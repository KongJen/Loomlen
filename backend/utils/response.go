// utils/response.go
package utils

import (
	"encoding/json"
	"net/http"
)

// Response represents a standardized API response
type Response struct {
	Status  string      `json:"status"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// RespondWithJSON sends a JSON response with the given status code
func RespondWithJSON(w http.ResponseWriter, statusCode int, payload interface{}) {
	response, err := json.Marshal(payload)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"status":"error","error":"Failed to marshal JSON response"}`))
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	w.Write(response)
}

// RespondWithError sends an error response with the given status code and message
func RespondWithError(w http.ResponseWriter, statusCode int, message string) {
	RespondWithJSON(w, statusCode, Response{
		Status: "error",
		Error:  message,
	})
}

// RespondWithSuccess sends a success response with the given data
func RespondWithSuccess(w http.ResponseWriter, data interface{}) {
	RespondWithJSON(w, http.StatusOK, Response{
		Status: "success",
		Data:   data,
	})
}

// RespondWithMessage sends a success response with a message
func RespondWithMessage(w http.ResponseWriter, message string) {
	RespondWithJSON(w, http.StatusOK, Response{
		Status:  "success",
		Message: message,
	})
}
