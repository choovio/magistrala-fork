// SPDX-License-Identifier: Apache-2.0
// Copyright (c) CHOOVIO Inc.

package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/absmach/magistrala/pkg/lora"
	smqlog "github.com/absmach/supermq/logger"
)

const svcName = "lora"

var (
	version   = "dev"
	commit    = "none"
	buildDate = "unknown"
)

func main() {
	cfg, err := lora.LoadConfig()
	if err != nil {
		log.Fatalf("failed to load %s configuration : %s", svcName, err)
	}

	logger, err := smqlog.New(os.Stdout, cfg.LogLevel)
	if err != nil {
		log.Fatalf("failed to init logger: %s", err)
	}

	logger.Info("LoRa adapter configuration loaded", "version", version, "commit", commit, "build_date", buildDate)
	if cfg.ChirpstackAPIURL == "" || cfg.ChirpstackAPIToken == "" {
		logger.Warn("ChirpStack API credentials not provided; automatic provisioning disabled")
	}

	var exitCode int
	defer smqlog.ExitWithError(&exitCode)

	publisher, err := lora.NewMQTTPublisher(cfg)
	if err != nil {
		logger.Error(fmt.Sprintf("failed to connect to MQTT broker: %s", err))
		exitCode = 1
		return
	}
	defer publisher.Close()

	handler := lora.MakeHandler(publisher, cfg, logger)
	srv := &http.Server{
		Addr:              net.JoinHostPort(cfg.HTTPHost, cfg.HTTPPort),
		Handler:           handler,
		ReadHeaderTimeout: cfg.ReadHeaderTimeout,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM, syscall.SIGINT)
	defer stop()

	errCh := make(chan error, 1)
	go func() {
		logger.Info("LoRa adapter HTTP server starting", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			logger.Error(fmt.Sprintf("HTTP server shutdown error: %s", err))
			exitCode = 1
		}
	case err := <-errCh:
		if err != nil {
			logger.Error(fmt.Sprintf("HTTP server error: %s", err))
			exitCode = 1
		}
	}

	if err := <-errCh; err != nil {
		logger.Error(fmt.Sprintf("HTTP server error: %s", err))
		exitCode = 1
	}

	logger.Info("LoRa adapter shutdown complete")
}
