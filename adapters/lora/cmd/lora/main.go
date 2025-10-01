// SPDX-License-Identifier: Apache-2.0
// Copyright (c) CHOOVIO Inc.
package main

import (
	"log"
	"net/http"
)

func health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", health)
	addr := ":8080"
	log.Printf("lora adapter listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
