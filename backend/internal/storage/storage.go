package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// Storage to cienka warstwa nad MinIO (S3-kompatybilny object storage).
type Storage struct {
	client *minio.Client
	bucket string
}

// Connect tworzy klienta MinIO i dba o istnienie bucketa, ponawiając próby
// (przy starcie docker-compose MinIO może wstawać dłużej niż backend).
func Connect(ctx context.Context, endpoint, accessKey, secretKey, bucket string, useSSL bool) (*Storage, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, err
	}
	s := &Storage{client: client, bucket: bucket}

	var lastErr error
	for i := 0; i < 30; i++ {
		exists, err := client.BucketExists(ctx, bucket)
		if err == nil {
			if exists {
				return s, nil
			}
			err = client.MakeBucket(ctx, bucket, minio.MakeBucketOptions{})
			if err == nil {
				log.Printf("utworzono bucket %q w MinIO", bucket)
				return s, nil
			}
			code := minio.ToErrorResponse(err).Code
			if code == "BucketAlreadyOwnedByYou" || code == "BucketAlreadyExists" {
				return s, nil
			}
		}
		lastErr = err
		log.Printf("MinIO jeszcze nie gotowe (%v), ponawiam...", lastErr)
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(2 * time.Second):
		}
	}
	return nil, fmt.Errorf("nie udało się połączyć z MinIO: %w", lastErr)
}

func (s *Storage) Put(ctx context.Context, key string, data []byte, contentType string) error {
	_, err := s.client.PutObject(ctx, s.bucket, key, bytes.NewReader(data), int64(len(data)),
		minio.PutObjectOptions{ContentType: contentType})
	return err
}

// Get zwraca strumień z obiektem. GetObject jest leniwe, więc od razu robimy Stat,
// żeby brak pliku wyszedł tutaj, a nie w połowie odpowiedzi HTTP.
func (s *Storage) Get(ctx context.Context, key string) (io.ReadCloser, error) {
	obj, err := s.client.GetObject(ctx, s.bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, err
	}
	if _, err := obj.Stat(); err != nil {
		_ = obj.Close()
		return nil, err
	}
	return obj, nil
}

func (s *Storage) Delete(ctx context.Context, key string) error {
	return s.client.RemoveObject(ctx, s.bucket, key, minio.RemoveObjectOptions{})
}
