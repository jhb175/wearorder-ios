package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

// LLMProvider runs one chat completion against an OpenAI-compatible
// endpoint. We deliberately stay generic — any vendor that implements
// `POST /chat/completions` (OpenAI, DeepSeek, 腾讯混元 OpenAI 兼容模式,
// Moonshot, Qwen DashScope OpenAI 兼容, OpenRouter, ...) plugs in by
// just changing base_url + api_key + model.
//
// Vendors with non-OpenAI shapes (Anthropic native, Gemini native,
// 文心一言 native) can be reached via OpenRouter or a similar
// aggregator without touching this code.
type LLMProvider struct {
	Record *ProviderRecord
	HTTP   *http.Client
}

// chatRequest mirrors the OpenAI chat.completions request shape. We
// only expose the fields we actually use; vendors generally ignore
// unknown fields, and adding more here is a safe forward-compatible
// change.
type chatRequest struct {
	Model          string             `json:"model"`
	Messages       []chatMessage      `json:"messages"`
	Temperature    *float64           `json:"temperature,omitempty"`
	MaxTokens      *int               `json:"max_tokens,omitempty"`
	ResponseFormat *responseFormatObj `json:"response_format,omitempty"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type responseFormatObj struct {
	Type string `json:"type"` // "json_object" — best supported across vendors
}

type chatResponse struct {
	Choices []struct {
		Message      chatMessage `json:"message"`
		FinishReason string      `json:"finish_reason"`
	} `json:"choices"`
	Usage struct {
		PromptTokens     int `json:"prompt_tokens"`
		CompletionTokens int `json:"completion_tokens"`
		TotalTokens      int `json:"total_tokens"`
	} `json:"usage"`
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
		Code    any    `json:"code"`
	} `json:"error"`
}

type GenerateOptions struct {
	Temperature *float64
	MaxTokens   *int
	JSONMode    bool // request response_format=json_object
	Timeout     time.Duration
}

type GenerateResult struct {
	Content          string
	PromptTokens     int
	CompletionTokens int
	FinishReason     string
}

// Generate runs a single chat completion and returns the assistant's
// content. Errors are wrapped so the caller can decide whether to
// retry against the next provider.
func (p *LLMProvider) Generate(ctx context.Context, system, user string, opt GenerateOptions) (*GenerateResult, error) {
	if p.HTTP == nil {
		p.HTTP = &http.Client{Timeout: 60 * time.Second}
	}
	if opt.Timeout > 0 {
		// Per-call deadline overrides the http.Client default.
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, opt.Timeout)
		defer cancel()
	}

	body := chatRequest{
		Model: p.Record.Model,
		Messages: []chatMessage{
			{Role: "system", Content: system},
			{Role: "user", Content: user},
		},
		Temperature: opt.Temperature,
		MaxTokens:   opt.MaxTokens,
	}
	if opt.JSONMode {
		body.ResponseFormat = &responseFormatObj{Type: "json_object"}
	}

	raw, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := strings.TrimSuffix(p.Record.BaseURL, "/") + "/chat/completions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+p.Record.APIKey)
	req.Header.Set("Accept", "application/json")

	resp, err := p.HTTP.Do(req)
	if err != nil {
		return nil, fmt.Errorf("call %s: %w", p.Record.Name, err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		// Surface the vendor's own error message so the admin can see
		// exactly what's wrong (bad key, model name, quota, …).
		return nil, fmt.Errorf("%s returned %d: %s", p.Record.Name, resp.StatusCode, truncate(string(respBody), 500))
	}

	var parsed chatResponse
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return nil, fmt.Errorf("parse response: %w (body=%s)", err, truncate(string(respBody), 500))
	}
	if parsed.Error != nil {
		return nil, fmt.Errorf("%s api error: %s", p.Record.Name, parsed.Error.Message)
	}
	if len(parsed.Choices) == 0 {
		return nil, errors.New("provider returned no choices")
	}

	return &GenerateResult{
		Content:          parsed.Choices[0].Message.Content,
		PromptTokens:     parsed.Usage.PromptTokens,
		CompletionTokens: parsed.Usage.CompletionTokens,
		FinishReason:     parsed.Choices[0].FinishReason,
	}, nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}

// ProviderManager keeps an in-memory cache of enabled providers, sorted
// by priority. Reload() is called on bootstrap and after admin edits.
type ProviderManager struct {
	store *Store

	mu        sync.RWMutex
	providers []*LLMProvider
}

func NewProviderManager(store *Store) *ProviderManager {
	return &ProviderManager{store: store}
}

func (m *ProviderManager) Reload(_ context.Context) error {
	records, err := m.store.ListEnabledProviders()
	if err != nil {
		return err
	}
	out := make([]*LLMProvider, 0, len(records))
	for _, r := range records {
		out = append(out, &LLMProvider{
			Record: r,
			HTTP:   &http.Client{Timeout: 90 * time.Second},
		})
	}
	m.mu.Lock()
	m.providers = out
	m.mu.Unlock()
	return nil
}

func (m *ProviderManager) Snapshot() []*LLMProvider {
	m.mu.RLock()
	defer m.mu.RUnlock()
	cp := make([]*LLMProvider, len(m.providers))
	copy(cp, m.providers)
	return cp
}
