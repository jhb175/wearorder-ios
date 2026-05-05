# IP 直连快速部署（内部测试用）

适用场景：**内部 TestFlight 测试**，没域名 / 没 ICP / 不想折腾 HTTPS。
等 App 接近上架时再换成 `api.your-domain.com` + Let's Encrypt + ICP 备案。

> ⚠️ **不要用这种方式上 App Store 中国区生产环境**。
> ATS 例外 + IP 直连在审核时可能被要求整改。

---

## 路线全景

```
iOS 模拟器 / 真机
    │
    │ HTTP (明文)，App Transport Security 单 IP 例外
    ▼
腾讯云服务器公网 IP : 80
    │
    │ Nginx 反代
    ▼
127.0.0.1:8080
    │
    ▼
wearorder-api (systemd)
```

---

## Phase 1：服务器初始化

```bash
# SSH 进服务器（用 SSH key，参见 TENCENT_CLOUD_GUIDE.md Phase 1.5）
ssh root@你的服务器IP

# 系统升级 + 装基础包
apt update
apt upgrade -y
apt install -y curl wget nginx git ufw fail2ban

# 防火墙：开 22 + 80
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable
sudo ufw status verbose
```

⚠️ **腾讯云控制台安全组也要开 80 端口**（轻量应用服务器/CVM 控制台 → 防火墙）。

---

## Phase 2：装 Go + 拉代码 + 编译

```bash
# Go 1.22（apt 的 1.19 太老）
cd /tmp
wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
source /etc/profile.d/go.sh

# 拉代码（如果是私有仓库需要先配 GitHub SSH key）
sudo mkdir -p /srv && sudo chown $(whoami) /srv
cd /srv
git clone git@github.com:jhb175/wearorder-ios.git wearorder
cd wearorder

# 一键安装
sudo bash backend/deploy/install.sh
```

---

## Phase 3：配置 + 启动

```bash
# 生成 session secret
openssl rand -hex 32   # 复制输出

# 编辑配置
sudo nano /etc/wearorder/wearorder.env
```

把 SESSION_SECRET 和 ADMIN_INITIAL_PASSWORD 填进去。其他保持默认。

```bash
# 启动
sudo systemctl enable --now wearorder-api
sudo systemctl status wearorder-api    # 应该 active (running)
sudo journalctl -u wearorder-api -f    # 看实时日志，Ctrl-C 退出
```

本机测试：

```bash
curl http://127.0.0.1:8080/healthz   # 应输出 ok
```

---

## Phase 4：Nginx 反代（HTTP-only）

```bash
sudo tee /etc/nginx/sites-available/wearorder-api > /dev/null <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;          # 不限定 server_name，IP 直连

    client_max_body_size 1m;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout                 120s;
        proxy_send_timeout                 120s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/wearorder-api /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

外部测试（在你 Mac 上）：

```bash
curl http://你的服务器IP/healthz   # 应输出 ok
```

如果看到 `ok`，**网络栈通了**。

---

## Phase 5：登录后台 + 加 LLM Provider

浏览器打开：

```
http://你的服务器IP/admin/login
```

> 浏览器会警告"非安全连接" — 内部测试期间忽略，正式上线前必须换 HTTPS。

用 `admin` + 你设的密码登录 → 进 "AI 服务商" → 添加 DeepSeek（或其他）→ "联调测试" 验证 LLM 通路。

---

## Phase 6：iOS App ATS 例外（**关键步骤**）

iOS 默认禁止明文 HTTP，必须在 Info.plist 加例外。

### 6.1 编辑 Info.plist

打开 Xcode → 项目导航器 → 选 `衣橱存储` target → Info → 加入：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>你的服务器IP</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <false/>
        </dict>
    </dict>
</dict>
```

> ⚠️ 替换 `你的服务器IP` 为实际 IP，不带端口、不带协议。例如 `123.45.67.89`。

### 6.2 配置后端 base URL

同样在 Info.plist 加一条：

```xml
<key>WEARORDER_AI_BASE_URL</key>
<string>http://你的服务器IP</string>
```

### 6.3 验证

Build & Run 到模拟器或 TestFlight，进 AI 入口。

第一次调用应该看到客户端发送 POST 到 `http://你的服务器IP/v1/ai/generate-outfit`，服务端 `journalctl -u wearorder-api -f` 能看到对应请求。

---

## 防滥用 / 暴露面收缩

IP 直连意味着任何人扫到你的 IP 都可能撞上后台登录页。建议：

### 限制 admin 后台只能从你 IP 访问

```bash
sudo nano /etc/nginx/sites-available/wearorder-api
# 把 location / 拆成两个：
```

```nginx
# 在 server { } 块里改成这样：

# admin 后台：只允许你家 / 公司 IP
location /admin/ {
    allow 你的家庭公网IP;     # curl ifconfig.me 拿
    allow 你的公司公网IP;
    deny all;
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}

# 公开 API：开放给所有人
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_read_timeout                 120s;
    proxy_send_timeout                 120s;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

这样：
- App 用户能调 `/v1/ai/generate-outfit`（公开）
- 只有你能登 `/admin/`（白名单）
- 外面扫端口的随机 IP 看到 admin 直接 403

---

## 后续切换到 HTTPS + 域名

当你准备上 App Store / 备案完成 / 拿到证书后：

1. 删 Info.plist 里的 ATS 例外块
2. 把 `WEARORDER_AI_BASE_URL` 从 `http://IP` 改成 `https://api.your-domain.com`
3. 服务器侧按 `TENCENT_CLOUD_GUIDE.md` 的 Phase 5/6 走 DNS + certbot

客户端不用动其他代码 — `BackendOutfitConfig` 自动从 Info.plist 读取新值。

---

## 故障排查

| 现象 | 排查 |
|---|---|
| iOS 真机调不通 | 检查 ATS 例外 IP 写对了；用 Safari 在 iPhone 上访问 `http://IP/healthz` 应该看到 `ok` |
| 模拟器调不通 | 同上，模拟器也走真实网络栈，ATS 一样生效 |
| 服务起不来 | `sudo journalctl -u wearorder-api -n 100` 看 panic |
| `curl http://IP` 超时 | 腾讯云安全组 + ufw 必须都开 80 |
| 后台登录返回 403 | nginx 白名单生效中，从你白名单的 IP 访问 |

---

## 完成的状态

跑通这个 quickstart 后，你应该有：

- ✅ 腾讯云服务器跑着 `wearorder-api`
- ✅ Nginx 反代 80 → 8080
- ✅ 浏览器从 `http://IP/admin/` 能登录后台
- ✅ 后台至少配了 1 个 LLM provider，联调测试 OK
- ✅ iOS App Info.plist 加了 ATS 例外 + base URL
- ✅ TestFlight 真机 → AI 入口能生成搭配

**下一步**：内测一段时间稳定后，按 `TENCENT_CLOUD_GUIDE.md` 走域名 + HTTPS + ICP 备案上正式。
