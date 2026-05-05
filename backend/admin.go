package main

import (
	"context"
	_ "embed"
	"fmt"
	"html/template"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// Templates are embedded into the binary so the operator can deploy a
// single artifact without worrying about asset paths.
var (
	//go:embed templates/layout.html
	layoutHTML string

	//go:embed templates/login.html
	loginHTML string

	//go:embed templates/home.html
	homeHTML string

	//go:embed templates/providers.html
	providersHTML string

	//go:embed templates/logs.html
	logsHTML string

	//go:embed templates/test.html
	testHTML string

	//go:embed templates/style.css
	adminCSS []byte
)

var adminTemplates = func() map[string]*template.Template {
	parse := func(name, body string) *template.Template {
		t := template.New("layout").Funcs(template.FuncMap{
			"formatTime": func(unix int64) string {
				if unix == 0 {
					return ""
				}
				return time.Unix(unix, 0).Local().Format("2006-01-02 15:04:05")
			},
			"truncate": truncate,
			"add":      func(a, b int) int { return a + b },
			"sub":      func(a, b int) int { return a - b },
			"statusBadge": func(status string) template.HTML {
				class := "badge"
				switch status {
				case "ok":
					class = "badge badge-ok"
				case "rate_limited":
					class = "badge badge-warn"
				case "provider_error", "invalid_output", "bad_request":
					class = "badge badge-err"
				}
				return template.HTML(fmt.Sprintf(`<span class="%s">%s</span>`, class, template.HTMLEscapeString(status)))
			},
		})
		t = template.Must(t.Parse(layoutHTML))
		t = template.Must(t.New(name).Parse(body))
		return t
	}
	return map[string]*template.Template{
		"login":     parse("content", loginHTML),
		"home":      parse("content", homeHTML),
		"providers": parse("content", providersHTML),
		"logs":      parse("content", logsHTML),
		"test":      parse("content", testHTML),
	}
}()

type adminPageData struct {
	Title       string
	ActiveTab   string
	FlashOK     string
	FlashError  string
	AdminUser   string
	Data        any
}

func (a *App) renderAdmin(w http.ResponseWriter, r *http.Request, name string, page *adminPageData) {
	tpl, ok := adminTemplates[name]
	if !ok {
		http.Error(w, "template not found", http.StatusInternalServerError)
		return
	}
	if page == nil {
		page = &adminPageData{}
	}
	if admin, _ := a.loadAdmin(r); admin != nil {
		page.AdminUser = admin.Username
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := tpl.ExecuteTemplate(w, "layout", page); err != nil {
		http.Error(w, "render: "+err.Error(), http.StatusInternalServerError)
	}
}

// ===== Login / logout / change password =====

func (a *App) handleAdminLoginGet(w http.ResponseWriter, r *http.Request) {
	a.renderAdmin(w, r, "login", &adminPageData{
		Title:     "登录",
		ActiveTab: "login",
		FlashError: r.URL.Query().Get("err"),
	})
}

func (a *App) handleAdminLoginPost(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	username := strings.TrimSpace(r.PostForm.Get("username"))
	password := r.PostForm.Get("password")

	admin, err := a.Store.FindAdminByUsername(username)
	if err != nil || admin == nil || !CheckPassword(password, admin.PasswordHash) {
		// Tiny constant-time delay so timing attacks against username
		// existence aren't trivial. Not perfect, but cheap.
		time.Sleep(150 * time.Millisecond)
		http.Redirect(w, r, "/admin/login?err=用户名或密码错误", http.StatusFound)
		return
	}

	sess, err := a.Store.CreateSession(admin.ID, sessionTTL)
	if err != nil {
		http.Error(w, "create session: "+err.Error(), http.StatusInternalServerError)
		return
	}
	setSessionCookie(w, sess.Token, sess.ExpiresAt)
	http.Redirect(w, r, "/admin/", http.StatusFound)
}

func (a *App) handleAdminLogout(w http.ResponseWriter, r *http.Request) {
	if c, err := r.Cookie(sessionCookieName); err == nil {
		_ = a.Store.DeleteSession(c.Value)
	}
	clearSessionCookie(w)
	http.Redirect(w, r, "/admin/login", http.StatusFound)
}

func (a *App) handleAdminChangePassword(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	current := r.PostForm.Get("current_password")
	newPW := r.PostForm.Get("new_password")
	confirm := r.PostForm.Get("confirm_password")

	admin, err := a.loadAdmin(r)
	if err != nil || admin == nil {
		http.Redirect(w, r, "/admin/login", http.StatusFound)
		return
	}

	flashErr := ""
	flashOK := ""
	switch {
	case !CheckPassword(current, admin.PasswordHash):
		flashErr = "当前密码不正确"
	case len(newPW) < 8:
		flashErr = "新密码至少 8 位"
	case newPW != confirm:
		flashErr = "两次输入的新密码不一致"
	default:
		hash, err := HashPassword(newPW)
		if err != nil {
			flashErr = "加密失败：" + err.Error()
		} else if err := a.Store.UpdateAdminPassword(admin.ID, hash); err != nil {
			flashErr = "更新失败：" + err.Error()
		} else {
			flashOK = "密码已更新"
		}
	}

	stats, _ := a.Store.RecentStats()
	a.renderAdmin(w, r, "home", &adminPageData{
		Title:      "总览",
		ActiveTab:  "home",
		FlashOK:    flashOK,
		FlashError: flashErr,
		Data:       stats,
	})
}

// ===== Home =====

func (a *App) handleAdminHome(w http.ResponseWriter, r *http.Request) {
	stats, _ := a.Store.RecentStats()
	a.renderAdmin(w, r, "home", &adminPageData{
		Title:     "总览",
		ActiveTab: "home",
		Data:      stats,
	})
}

// ===== Providers =====

type providersPageData struct {
	Providers []*ProviderRecord
}

func (a *App) handleAdminProviders(w http.ResponseWriter, r *http.Request) {
	list, err := a.Store.ListProviders()
	if err != nil {
		http.Error(w, "list providers: "+err.Error(), http.StatusInternalServerError)
		return
	}
	a.renderAdmin(w, r, "providers", &adminPageData{
		Title:     "AI 服务商",
		ActiveTab: "providers",
		FlashOK:   r.URL.Query().Get("ok"),
		FlashError: r.URL.Query().Get("err"),
		Data:      &providersPageData{Providers: list},
	})
}

func (a *App) handleAdminProviderCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	name := strings.TrimSpace(r.PostForm.Get("name"))
	baseURL := strings.TrimSpace(r.PostForm.Get("base_url"))
	apiKey := strings.TrimSpace(r.PostForm.Get("api_key"))
	model := strings.TrimSpace(r.PostForm.Get("model"))
	priorityStr := strings.TrimSpace(r.PostForm.Get("priority"))
	notes := strings.TrimSpace(r.PostForm.Get("notes"))
	enabled := r.PostForm.Get("enabled") == "1"

	if name == "" || baseURL == "" || apiKey == "" || model == "" {
		http.Redirect(w, r, "/admin/providers?err=name/base_url/api_key/model 都必填", http.StatusFound)
		return
	}
	if !strings.HasPrefix(baseURL, "https://") && !strings.HasPrefix(baseURL, "http://") {
		http.Redirect(w, r, "/admin/providers?err=base_url 必须以 http(s):// 开头", http.StatusFound)
		return
	}

	priority := 100
	if priorityStr != "" {
		if n, err := strconv.Atoi(priorityStr); err == nil {
			priority = n
		}
	}

	p := &ProviderRecord{
		Name:     name,
		BaseURL:  baseURL,
		APIKey:   apiKey,
		Model:    model,
		Enabled:  enabled,
		Priority: priority,
		Notes:    notes,
	}
	if err := a.Store.CreateProvider(p); err != nil {
		http.Redirect(w, r, "/admin/providers?err="+url(err.Error()), http.StatusFound)
		return
	}
	if err := a.Providers.Reload(context.Background()); err != nil {
		http.Redirect(w, r, "/admin/providers?err=reload 失败："+url(err.Error()), http.StatusFound)
		return
	}
	http.Redirect(w, r, "/admin/providers?ok=已添加 "+url(name), http.StatusFound)
}

func (a *App) handleAdminProviderToggle(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "bad id", http.StatusBadRequest)
		return
	}
	if err := a.Store.ToggleProvider(id); err != nil {
		http.Redirect(w, r, "/admin/providers?err="+url(err.Error()), http.StatusFound)
		return
	}
	if err := a.Providers.Reload(context.Background()); err != nil {
		http.Redirect(w, r, "/admin/providers?err=reload 失败", http.StatusFound)
		return
	}
	http.Redirect(w, r, "/admin/providers?ok=已切换", http.StatusFound)
}

func (a *App) handleAdminProviderDelete(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, "bad id", http.StatusBadRequest)
		return
	}
	if err := a.Store.DeleteProvider(id); err != nil {
		http.Redirect(w, r, "/admin/providers?err="+url(err.Error()), http.StatusFound)
		return
	}
	if err := a.Providers.Reload(context.Background()); err != nil {
		http.Redirect(w, r, "/admin/providers?err=reload 失败", http.StatusFound)
		return
	}
	http.Redirect(w, r, "/admin/providers?ok=已删除", http.StatusFound)
}

// ===== Logs =====

func (a *App) handleAdminLogs(w http.ResponseWriter, r *http.Request) {
	limit := 200
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 1000 {
			limit = n
		}
	}
	logs, err := a.Store.RecentCallLogs(limit)
	if err != nil {
		http.Error(w, "list logs: "+err.Error(), http.StatusInternalServerError)
		return
	}
	a.renderAdmin(w, r, "logs", &adminPageData{
		Title:     "调用日志",
		ActiveTab: "logs",
		Data:      logs,
	})
}

// ===== Test page =====

type testPageData struct {
	Providers       []*ProviderRecord
	Result          string
	Error           string
	ChosenProvider  string
}

func (a *App) handleAdminTestGet(w http.ResponseWriter, r *http.Request) {
	list, _ := a.Store.ListProviders()
	a.renderAdmin(w, r, "test", &adminPageData{
		Title:     "联调测试",
		ActiveTab: "test",
		Data:      &testPageData{Providers: list},
	})
}

func (a *App) handleAdminTestPost(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	idStr := r.PostForm.Get("provider_id")
	prompt := strings.TrimSpace(r.PostForm.Get("prompt"))
	if prompt == "" {
		prompt = "请用一句话夸奖一下衣序这个 App。"
	}

	list, _ := a.Store.ListProviders()
	page := &testPageData{Providers: list}

	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		page.Error = "请选择一个 provider"
		a.renderAdmin(w, r, "test", &adminPageData{
			Title:     "联调测试",
			ActiveTab: "test",
			Data:      page,
		})
		return
	}

	var record *ProviderRecord
	for _, p := range list {
		if p.ID == id {
			record = p
			break
		}
	}
	if record == nil {
		page.Error = "找不到该 provider"
		a.renderAdmin(w, r, "test", &adminPageData{
			Title:     "联调测试",
			ActiveTab: "test",
			Data:      page,
		})
		return
	}

	provider := &LLMProvider{Record: record}
	ctx, cancel := context.WithTimeout(r.Context(), 60*time.Second)
	defer cancel()

	result, err := provider.Generate(ctx, "你是一个测试用的 echo 助手，请简洁回复。", prompt, GenerateOptions{
		Timeout: 60 * time.Second,
	})

	page.ChosenProvider = record.Name
	if err != nil {
		page.Error = err.Error()
	} else {
		page.Result = fmt.Sprintf("✓ 来自 %s/%s（%d+%d tokens）：\n\n%s",
			record.Name, record.Model, result.PromptTokens, result.CompletionTokens, result.Content)
	}
	a.renderAdmin(w, r, "test", &adminPageData{
		Title:     "联调测试",
		ActiveTab: "test",
		Data:      page,
	})
}

// url is a tiny query-escape shortcut.
func url(s string) string {
	r := strings.NewReplacer(
		"%", "%25",
		"&", "%26",
		"#", "%23",
		"+", "%2B",
		"?", "%3F",
		" ", "%20",
		"\n", "%0A",
		"\r", "%0D",
	)
	return r.Replace(s)
}

// ensureAdminTemplatesParsed is a compile-time guarantee that the
// embedded templates are non-empty. Bumping a template name without
// updating the var here will fail to build, which is what we want.
var _ = []string{layoutHTML, loginHTML, homeHTML, providersHTML, logsHTML, testHTML}
