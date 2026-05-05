package main

import (
	"strings"
	"unicode"
)

// PromptScreener pre-filters user input before we call any LLM. The
// goal is *not* to be a perfect content classifier — it's to reject the
// cheap, high-volume abuse patterns that cost us tokens for zero
// product value. Anything that gets past this layer goes through the
// LLM, where the JSON+ID constraint does the real heavy lifting.
//
// Design rules:
//   - False positives must be rare. A real user typing "今天去咖啡馆"
//     must always pass.
//   - Detection is purely lexical (no model call). Anything that needs
//     semantic understanding belongs in the LLM layer or a future
//     classifier sidecar.
//   - We log rejection reasons so the admin can see what's getting
//     blocked and tune.
type PromptScreener struct{}

// ScreenResult is the screener's verdict. When Allow=false the
// caller should return the user a polite, specific reason.
type ScreenResult struct {
	Allow      bool
	Reason     string // user-presentable rejection reason
	DetectorID string // internal tag for logs/analytics
}

// promptMaxLength is generous — outfit prompts are usually < 50
// characters, but users sometimes paste full scenarios. 400 chars
// covers any legitimate use; longer means abuse or LLM injection.
const promptMaxLength = 400

// nonOutfitKeywords are obvious red-flag terms. We deliberately keep
// the list short and tightly scoped — broader filtering belongs in
// the system prompt. These are things no real outfit conversation
// would ever contain. Each line is a category for easier review.
var nonOutfitKeywords = []string{
	// Prompt-injection / jailbreak attempts
	"忽略之前", "ignore previous", "ignore above", "system prompt",
	"system:", "你现在是", "你不是", "扮演", "act as", "pretend",
	"jailbreak", "developer mode", "dan mode",

	// General-knowledge / chatbot probing
	"是什么意思", "解释一下", "告诉我关于", "什么是", "为什么",
	"how to", "what is", "explain", "tell me about",

	// Code / technical
	"```", "function", "代码", "编程", "python", "javascript", "sql",
	"```python", "```js",

	// Math
	"计算", "等于多少", "求解", "方程", "微积分", "求导",

	// News / politics / sensitive
	"新闻", "政治", "政府", "习近平", "总统", "战争", "疫情",

	// Generic chat fishing
	"讲个笑话", "写首诗", "写一篇", "翻译", "translate",
}

// outfitContextKeywords are positive signals — at least one of these
// (or the prompt being short and casual) usually means it's a real
// outfit query. We only use this as a "safety net" for borderline
// cases.
var outfitContextKeywords = []string{
	"穿", "搭配", "衣", "裤", "裙", "鞋", "包", "配", "套",
	"约会", "面试", "工作", "通勤", "聚会", "出门", "开会", "旅游",
	"咖啡", "餐厅", "公园", "运动", "购物", "见", "今天", "明天",
	"风格", "颜色", "夏", "冬", "春", "秋", "正式", "休闲", "暖", "冷",
	"outfit", "wear", "look", "style",
}

// hasLongRepeat catches things like "啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊啊"
// which is a common pattern when users mash keys to test the system.
// Go's RE2 has no backreferences, so we scan manually — runs of any
// single rune length >= threshold are flagged.
func hasLongRepeat(s string, threshold int) bool {
	var prev rune
	streak := 0
	first := true
	for _, r := range s {
		if first || r != prev {
			prev = r
			streak = 1
			first = false
			continue
		}
		streak++
		if streak >= threshold {
			return true
		}
	}
	return false
}

// Screen runs every fast lexical check we have. Returns the first
// rejection reason if any, else allow.
func (s *PromptScreener) Screen(prompt string) ScreenResult {
	trimmed := strings.TrimSpace(prompt)

	// Empty prompt is allowed — outfit.go falls back to a default.
	if trimmed == "" {
		return ScreenResult{Allow: true, DetectorID: "empty_default"}
	}

	if len([]rune(trimmed)) > promptMaxLength {
		return ScreenResult{
			Allow:      false,
			Reason:     "请把穿搭描述缩短到 200 字以内（例如：今天去咖啡馆 / 通勤偏正式）",
			DetectorID: "too_long",
		}
	}

	lower := strings.ToLower(trimmed)

	// Hard reject on prompt-injection / jailbreak / off-topic
	// keywords. We check substring on the lowercased input so
	// trivial casing tricks don't bypass.
	for _, kw := range nonOutfitKeywords {
		if strings.Contains(lower, strings.ToLower(kw)) {
			return ScreenResult{
				Allow:      false,
				Reason:     "我只能帮你搭配衣橱里的衣服，其他问题暂不支持～",
				DetectorID: "non_outfit_keyword:" + kw,
			}
		}
	}

	// Repeated character spam — people don't naturally type that.
	if hasLongRepeat(trimmed, 16) {
		return ScreenResult{
			Allow:      false,
			Reason:     "请描述一下你今天的场景或喜好，例如：今天去面试。",
			DetectorID: "char_spam",
		}
	}

	// Excessive ASCII ratio in a Chinese-first product is suspicious.
	// Real Chinese users sometimes mix English ("去 mall 逛街") but a
	// 90%+ ASCII prompt is almost always copy-paste of foreign text.
	if asciiRatio(trimmed) > 0.92 && len([]rune(trimmed)) > 30 {
		return ScreenResult{
			Allow:      false,
			Reason:     "请用中文描述你的搭配需求～",
			DetectorID: "ascii_ratio_high",
		}
	}

	// Final check: long-ish prompts that contain *zero* outfit-related
	// words are likely off-topic. Short prompts get the benefit of the
	// doubt — "随便" / "夏日" are valid even without outfit verbs.
	if len([]rune(trimmed)) > 25 && !containsAnyKeyword(lower, outfitContextKeywords) {
		return ScreenResult{
			Allow:      false,
			Reason:     "请告诉我今天的场景或风格，例如：今天去面试 / 想穿轻松一点。",
			DetectorID: "no_outfit_signal",
		}
	}

	return ScreenResult{Allow: true, DetectorID: "ok"}
}

func containsAnyKeyword(text string, keywords []string) bool {
	for _, kw := range keywords {
		if strings.Contains(text, kw) {
			return true
		}
	}
	return false
}

func asciiRatio(s string) float64 {
	if s == "" {
		return 0
	}
	asciiCount := 0
	total := 0
	for _, r := range s {
		if unicode.IsSpace(r) {
			continue
		}
		total++
		if r < 128 {
			asciiCount++
		}
	}
	if total == 0 {
		return 0
	}
	return float64(asciiCount) / float64(total)
}
