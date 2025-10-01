// SPDX-License-Identifier: Apache-2.0
// Copyright (c) CHOOVIO Inc.

package lora

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
)

const defaultPublishTimeout = 5 * time.Second

type MQTTPublisher interface {
	Publish(ctx context.Context, topic string, payload []byte) error
	Close()
}

type mqttPublisher struct {
	client  mqtt.Client
	timeout time.Duration
}

func NewMQTTPublisher(cfg Config) (MQTTPublisher, error) {
	brokerURL, err := parseMQTTURL(cfg.MagistralaMQTTURL)
	if err != nil {
		return nil, err
	}
	if cfg.MagistralaMQTTClientID == "" {
		cfg.MagistralaMQTTClientID = fmt.Sprintf("lora-adapter-%s", randomSuffix(6))
	}
	opts := mqtt.NewClientOptions()
	opts.AddBroker(convertBrokerScheme(brokerURL.String()))
	opts.SetClientID(cfg.MagistralaMQTTClientID)
	if cfg.MagistralaMQTTUsername != "" {
		opts.SetUsername(cfg.MagistralaMQTTUsername)
		opts.SetPassword(cfg.MagistralaMQTTPassword)
	}
	opts.SetConnectRetry(true)
	opts.SetConnectRetryInterval(2 * time.Second)
	opts.SetAutoReconnect(true)
	client := mqtt.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		return nil, fmt.Errorf("failed to connect to MQTT broker: %w", token.Error())
	}
	timeout := defaultPublishTimeout
	if cfg.MagistralaMQTTPublishTimeout > 0 {
		timeout = cfg.MagistralaMQTTPublishTimeout
	}
	return &mqttPublisher{client: client, timeout: timeout}, nil
}

func (p *mqttPublisher) Publish(ctx context.Context, topic string, payload []byte) error {
	if !p.client.IsConnected() {
		return fmt.Errorf("mqtt client is not connected")
	}
	token := p.client.Publish(topic, 0, false, payload)
	waitTimeout := p.timeout
	if deadline, ok := ctx.Deadline(); ok {
		if rem := time.Until(deadline); rem > 0 && rem < waitTimeout {
			waitTimeout = rem
		}
	}
	if !token.WaitTimeout(waitTimeout) {
		if ctx.Err() != nil {
			return fmt.Errorf("publish cancelled: %w", ctx.Err())
		}
		return fmt.Errorf("publishing to topic %s timed out after %s", topic, waitTimeout)
	}
	if err := token.Error(); err != nil {
		return fmt.Errorf("publish error: %w", err)
	}
	return nil
}

func (p *mqttPublisher) Close() {
	if p.client == nil {
		return
	}
	p.client.Disconnect(250)
}

func randomSuffix(length int) string {
	if length <= 0 {
		return ""
	}
	bytes := make([]byte, length)
	if _, err := rand.Read(bytes); err != nil {
		return ""
	}
	encoded := hex.EncodeToString(bytes)
	if len(encoded) > length {
		encoded = encoded[:length]
	}
	return encoded
}

func convertBrokerScheme(raw string) string {
	if raw == "" {
		return raw
	}
	if strings.HasPrefix(raw, "mqtt://") {
		return "tcp://" + strings.TrimPrefix(raw, "mqtt://")
	}
	if strings.HasPrefix(raw, "mqtts://") {
		return "ssl://" + strings.TrimPrefix(raw, "mqtts://")
	}
	return raw
}
