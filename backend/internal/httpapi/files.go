package httpapi

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"regexp"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

const maxUploadBytes = 15 << 20 // 15 MB

var safeExt = regexp.MustCompile(`^\.[a-zA-Z0-9]{1,5}$`)

// uploadFile przyjmuje multipart pole "file", zapisuje obiekt w MinIO
// i metadane w Postgresie. Zwraca id, którym można podpiąć plik
// pod transakcję (paragon) albo przepis (zdjęcie).
func (a *API) uploadFile(w http.ResponseWriter, r *http.Request) {
	uid := userID(r)
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadBytes)
	if err := r.ParseMultipartForm(maxUploadBytes); err != nil {
		writeErr(w, http.StatusBadRequest, "Plik jest za duży (maks. 15 MB)")
		return
	}
	f, hdr, err := r.FormFile("file")
	if err != nil {
		writeErr(w, http.StatusBadRequest, "Brak pliku w żądaniu (pole \"file\")")
		return
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		internalErr(w, err)
		return
	}
	if len(data) == 0 {
		writeErr(w, http.StatusBadRequest, "Pusty plik")
		return
	}

	contentType := hdr.Header.Get("Content-Type")
	if contentType == "" || contentType == "application/octet-stream" {
		contentType = http.DetectContentType(data)
	}

	id := uuid.New()
	ext := filepath.Ext(hdr.Filename)
	if !safeExt.MatchString(ext) {
		ext = ""
	}
	key := fmt.Sprintf("%s/%s%s", uid, id, ext)

	if err := a.store.Put(r.Context(), key, data, contentType); err != nil {
		internalErr(w, err)
		return
	}
	if _, err := a.db.Exec(r.Context(),
		`INSERT INTO files (id, user_id, object_key, content_type, size_bytes)
		 VALUES ($1, $2, $3, $4, $5)`,
		id, uid, key, contentType, len(data)); err != nil {
		internalErr(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{
		"id":  id.String(),
		"url": "/api/files/" + id.String(),
	})
}

// serveFile streamuje plik z MinIO (tylko właścicielowi).
func (a *API) serveFile(w http.ResponseWriter, r *http.Request) {
	id, err := pathUUID(r, "id")
	if err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	var key, contentType string
	err = a.db.QueryRow(r.Context(),
		`SELECT object_key, content_type FROM files WHERE id = $1 AND user_id = $2`,
		id, userID(r)).Scan(&key, &contentType)
	if errors.Is(err, pgx.ErrNoRows) {
		writeErr(w, http.StatusNotFound, "Nie znaleziono pliku")
		return
	}
	if err != nil {
		internalErr(w, err)
		return
	}

	obj, err := a.store.Get(r.Context(), key)
	if err != nil {
		writeErr(w, http.StatusNotFound, "Plik niedostępny")
		return
	}
	defer obj.Close()

	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "private, max-age=86400")
	_, _ = io.Copy(w, obj)
}
