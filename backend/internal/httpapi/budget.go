package httpapi

import (
	"net/http"
	"sort"
	"time"

	"github.com/google/uuid"
)

type CategorySummary struct {
	Category    string `json:"category"`
	SpentGrosze int64  `json:"spentGrosze"`
	LimitGrosze int64  `json:"limitGrosze"` // 0 = brak limitu
}

type BudgetSummary struct {
	Month         string            `json:"month"` // YYYY-MM
	IncomeGrosze  int64             `json:"incomeGrosze"`
	ExpenseGrosze int64             `json:"expenseGrosze"`
	Categories    []CategorySummary `json:"categories"`
}

// budgetSummary zwraca podsumowanie miesiąca: przychody, wydatki i wydatki
// per kategoria zestawione z limitami. ?month=YYYY-MM (domyślnie bieżący).
func (a *API) budgetSummary(w http.ResponseWriter, r *http.Request) {
	uid := userID(r)
	monthStr := r.URL.Query().Get("month")
	first, err := parseMonth(monthStr)
	if err != nil {
		now := time.Now()
		first = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
		monthStr = first.Format("2006-01")
	}
	next := first.AddDate(0, 1, 0)

	out := BudgetSummary{Month: monthStr, Categories: []CategorySummary{}}

	err = a.db.QueryRow(r.Context(),
		`SELECT
		   COALESCE(SUM(CASE WHEN kind = 'income' THEN amount_grosze ELSE 0 END), 0),
		   COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount_grosze ELSE 0 END), 0)
		 FROM transactions
		 WHERE user_id = $1 AND occurred_on >= $2 AND occurred_on < $3`,
		uid, first, next).Scan(&out.IncomeGrosze, &out.ExpenseGrosze)
	if err != nil {
		internalErr(w, err)
		return
	}

	byCat := map[string]*CategorySummary{}
	getCat := func(name string) *CategorySummary {
		if c, ok := byCat[name]; ok {
			return c
		}
		c := &CategorySummary{Category: name}
		byCat[name] = c
		return c
	}

	rows, err := a.db.Query(r.Context(),
		`SELECT category, SUM(amount_grosze) FROM transactions
		 WHERE user_id = $1 AND kind = 'expense' AND occurred_on >= $2 AND occurred_on < $3
		 GROUP BY category`, uid, first, next)
	if err != nil {
		internalErr(w, err)
		return
	}
	for rows.Next() {
		var cat string
		var spent int64
		if err := rows.Scan(&cat, &spent); err != nil {
			rows.Close()
			internalErr(w, err)
			return
		}
		getCat(cat).SpentGrosze = spent
	}
	rows.Close()

	rows, err = a.db.Query(r.Context(),
		`SELECT category, limit_grosze FROM budgets WHERE user_id = $1 AND month = $2`, uid, first)
	if err != nil {
		internalErr(w, err)
		return
	}
	for rows.Next() {
		var cat string
		var limit int64
		if err := rows.Scan(&cat, &limit); err != nil {
			rows.Close()
			internalErr(w, err)
			return
		}
		getCat(cat).LimitGrosze = limit
	}
	rows.Close()

	for _, c := range byCat {
		out.Categories = append(out.Categories, *c)
	}
	sort.Slice(out.Categories, func(i, j int) bool {
		if out.Categories[i].SpentGrosze != out.Categories[j].SpentGrosze {
			return out.Categories[i].SpentGrosze > out.Categories[j].SpentGrosze
		}
		return out.Categories[i].Category < out.Categories[j].Category
	})

	writeJSON(w, http.StatusOK, out)
}

type budgetLimitInput struct {
	Month       string `json:"month"` // YYYY-MM
	Category    string `json:"category"`
	LimitGrosze int64  `json:"limitGrosze"`
}

// upsertBudgetLimit ustawia limit dla kategorii w danym miesiącu; limit <= 0 usuwa go.
func (a *API) upsertBudgetLimit(w http.ResponseWriter, r *http.Request) {
	var in budgetLimitInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	first, err := parseMonth(in.Month)
	if err != nil {
		writeErr(w, http.StatusBadRequest, "Nieprawidłowy miesiąc (użyj RRRR-MM)")
		return
	}
	if in.Category == "" {
		writeErr(w, http.StatusBadRequest, "Podaj kategorię")
		return
	}

	if in.LimitGrosze <= 0 {
		_, err = a.db.Exec(r.Context(),
			`DELETE FROM budgets WHERE user_id = $1 AND month = $2 AND category = $3`,
			userID(r), first, in.Category)
	} else {
		_, err = a.db.Exec(r.Context(),
			`INSERT INTO budgets (user_id, month, category, limit_grosze) VALUES ($1, $2, $3, $4)
			 ON CONFLICT (user_id, month, category) DO UPDATE SET limit_grosze = EXCLUDED.limit_grosze`,
			userID(r), first, in.Category, in.LimitGrosze)
	}
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

type Transaction struct {
	ID            uuid.UUID  `json:"id"`
	OccurredOn    string     `json:"occurredOn"` // YYYY-MM-DD
	Kind          string     `json:"kind"`       // expense | income
	AmountGrosze  int64      `json:"amountGrosze"`
	Category      string     `json:"category"`
	Description   string     `json:"description"`
	ReceiptFileID *uuid.UUID `json:"receiptFileId"`
}

type transactionInput struct {
	OccurredOn    string     `json:"occurredOn"`
	Kind          string     `json:"kind"`
	AmountGrosze  int64      `json:"amountGrosze"`
	Category      string     `json:"category"`
	Description   string     `json:"description"`
	ReceiptFileID *uuid.UUID `json:"receiptFileId"`
}

func (in *transactionInput) validate() (time.Time, error) {
	d, err := parseDate(in.OccurredOn)
	if err != nil {
		return time.Time{}, &validationError{"Nieprawidłowa data"}
	}
	if in.Kind != "expense" && in.Kind != "income" {
		return time.Time{}, &validationError{"Nieprawidłowy rodzaj transakcji"}
	}
	if in.AmountGrosze <= 0 {
		return time.Time{}, &validationError{"Kwota musi być większa od zera"}
	}
	if in.Category == "" {
		in.Category = "inne"
	}
	return d, nil
}

// listTransactions obsługuje ?month=YYYY-MM (domyślnie bieżący miesiąc).
func (a *API) listTransactions(w http.ResponseWriter, r *http.Request) {
	first, err := parseMonth(r.URL.Query().Get("month"))
	if err != nil {
		now := time.Now()
		first = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	}
	next := first.AddDate(0, 1, 0)

	rows, err := a.db.Query(r.Context(),
		`SELECT id, occurred_on, kind, amount_grosze, category, description, receipt_file_id
		 FROM transactions
		 WHERE user_id = $1 AND occurred_on >= $2 AND occurred_on < $3
		 ORDER BY occurred_on DESC, created_at DESC`, userID(r), first, next)
	if err != nil {
		internalErr(w, err)
		return
	}
	defer rows.Close()

	out := []Transaction{}
	for rows.Next() {
		var t Transaction
		var d time.Time
		if err := rows.Scan(&t.ID, &d, &t.Kind, &t.AmountGrosze, &t.Category, &t.Description, &t.ReceiptFileID); err != nil {
			internalErr(w, err)
			return
		}
		t.OccurredOn = fmtDate(d)
		out = append(out, t)
	}
	writeJSON(w, http.StatusOK, out)
}

func (a *API) createTransaction(w http.ResponseWriter, r *http.Request) {
	var in transactionInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	d, err := in.validate()
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	t := Transaction{OccurredOn: in.OccurredOn, Kind: in.Kind, AmountGrosze: in.AmountGrosze,
		Category: in.Category, Description: in.Description, ReceiptFileID: in.ReceiptFileID}
	err = a.db.QueryRow(r.Context(),
		`INSERT INTO transactions (user_id, occurred_on, kind, amount_grosze, category, description, receipt_file_id)
		 VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`,
		userID(r), d, in.Kind, in.AmountGrosze, in.Category, in.Description, in.ReceiptFileID).Scan(&t.ID)
	if err != nil {
		internalErr(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, t)
}

func (a *API) updateTransaction(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var in transactionInput
	if err := decodeJSON(r, &in); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	d, err := in.validate()
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	tag, err := a.db.Exec(r.Context(),
		`UPDATE transactions SET occurred_on = $1, kind = $2, amount_grosze = $3,
		 category = $4, description = $5, receipt_file_id = $6
		 WHERE id = $7 AND user_id = $8`,
		d, in.Kind, in.AmountGrosze, in.Category, in.Description, in.ReceiptFileID, id, userID(r))
	if err != nil {
		internalErr(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		writeErr(w, http.StatusNotFound, "Nie znaleziono transakcji")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (a *API) deleteTransaction(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`DELETE FROM transactions WHERE id = $1 AND user_id = $2`, id, userID(r)); err != nil {
		internalErr(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
