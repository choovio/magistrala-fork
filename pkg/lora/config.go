// SPDX-License-Identifier: Apache-2.0
// Copyright (c) CHOOVIO Inc.

package lora

import (
	"errors"
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/caarlos0/env/v11"
)

type Config struct {
	HTTPHost          string        `env:"LORA_HTTP_HOST"               envDefault:"0.0.0.0"`
	HTTPPort          string        `env:"LORA_HTTP_PORT"               envDefault:"8080"`
	UplinkPath        string        `env:"LORA_HTTP_UPLINK_PATH"        envDefault:"/uplink"`
	ReadHeaderTimeout time.Duration `env:"LORA_HTTP_READ_HEADER_TIMEOUT" envDefault:"5s"`
	ShutdownTimeout   time.Duration `env:"LORA_HTTP_SHUTDOWN_TIMEOUT"   envDefault:"5s"`
	MaxBodySize       int64         `env:"LORA_HTTP_MAX_BODY_SIZE"      envDefault:"1048576"`

	MagistralaMQTTURL            string        `env:"MAGISTRALA_MQTT_URL,notEmpty"`
	MagistralaMQTTUsername       string        `env:"MAGISTRALA_MQTT_USERNAME"`
	MagistralaMQTTPassword       string        `env:"MAGISTRALA_MQTT_PASSWORD"`
	MagistralaMQTTClientID       string        `env:"MAGISTRALA_MQTT_CLIENT_ID"`
	MagistralaMQTTBaseTopic      string        `env:"MAGISTRALA_MQTT_BASE_TOPIC"   envDefault:"lora"`
	MagistralaMQTTPublishTimeout time.Duration `env:"MAGISTRALA_MQTT_PUBLISH_TIMEOUT" envDefault:"5s"`

	ChirpstackAPIURL   string `env:"CHIRPSTACK_API_URL"`
	ChirpstackAPIToken string `env:"CHIRPSTACK_API_TOKEN"`

	LogLevel string `env:"LOG_LEVEL" envDefault:"info"`
}

func LoadConfig() (Config, error) {
	var cfg Config
	if err := env.Parse(&cfg); err != nil {
		return Config{}, fmt.Errorf("failed to parse environment: %w", err)
	}
	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (cfg *Config) Validate() error {
	if cfg == nil {
		return errors.New("missing configuration")
	}

	if strings.TrimSpace(cfg.HTTPPort) == "" {
		cfg.HTTPPort = "8080"
	}

	if _, err := strconv.Atoi(cfg.HTTPPort); err != nil {
		return fmt.Errorf("invalid http port: %w", err)
	}

	if cfg.MaxBodySize <= 0 {
		return fmt.Errorf("invalid max body size: %d", cfg.MaxBodySize)
	}

	cfg.UplinkPath = sanitizePath(cfg.UplinkPath)
	if !strings.HasPrefix(cfg.UplinkPath, "/") {
		return fmt.Errorf("uplink path must start with '/' got %s", cfg.UplinkPath)
	}

	cfg.MagistralaMQTTBaseTopic = strings.Trim(cfg.MagistralaMQTTBaseTopic, "/")
	if cfg.MagistralaMQTTBaseTopic == "" {
		return errors.New("magistrala base topic must not be empty")
	}

	if _, err := parseMQTTURL(cfg.MagistralaMQTTURL); err != nil {
		return err
	}

	if cfg.MagistralaMQTTPublishTimeout <= 0 {
		return fmt.Errorf("magistrala mqtt publish timeout must be positive")
	}

	if cfg.HTTPHost != "" {
		if ip := net.ParseIP(cfg.HTTPHost); ip == nil && cfg.HTTPHost != "localhost" {
			if strings.Contains(cfg.HTTPHost, " ") {
				return fmt.Errorf("invalid http host: %s", cfg.HTTPHost)
			}
		}
	}

	return nil
}

func sanitizePath(path string) string {
	if path == "" {
		return "/uplink"
	}
	if !strings.HasPrefix(path, "/") {
		path = "/" + path
	}
	if path != "/" && strings.HasSuffix(path, "/") {
		path = strings.TrimRight(path, "/")
		if path == "" {
			path = "/"
		}
	}
	return path
}

func parseMQTTURL(raw string) (*url.URL, error) {
	if strings.TrimSpace(raw) == "" {
		return nil, errors.New("magistrala MQTT URL must not be empty")
	}
	u, err := url.Parse(raw)
	if err != nil {
		return nil, fmt.Errorf("invalid magistrala MQTT URL: %w", err)
	}
	switch strings.ToLower(u.Scheme) {
	case "mqtt", "tcp", "ssl", "tls", "ws", "wss":
	default:
		return nil, fmt.Errorf("unsupported mqtt scheme: %s", u.Scheme)
	}
	if u.Host == "" {
		return nil, errors.New("magistrala MQTT URL missing host")
	}
	return u, nil
}
