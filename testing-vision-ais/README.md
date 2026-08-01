# testing-vision-ais

Pick a receipt image and have a local [Ollama](https://ollama.com) vision model
extract its products and total as structured JSON.

## Requirements

- Ollama running at `localhost:11434` with a vision model pulled:
  ```sh
  ollama pull gemma4:12b
  ```
- Nix — the dev shell provides Go and `air`.

## Run

```sh
nix-shell              # enters a shell with go + air
go run . 1             # extract receipt #1
go run .               # interactive picker
go run . receipt-0.jpg # by filename
```

Drop receipt images into `receipts/`.
Flags: `-model` (default `gemma4:12b`), `-url` (default `http://localhost:11434`),
`-dir` (default `receipts`).

## Develop

Live reload — rebuild and re-run on every `.go` save:

```sh
air
```

Configured in `.air.toml`; it re-runs against receipt #1. Change `args_bin` to
pick a different receipt (or `[]` for the interactive picker).
