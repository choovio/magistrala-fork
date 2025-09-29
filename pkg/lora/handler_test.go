// # Copyright (c) CHOOVIO Inc.
// # SPDX-License-Identifier: Apache-2.0

package lora

import "testing"

func TestDecodeUplink(t *testing.T) {
	t.Helper()
	cases := []struct {
		name    string
		payload string
		want    uplinkMessage
		wantErr bool
	}{
		{
			name:    "standard payload",
			payload: `{"applicationID":"42","devEUI":"0102030405060708","deviceName":"sensor-1"}`,
			want:    uplinkMessage{ApplicationID: "42", DevEUI: "0102030405060708", DeviceName: "sensor-1"},
		},
		{
			name:    "alternative keys",
			payload: `{"applicationId":"17","dev_eui":"AABBCC","device_name":"node"}`,
			want:    uplinkMessage{ApplicationID: "17", DevEUI: "AABBCC", DeviceName: "node"},
		},
		{
			name:    "missing identifiers",
			payload: `{"data":"AQ=="}`,
			wantErr: true,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			msg, err := decodeUplink([]byte(tc.payload))
			if tc.wantErr {
				if err == nil {
					t.Fatalf("expected error, got none")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if msg != tc.want {
				t.Fatalf("unexpected message: %+v", msg)
			}
		})
	}
}

func TestBuildTopic(t *testing.T) {
	cfg := Config{MagistralaMQTTBaseTopic: "lora"}
	msg := uplinkMessage{ApplicationID: "1", DevEUI: "AA", DeviceName: "node"}
	got := buildTopic(cfg.MagistralaMQTTBaseTopic, msg)
	want := "lora/1/AA/up"
	if got != want {
		t.Fatalf("unexpected topic: got %s want %s", got, want)
	}

	msg = uplinkMessage{ApplicationID: "", DevEUI: "", DeviceName: "node"}
	got = buildTopic(cfg.MagistralaMQTTBaseTopic, msg)
	if got != "lora/node/up" {
		t.Fatalf("unexpected fallback topic: %s", got)
	}
}
