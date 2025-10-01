// SPDX-License-Identifier: Apache-2.0
// Copyright (c) CHOOVIO Inc.

package lora

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

type Handler struct {
	publisher MQTTPublisher
	cfg       Config
	logger    *slog.Logger
}

func MakeHandler(publisher MQTTPublisher, cfg Config, logger *slog.Logger) http.Handler {
	h := Handler{publisher: publisher, cfg: cfg, logger: logger}
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Get("/health", h.health)
	r.Post(cfg.UplinkPath, h.uplink)
	return r
}

func (h Handler) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h Handler) uplink(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, h.cfg.MaxBodySize))
	if err != nil {
		h.logError("failed to read request body", err)
		writeError(w, http.StatusRequestEntityTooLarge, fmt.Errorf("failed to read body: %w", err))
		return
	}
	defer r.Body.Close()
	if len(body) == 0 {
		h.logError("empty uplink payload", errors.New("empty body"))
		writeError(w, http.StatusBadRequest, errors.New("empty request body"))
		return
	}
	msg, err := decodeUplink(body)
	if err != nil {
		h.logError("failed to decode uplink payload", err)
		writeError(w, http.StatusBadRequest, err)
		return
	}
	topic := buildTopic(h.cfg.MagistralaMQTTBaseTopic, msg)
	if err := h.publisher.Publish(r.Context(), topic, body); err != nil {
		h.logError("failed to forward uplink to MQTT", err, slog.String("topic", topic))
		writeError(w, http.StatusBadGateway, err)
		return
	}
	if h.logger != nil {
		h.logger.Info("uplink forwarded", slog.String("topic", topic), slog.String("application_id", msg.ApplicationID), slog.String("dev_eui", msg.DevEUI))
	}
	writeJSON(w, http.StatusAccepted, map[string]string{"status": "forwarded"})
}

type uplinkEnvelope struct {
	ApplicationID    string `json:"applicationID"`
	ApplicationIdAlt string `json:"applicationId"`
	ApplicationIDS   string `json:"application_id"`
	DevEUI           string `json:"devEUI"`
	DevEuiAlt        string `json:"devEui"`
	DevEUIS          string `json:"dev_eui"`
	DeviceName       string `json:"deviceName"`
	DeviceNameSnake  string `json:"device_name"`
}

type uplinkMessage struct {
	ApplicationID string
	DevEUI        string
	DeviceName    string
}

func decodeUplink(body []byte) (uplinkMessage, error) {
	var env uplinkEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		return uplinkMessage{}, fmt.Errorf("invalid uplink payload: %w", err)
	}
	msg := uplinkMessage{
		ApplicationID: firstNonEmpty(env.ApplicationID, env.ApplicationIdAlt, env.ApplicationIDS),
		DevEUI:        strings.ToUpper(firstNonEmpty(env.DevEUI, env.DevEuiAlt, env.DevEUIS)),
		DeviceName:    firstNonEmpty(env.DeviceName, env.DeviceNameSnake),
	}
	if msg.ApplicationID == "" && msg.DevEUI == "" {
		return uplinkMessage{}, errors.New("uplink payload missing identifiers")
	}
	return msg, nil
}

func buildTopic(base string, msg uplinkMessage) string {
	parts := []string{strings.Trim(base, "/")}
	if msg.ApplicationID != "" {
		parts = append(parts, msg.ApplicationID)
	}
	if msg.DevEUI != "" {
		parts = append(parts, msg.DevEUI)
	} else if msg.DeviceName != "" {
		parts = append(parts, msg.DeviceName)
	}
	parts = append(parts, "up")
	return strings.Join(parts, "/")
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if payload == nil {
		return
	}
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, map[string]string{"error": err.Error()})
}

func (h Handler) logError(message string, err error, attrs ...slog.Attr) {
	if h.logger == nil {
		return
	}
	all := make([]any, 0, len(attrs)+1)
	for _, attr := range attrs {
		all = append(all, attr)
	}
	all = append(all, slog.String("error", err.Error()))
	h.logger.Error(message, all...)
}
