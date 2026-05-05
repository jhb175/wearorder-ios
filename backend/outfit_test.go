package main

import (
	"strings"
	"testing"
)

func TestExtractJSONObject_PureJSON(t *testing.T) {
	in := `{"title":"x","reason":"y","top_item_id":null,"bottom_item_id":null,"outerwear_item_id":null,"shoes_item_id":null,"bag_item_id":null,"accessory_item_id":null}`
	got := extractJSONObject(in)
	if got != in {
		t.Errorf("expected pass-through, got %q", got)
	}
}

func TestExtractJSONObject_Fenced(t *testing.T) {
	in := "```json\n{\"title\":\"x\"}\n```"
	got := extractJSONObject(in)
	if !strings.HasPrefix(got, "{") || !strings.HasSuffix(got, "}") {
		t.Errorf("expected unfenced JSON, got %q", got)
	}
}

func TestExtractJSONObject_WrappedInProse(t *testing.T) {
	in := `好的，这是为您挑选的搭配：

{"title":"通勤简洁","reason":"白衬衫配黑裤简洁干练。","top_item_id":"abc","bottom_item_id":null,"outerwear_item_id":null,"shoes_item_id":null,"bag_item_id":null,"accessory_item_id":null}

希望您喜欢！`
	got := extractJSONObject(in)
	if !strings.HasPrefix(got, "{") {
		t.Errorf("expected leading prose stripped, got %q", got[:min(40, len(got))])
	}
	if !strings.HasSuffix(got, "}") {
		t.Errorf("expected trailing prose stripped, got %q", got[max(0, len(got)-40):])
	}
}

func TestExtractJSONObject_NestedBraces(t *testing.T) {
	in := `Output: {"a": {"nested": true}, "b": "ok"} done`
	got := extractJSONObject(in)
	want := `{"a": {"nested": true}, "b": "ok"}`
	if got != want {
		t.Errorf("nested braces: got %q want %q", got, want)
	}
}

func TestExtractJSONObject_BraceInString(t *testing.T) {
	in := `prefix {"reason": "看起来像 { 的字符不算嵌套"} suffix`
	got := extractJSONObject(in)
	want := `{"reason": "看起来像 { 的字符不算嵌套"}`
	if got != want {
		t.Errorf("brace in string: got %q want %q", got, want)
	}
}

func TestExtractJSONObject_NoJSON(t *testing.T) {
	in := `抱歉，无法理解你的请求。`
	got := extractJSONObject(in)
	if got != "" {
		t.Errorf("no JSON expected empty, got %q", got)
	}
}

func TestExtractJSONObject_UnterminatedReturnsTail(t *testing.T) {
	// Unterminated still returns from first { so the decoder gets a
	// chance to fail with a clearer error.
	in := `prose {"a": 1`
	got := extractJSONObject(in)
	if !strings.HasPrefix(got, "{") {
		t.Errorf("expected tail starting at {, got %q", got)
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
