// SPDX-License-Identifier: Apache-2.0
// Copyright (c) CHOOVIO Inc.
package lora

import "net/http"

func Handler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("lora"))
}
