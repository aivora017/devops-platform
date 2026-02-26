package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", home)
	http.HandleFunc("/health", health)
	http.HandleFunc("/version", version)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	fmt.Printf("Starting Go API on port %s\n", port)
	http.ListenAndServe(":"+port, nil)
}

func home(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"service": "go-api",
		"status":  "running",
	})
}

func health(w http.ResponseWriter, r *http.Request) {
	// just return ok, worker checks this endpoint
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func version(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{"version": "0.1"})
}
