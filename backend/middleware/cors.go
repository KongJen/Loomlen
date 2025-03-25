package middleware

import (
	"net/http"
)

func CorsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// More comprehensive CORS headers
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, CONNECT")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Socket-ID")

		// Specific WebSocket headers
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		// Preflight request handling
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}
