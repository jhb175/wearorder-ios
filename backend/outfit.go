package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// ===== Wire types =====

// generateOutfitRequest is what the iOS app POSTs. It mirrors the
// data already assembled client-side by AIWardrobeContextBuilder, so
// the server's only job is "ask an LLM to pick from this list".
type generateOutfitRequest struct {
	UserPrompt     string                 `json:"user_prompt"`
	WeatherSummary string                 `json:"weather_summary"`
	Candidates     map[string][]itemDTO   `json:"candidates"` // slot -> items
	ClientHints    map[string]any         `json:"client_hints,omitempty"`
}

type itemDTO struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	Color      string   `json:"color"`
	Season     string   `json:"season"`
	StyleTags  []string `json:"style_tags,omitempty"`
	IsFavorite bool     `json:"is_favorite,omitempty"`
}

// generateOutfitResponse is what the client expects back. The IDs are
// strings (UUID) — caller cross-references against its own pool.
type generateOutfitResponse struct {
	Title              string  `json:"title"`
	Reason             string  `json:"reason"`
	TopItemID          *string `json:"top_item_id,omitempty"`
	BottomItemID       *string `json:"bottom_item_id,omitempty"`
	OuterwearItemID    *string `json:"outerwear_item_id,omitempty"`
	ShoesItemID        *string `json:"shoes_item_id,omitempty"`
	BagItemID          *string `json:"bag_item_id,omitempty"`
	AccessoryItemID    *string `json:"accessory_item_id,omitempty"`
	ProviderName       string  `json:"provider_name"`
	ModelIdentifier    string  `json:"model_identifier"`
	PromptTokens       int     `json:"prompt_tokens,omitempty"`
	CompletionTokens   int     `json:"completion_tokens,omitempty"`
}

// llmOutput is the JSON shape we ask the LLM to produce. Keep it close
// to AIGeneratedOutfit on the iOS side so the client mapping is 1:1.
type llmOutput struct {
	Title              string  `json:"title"`
	Reason             string  `json:"reason"`
	TopItemID          *string `json:"top_item_id"`
	BottomItemID       *string `json:"bottom_item_id"`
	OuterwearItemID    *string `json:"outerwear_item_id"`
	ShoesItemID        *string `json:"shoes_item_id"`
	BagItemID          *string `json:"bag_item_id"`
	AccessoryItemID    *string `json:"accessory_item_id"`
}

// ===== Handler =====

const (
	deviceIDHeader = "X-Device-ID"
)

var slotOrder = []string{"top", "bottom", "outerwear", "shoes", "bag", "accessory"}

var slotChineseLabel = map[string]string{
	"top":       "上装 top",
	"bottom":    "下装 bottom",
	"outerwear": "外套 outerwear",
	"shoes":     "鞋 shoes",
	"bag":       "包 bag",
	"accessory": "配饰 accessory",
}

func (a *App) handleGenerateOutfit(w http.ResponseWriter, r *http.Request) {
	deviceID := strings.TrimSpace(r.Header.Get(deviceIDHeader))
	if deviceID == "" {
		writeJSONError(w, http.StatusBadRequest, "missing X-Device-ID header")
		return
	}

	if r.ContentLength > 256*1024 {
		writeJSONError(w, http.StatusRequestEntityTooLarge, "request body too large")
		return
	}

	var req generateOutfitRequest
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 256*1024)).Decode(&req); err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid JSON: "+err.Error())
		return
	}
	if err := validateRequest(&req); err != nil {
		writeJSONError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Rate limit before doing any provider work — abusive callers
	// should never reach the upstream.
	if allowed, used, err := a.RateLimit.Allow(deviceID); err != nil {
		writeJSONError(w, http.StatusInternalServerError, "rate limit check failed")
		return
	} else if !allowed {
		_ = a.Store.RecordCall(&CallLog{
			DeviceID:     deviceID,
			ProviderName: "-",
			Status:       "rate_limited",
			UserPrompt:   truncate(req.UserPrompt, 200),
		})
		w.Header().Set("X-RateLimit-Used", fmt.Sprint(used))
		writeJSONError(w, http.StatusTooManyRequests, fmt.Sprintf("rate limit exceeded (%d/day)", a.Config.RateLimitPerDay))
		return
	}

	providers := a.Providers.Snapshot()
	if len(providers) == 0 {
		_ = a.Store.RecordCall(&CallLog{
			DeviceID:     deviceID,
			ProviderName: "-",
			Status:       "bad_request",
			UserPrompt:   truncate(req.UserPrompt, 200),
			ErrorMessage: "no providers configured",
		})
		writeJSONError(w, http.StatusServiceUnavailable, "AI 服务尚未配置，请稍后再试。")
		return
	}

	systemPrompt := buildSystemPrompt()
	userPrompt := buildUserPrompt(&req)
	timeout := time.Duration(a.Config.RequestTimeoutSec) * time.Second
	if timeout <= 0 {
		timeout = 60 * time.Second
	}

	// Try providers in priority order. Surface the first valid result.
	var lastErr error
	for _, p := range providers {
		start := time.Now()
		genResult, err := p.Generate(r.Context(), systemPrompt, userPrompt, GenerateOptions{
			JSONMode: true,
			Timeout:  timeout,
		})
		latency := int(time.Since(start).Milliseconds())

		if err != nil {
			_ = a.Store.RecordCall(&CallLog{
				DeviceID:     deviceID,
				ProviderName: p.Record.Name,
				Status:       "provider_error",
				LatencyMs:    latency,
				UserPrompt:   truncate(req.UserPrompt, 200),
				ErrorMessage: truncate(err.Error(), 1000),
			})
			lastErr = err
			continue
		}

		// Validate the LLM output against the candidate pool.
		out, validateErr := validateLLMOutput(genResult.Content, &req)
		if validateErr != nil {
			_ = a.Store.RecordCall(&CallLog{
				DeviceID:         deviceID,
				ProviderName:     p.Record.Name,
				Status:           "invalid_output",
				LatencyMs:        latency,
				PromptTokens:     genResult.PromptTokens,
				CompletionTokens: genResult.CompletionTokens,
				UserPrompt:       truncate(req.UserPrompt, 200),
				ErrorMessage:     truncate(validateErr.Error(), 1000),
			})
			lastErr = validateErr
			continue
		}

		// Success.
		resp := buildResponse(out, p.Record, genResult)
		_ = a.Store.RecordCall(&CallLog{
			DeviceID:         deviceID,
			ProviderName:     p.Record.Name,
			Status:           "ok",
			LatencyMs:        latency,
			PromptTokens:     genResult.PromptTokens,
			CompletionTokens: genResult.CompletionTokens,
			UserPrompt:       truncate(req.UserPrompt, 200),
		})
		writeJSON(w, http.StatusOK, resp)
		return
	}

	msg := "AI 服务暂时不可用，请稍后再试。"
	if lastErr != nil {
		msg = fmt.Sprintf("AI 服务暂时不可用：%s", truncate(lastErr.Error(), 200))
	}
	writeJSONError(w, http.StatusBadGateway, msg)
}

// ===== Validation =====

func validateRequest(req *generateOutfitRequest) error {
	if req.Candidates == nil {
		return errors.New("candidates missing")
	}

	hasAny := false
	for slot, items := range req.Candidates {
		if !validSlot(slot) {
			return fmt.Errorf("unknown slot %q", slot)
		}
		if len(items) > 16 {
			return fmt.Errorf("too many candidates for slot %q (max 16)", slot)
		}
		for _, it := range items {
			if strings.TrimSpace(it.ID) == "" || strings.TrimSpace(it.Name) == "" {
				return fmt.Errorf("invalid item in slot %q", slot)
			}
		}
		if len(items) > 0 {
			hasAny = true
		}
	}
	if !hasAny {
		return errors.New("no candidates supplied")
	}

	total := 0
	for _, items := range req.Candidates {
		total += len(items)
	}
	if total > 64 {
		return errors.New("total candidates exceed 64 — pre-filter on client")
	}

	if len(req.UserPrompt) > 2000 {
		return errors.New("user_prompt too long")
	}

	return nil
}

func validSlot(s string) bool {
	for _, k := range slotOrder {
		if k == s {
			return true
		}
	}
	return false
}

// validateLLMOutput parses the LLM's JSON, then cross-references each
// returned ID against the slot's candidate pool. We mirror the iOS
// AIOutfitValidator semantics so end-to-end behavior stays consistent.
func validateLLMOutput(raw string, req *generateOutfitRequest) (*llmOutput, error) {
	cleaned := stripJSONFence(raw)
	var out llmOutput
	if err := json.Unmarshal([]byte(cleaned), &out); err != nil {
		return nil, fmt.Errorf("LLM 输出不是合法 JSON：%w", err)
	}

	candidatePool := make(map[string]map[string]bool, len(req.Candidates))
	for slot, items := range req.Candidates {
		ids := make(map[string]bool, len(items))
		for _, it := range items {
			ids[strings.ToLower(it.ID)] = true
		}
		candidatePool[slot] = ids
	}

	check := func(slot string, idPtr **string) error {
		if *idPtr == nil {
			return nil
		}
		v := strings.ToLower(strings.TrimSpace(**idPtr))
		if v == "" || v == "null" {
			*idPtr = nil
			return nil
		}
		if !candidatePool[slot][v] {
			return fmt.Errorf("LLM 在 %s 槽返回了未知或错配的 ID", slot)
		}
		// Normalize back into the output struct.
		**idPtr = v
		return nil
	}

	if err := check("top", &out.TopItemID); err != nil {
		return nil, err
	}
	if err := check("bottom", &out.BottomItemID); err != nil {
		return nil, err
	}
	if err := check("outerwear", &out.OuterwearItemID); err != nil {
		return nil, err
	}
	if err := check("shoes", &out.ShoesItemID); err != nil {
		return nil, err
	}
	if err := check("bag", &out.BagItemID); err != nil {
		return nil, err
	}
	if err := check("accessory", &out.AccessoryItemID); err != nil {
		return nil, err
	}

	if out.TopItemID == nil && out.BottomItemID == nil {
		return nil, errors.New("LLM 没有挑选 top 或 bottom，搭配不完整")
	}

	out.Title = strings.TrimSpace(out.Title)
	out.Reason = strings.TrimSpace(out.Reason)
	if out.Title == "" {
		out.Title = "今日搭配"
	}
	if out.Reason == "" {
		out.Reason = "结合天气和你的衣橱挑选的一套搭配。"
	}

	return &out, nil
}

// stripJSONFence removes the ```json fences some models love to add
// even when asked for raw JSON.
func stripJSONFence(s string) string {
	s = strings.TrimSpace(s)
	if !strings.HasPrefix(s, "```") {
		return s
	}
	s = strings.TrimPrefix(s, "```json")
	s = strings.TrimPrefix(s, "```")
	s = strings.TrimSpace(s)
	s = strings.TrimSuffix(s, "```")
	return strings.TrimSpace(s)
}

// ===== Prompt building =====

func buildSystemPrompt() string {
	return `你是衣序 App 的 AI 搭配师。从用户提供的"可选单品"列表里挑选一套日常搭配，
输出标题、理由，以及 6 个槽位（top/bottom/outerwear/shoes/bag/accessory）的单品 ID。

严格遵守：
1. 每个 *_item_id 字段，只能填写列表里出现过的 ID。绝不发明 ID。
2. ID 一定要从"# 上装/下装/..."对应的小节里挑，不要把鞋的 ID 放进上装。
3. 如果某个槽位没有合适的，把对应字段设为 null。
4. 上装、下装尽量都填；连衣裙类作为 bottom 时上装可以为 null。
5. 标题 6-12 个汉字；理由 30-60 个汉字，结合天气和场景给出穿搭建议。
6. 必须返回合法 JSON 对象，键名严格匹配：
{"title": "...", "reason": "...", "top_item_id": "...", "bottom_item_id": "...", "outerwear_item_id": null, "shoes_item_id": "...", "bag_item_id": null, "accessory_item_id": null}`
}

func buildUserPrompt(req *generateOutfitRequest) string {
	var b strings.Builder
	prompt := strings.TrimSpace(req.UserPrompt)
	if prompt == "" {
		prompt = "今日合适的搭配"
	}
	weather := strings.TrimSpace(req.WeatherSummary)
	if weather == "" {
		weather = "天气未知"
	}

	fmt.Fprintf(&b, "用户想要：%s\n", prompt)
	fmt.Fprintf(&b, "当前天气：%s\n\n", weather)
	b.WriteString("可选单品（按槽位分组，每行一件，格式：[id] 名字·颜色·季节·标签）：\n")

	for _, slot := range slotOrder {
		items := req.Candidates[slot]
		if len(items) == 0 {
			continue
		}
		fmt.Fprintf(&b, "# %s\n", slotChineseLabel[slot])
		for _, it := range items {
			tagSuffix := ""
			if len(it.StyleTags) > 0 {
				maxTags := 3
				if len(it.StyleTags) < maxTags {
					maxTags = len(it.StyleTags)
				}
				tagSuffix = "·" + strings.Join(it.StyleTags[:maxTags], "/")
			}
			star := ""
			if it.IsFavorite {
				star = " ★"
			}
			fmt.Fprintf(&b, "[%s] %s·%s·%s%s%s\n",
				strings.ToLower(it.ID), it.Name, it.Color, it.Season, tagSuffix, star)
		}
	}

	b.WriteString("\n请只返回 JSON 对象本身，不要加 ```json 代码块，不要加任何其它文字。")

	return b.String()
}

// ===== Response building =====

func buildResponse(out *llmOutput, p *ProviderRecord, genResult *GenerateResult) *generateOutfitResponse {
	return &generateOutfitResponse{
		Title:            out.Title,
		Reason:           out.Reason,
		TopItemID:        out.TopItemID,
		BottomItemID:     out.BottomItemID,
		OuterwearItemID:  out.OuterwearItemID,
		ShoesItemID:      out.ShoesItemID,
		BagItemID:        out.BagItemID,
		AccessoryItemID:  out.AccessoryItemID,
		ProviderName:     p.Name,
		ModelIdentifier:  fmt.Sprintf("%s/%s", p.Name, p.Model),
		PromptTokens:     genResult.PromptTokens,
		CompletionTokens: genResult.CompletionTokens,
	}
}

// ===== JSON helpers =====

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(v)
}

func writeJSONError(w http.ResponseWriter, code int, message string) {
	writeJSON(w, code, map[string]string{"error": message})
}

