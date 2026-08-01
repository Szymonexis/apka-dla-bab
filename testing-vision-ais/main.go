// Command testing-vision-ais lets you pick a receipt image from the receipts/
// directory and sends it to a local Ollama vision model, which returns the
// products and total as structured JSON.
package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// ---- Extracted receipt shape ------------------------------------------------

// Money is a monetary amount. Value is in MINOR currency units (e.g. grosze,
// cents) so it stays an exact integer: 12.34 PLN is represented as 1234.
type Money struct {
	Value    int    `json:"value"`
	Currency string `json:"currency"` // ISO 4217, e.g. PLN, EUR, USD
}

// Product is a single purchased line item.
type Product struct {
	Name  string `json:"name"`
	Price Money  `json:"price"`
}

// Receipt is the full structured result we ask the model to produce.
type Receipt struct {
	Total    Money     `json:"total"`
	Products []Product `json:"products"`
}

// receiptSchema is the JSON schema handed to Ollama's `format` parameter. It
// constrains the model's decoding so the reply is always valid JSON matching
// the Receipt struct above.
func receiptSchema() map[string]any {
	money := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"value":    map[string]any{"type": "integer"},
			"currency": map[string]any{"type": "string"},
		},
		"required": []string{"value", "currency"},
	}
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"total": money,
			"products": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"name":  map[string]any{"type": "string"},
						"price": money,
					},
					"required": []string{"name", "price"},
				},
			},
		},
		"required": []string{"total", "products"},
	}
}

const systemPrompt = `You are a precise receipt data extraction system. You are given a photograph of a shopping receipt. Extract every purchased product and the final total.

Respond with a single JSON object of exactly this shape:
{
  "total":    { "value": <int>, "currency": "<ISO 4217>" },
  "products": [ { "name": "<string>", "price": { "value": <int>, "currency": "<ISO 4217>" } } ]
}

Rules:
- "value" is the amount in MINOR currency units (cents, grosze) as an integer. 12.34 PLN -> 1234, 5.00 EUR -> 500. Never write a decimal point.
- "currency" is the ISO 4217 three-letter code (PLN, EUR, USD, GBP, ...). Infer it from currency symbols, the language, or tax labels on the receipt.
- "products" has one entry per purchased line item, with the name exactly as printed and the price actually charged for that line (after any per-line discount).
- "total" is the final amount paid printed on the receipt.
- Do not include subtotals, tax lines, change, loyalty points, or the payment method as products.
- Output only the JSON object, with no markdown fences and no commentary.`

// ---- Ollama chat API --------------------------------------------------------

type chatMessage struct {
	Role    string   `json:"role"`
	Content string   `json:"content"`
	Images  []string `json:"images,omitempty"` // base64-encoded, no data: prefix
}

type chatRequest struct {
	Model    string         `json:"model"`
	Messages []chatMessage  `json:"messages"`
	Stream   bool           `json:"stream"`
	Think    bool           `json:"think"` // disable "thinking" for a clean, fast reply
	Format   any            `json:"format,omitempty"`
	Options  map[string]any `json:"options,omitempty"`
}

type chatResponse struct {
	Message struct {
		Content string `json:"content"`
	} `json:"message"`
}

// extract sends one receipt image to the model and returns the parsed receipt
// plus the raw JSON string the model produced.
func extract(ollamaURL, model, imagePath string) (*Receipt, string, error) {
	raw, err := os.ReadFile(imagePath)
	if err != nil {
		return nil, "", fmt.Errorf("reading image: %w", err)
	}

	body, err := json.Marshal(chatRequest{
		Model:   model,
		Stream:  false,
		Think:   false,
		Format:  receiptSchema(),
		Options: map[string]any{"temperature": 0},
		Messages: []chatMessage{
			{Role: "system", Content: systemPrompt},
			{
				Role:    "user",
				Content: "Extract the receipt data from this image.",
				Images:  []string{base64.StdEncoding.EncodeToString(raw)},
			},
		},
	})
	if err != nil {
		return nil, "", err
	}

	// Vision inference on a 12B model can take a while, so allow plenty of time.
	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Post(ollamaURL+"/api/chat", "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, "", fmt.Errorf("calling Ollama at %s: %w", ollamaURL, err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return nil, "", fmt.Errorf("ollama returned %s: %s", resp.Status, strings.TrimSpace(string(respBody)))
	}

	var cr chatResponse
	if err := json.Unmarshal(respBody, &cr); err != nil {
		return nil, "", fmt.Errorf("decoding ollama response: %w", err)
	}

	content := strings.TrimSpace(cr.Message.Content)
	var receipt Receipt
	if err := json.Unmarshal([]byte(content), &receipt); err != nil {
		return nil, content, fmt.Errorf("model did not return the expected JSON: %w", err)
	}
	return &receipt, content, nil
}

// ---- Receipt selection ------------------------------------------------------

var imageExts = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true,
	".webp": true, ".gif": true, ".bmp": true,
}

func listReceipts(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var files []string
	for _, e := range entries {
		if !e.IsDir() && imageExts[strings.ToLower(filepath.Ext(e.Name()))] {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)
	return files, nil
}

// chooseReceipt resolves the receipt to use. selector may be empty (prompt
// interactively), a 1-based index, or a filename.
func chooseReceipt(dir string, files []string, selector string) (string, error) {
	if selector != "" {
		if n, err := strconv.Atoi(selector); err == nil {
			if n < 1 || n > len(files) {
				return "", fmt.Errorf("index %d out of range (1..%d)", n, len(files))
			}
			return files[n-1], nil
		}
		for _, f := range files {
			if f == selector {
				return f, nil
			}
		}
		return "", fmt.Errorf("receipt %q not found in %s/", selector, dir)
	}

	fmt.Println("Select a receipt:")
	for i, f := range files {
		fmt.Printf("  [%d] %s\n", i+1, f)
	}
	fmt.Print("Enter number: ")

	line, _ := bufio.NewReader(os.Stdin).ReadString('\n')
	n, err := strconv.Atoi(strings.TrimSpace(line))
	if err != nil || n < 1 || n > len(files) {
		return "", fmt.Errorf("invalid selection %q", strings.TrimSpace(line))
	}
	return files[n-1], nil
}

// ---- Output -----------------------------------------------------------------

// formatMoney renders minor units as major units with two decimals. This is
// correct for 2-decimal currencies (PLN, EUR, USD, ...), which cover the
// common receipt cases.
func formatMoney(m Money) string {
	return fmt.Sprintf("%d.%02d %s", m.Value/100, abs(m.Value)%100, m.Currency)
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}

func printReceipt(r *Receipt, rawJSON string) {
	fmt.Println("\nProducts:")
	for _, p := range r.Products {
		fmt.Printf("  %-34s %12s\n", p.Name, formatMoney(p.Price))
	}
	fmt.Printf("\n  %-34s %12s\n", "TOTAL", formatMoney(r.Total))

	fmt.Println("\nRaw JSON:")
	var pretty bytes.Buffer
	if json.Indent(&pretty, []byte(rawJSON), "", "  ") == nil {
		fmt.Println(pretty.String())
	} else {
		fmt.Println(rawJSON)
	}
}

// ---- main -------------------------------------------------------------------

func main() {
	model := flag.String("model", "gemma4:12b", "Ollama model to use")
	ollamaURL := flag.String("url", "http://localhost:11434", "Ollama server base URL")
	dir := flag.String("dir", "receipts", "directory containing receipt images")
	flag.Parse()

	if err := run(*model, *ollamaURL, *dir, flag.Arg(0)); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(model, ollamaURL, dir, selector string) error {
	files, err := listReceipts(dir)
	if err != nil {
		return fmt.Errorf("listing receipts: %w", err)
	}
	if len(files) == 0 {
		return fmt.Errorf("no receipt images found in %s/", dir)
	}

	choice, err := chooseReceipt(dir, files, selector)
	if err != nil {
		return err
	}
	path := filepath.Join(dir, choice)

	fmt.Printf("\nSending %s to %s ...\n", path, model)
	start := time.Now()
	receipt, rawJSON, err := extract(ollamaURL, model, path)
	if err != nil {
		if rawJSON != "" {
			fmt.Fprintln(os.Stderr, "model output was:\n"+rawJSON)
		}
		return err
	}
	fmt.Printf("Done in %s.\n", time.Since(start).Round(time.Second))

	printReceipt(receipt, rawJSON)
	return nil
}
