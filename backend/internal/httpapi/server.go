package httpapi

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/szymonexis/apka-dla-bab/backend/internal/config"
	"github.com/szymonexis/apka-dla-bab/backend/internal/notify"
	"github.com/szymonexis/apka-dla-bab/backend/internal/storage"
)

// API trzyma zależności współdzielone przez wszystkie handlery.
type API struct {
	db       *pgxpool.Pool
	store    *storage.Storage
	cfg      config.Config
	notifier *notify.Notifier
}

func New(db *pgxpool.Pool, store *storage.Storage, cfg config.Config, notifier *notify.Notifier) *API {
	return &API{db: db, store: store, cfg: cfg, notifier: notifier}
}

func (a *API) Router() http.Handler {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"*"},
	}))

	r.Get("/healthz", a.health)

	r.Route("/api", func(r chi.Router) {
		r.Post("/auth/register", a.register)
		r.Post("/auth/login", a.login)

		// Wszystko poniżej wymaga tokenu JWT.
		r.Group(func(r chi.Router) {
			r.Use(a.requireAuth)

			r.Get("/me", a.me)

			r.Route("/notes", func(r chi.Router) {
				r.Get("/", a.listNotes)
				r.Post("/", a.createNote)
				r.Put("/{id}", a.updateNote)
				r.Delete("/{id}", a.deleteNote)
			})

			r.Route("/reminders", func(r chi.Router) {
				r.Get("/", a.listReminders)
				r.Post("/", a.createReminder)
				r.Put("/{id}", a.updateReminder)
				r.Delete("/{id}", a.deleteReminder)
				r.Post("/{id}/toggle", a.toggleReminder)
			})

			r.Route("/events", func(r chi.Router) {
				r.Get("/", a.listEvents)
				r.Post("/", a.createEvent)
				r.Put("/{id}", a.updateEvent)
				r.Delete("/{id}", a.deleteEvent)
			})

			r.Route("/tasks", func(r chi.Router) {
				r.Get("/", a.listTasks)
				r.Post("/", a.createTask)
				r.Put("/{id}", a.updateTask)
				r.Delete("/{id}", a.deleteTask)
				r.Post("/{id}/toggle", a.toggleTask)
			})

			r.Route("/recipes", func(r chi.Router) {
				r.Get("/", a.listRecipes)
				r.Post("/", a.createRecipe)
				r.Get("/random", a.randomRecipe)
				r.Get("/{id}", a.getRecipe)
				r.Put("/{id}", a.updateRecipe)
				r.Delete("/{id}", a.deleteRecipe)
			})

			r.Route("/mealplan", func(r chi.Router) {
				r.Get("/", a.listMealPlan)
				r.Put("/", a.upsertMealPlan)
				r.Delete("/{id}", a.deleteMealPlan)
			})

			r.Route("/diary", func(r chi.Router) {
				r.Get("/", a.listDiary)
				r.Post("/", a.createDiary)
				r.Put("/{id}", a.updateDiary)
				r.Delete("/{id}", a.deleteDiary)
			})

			r.Get("/budget/summary", a.budgetSummary)
			r.Put("/budget/limits", a.upsertBudgetLimit)

			r.Route("/transactions", func(r chi.Router) {
				r.Get("/", a.listTransactions)
				r.Post("/", a.createTransaction)
				r.Put("/{id}", a.updateTransaction)
				r.Delete("/{id}", a.deleteTransaction)
			})

			r.Route("/push", func(r chi.Router) {
				r.Get("/settings", a.getPushSettings)
				r.Put("/settings", a.updatePushSettings)
				r.Post("/regenerate", a.regeneratePushTopic)
				r.Post("/test", a.testPush)
			})

			r.Post("/files", a.uploadFile)
			r.Get("/files/{id}", a.serveFile)
		})
	})

	return r
}

func (a *API) health(w http.ResponseWriter, r *http.Request) {
	if err := a.db.Ping(r.Context()); err != nil {
		writeErr(w, http.StatusServiceUnavailable, "baza danych niedostępna")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "app": "ogarniaczka"})
}
