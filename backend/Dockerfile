# --- Etap budowania ---
FROM golang:1.24-alpine AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/server ./cmd/server

# --- Etap uruchomieniowy ---
FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata && adduser -D -u 10001 app
USER app

COPY --from=build /out/server /usr/local/bin/server

EXPOSE 8080
ENTRYPOINT ["server"]
