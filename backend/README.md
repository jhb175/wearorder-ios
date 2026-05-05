# 衣序 AI 后端

OpenAI 兼容协议的 LLM 网关 + 后台管理面板。一个 Go 二进制 + 一个 SQLite 文件，没了。

## 它做什么

- **`POST /v1/ai/generate-outfit`** — iOS 客户端调用：传入候选衣物列表 + 用户 prompt + 天气 → 返回一套 AI 挑选的搭配（含理由）
- **`/admin/`** — 网页后台：登录、配置 LLM 厂商、查看调用日志、做联调测试
- **多 provider failover** — 按 priority 排序，第一个成功的 provider 返回结果，其它按需补救
- **设备级限流** — 每设备每天 N 次（默认 30），保护 LLM 账单
- **OpenAI 兼容协议** — 一套代码接 DeepSeek、腾讯混元、通义千问、Moonshot、智谱 GLM、OpenAI、OpenRouter（含 Claude/Gemini）等所有支持 `POST /chat/completions` 的厂商

## 在腾讯云 Debian 12 上部署

### 一次性准备

```bash
# 1. 装 Go 1.22（apt 的 1.19 太老）
cd /tmp
wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee -a /etc/profile.d/go.sh
source /etc/profile.d/go.sh

# 2. 装 nginx + certbot
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

### 拉代码 & 安装

```bash
# 把整个仓库克隆到 /srv/wearorder（任意路径都行）
sudo mkdir -p /srv && sudo chown $(whoami) /srv
cd /srv
git clone <你的仓库 URL> wearorder
cd wearorder

# 一键安装（编译 + systemd unit + 配置目录）
sudo bash backend/deploy/install.sh
```

### 启动前编辑配置

```bash
# 生成一个 session secret
openssl rand -hex 32

# 编辑配置：写入上面那个 secret + 一个强密码
sudo nano /etc/wearorder/wearorder.env
```

### 启用 + 启动

```bash
sudo systemctl enable --now wearorder-api
sudo journalctl -u wearorder-api -f      # 看日志，里面会有 admin 临时密码
```

### Nginx + HTTPS

```bash
sudo cp backend/deploy/nginx.conf.example /etc/nginx/sites-available/wearorder-api
sudo nano /etc/nginx/sites-available/wearorder-api    # 把 api.your-domain.com 替换成你的域名
sudo ln -s /etc/nginx/sites-available/wearorder-api /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 申请 Let's Encrypt 证书（前提：域名已解析到本机）
sudo certbot --nginx -d api.your-domain.com
```

完成后浏览器打开 `https://api.your-domain.com/admin/` 就能登录。

## 升级流程

```bash
cd /srv/wearorder
git pull
sudo bash backend/deploy/install.sh   # 自动重新编译 + 重启
```

二进制是原子替换，重启零停机感（systemd 会等旧请求完成）。

## 接 LLM 厂商

登录后台 → "服务商" → 添加。常用配置：

| 厂商 | base_url | 备注 |
|---|---|---|
| DeepSeek | `https://api.deepseek.com/v1` | 价格最低、中文好 |
| 腾讯混元 | `https://api.hunyuan.cloud.tencent.com/v1` | 腾讯云内网最快 |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | OpenAI 兼容模式 |
| Moonshot | `https://api.moonshot.cn/v1` | 长上下文 |
| 智谱 GLM | `https://open.bigmodel.cn/api/paas/v4` | 免费额度大 |
| OpenAI | `https://api.openai.com/v1` | 需海外网络 |
| OpenRouter | `https://openrouter.ai/api/v1` | 中转 Claude / Gemini |

建议同时开 **2 家**，priority 一个 100 一个 200。第一家挂了第二家立即接手，用户感知不到。

## 运维

```bash
# 看实时日志
sudo journalctl -u wearorder-api -f

# 看最近一小时的错误
sudo journalctl -u wearorder-api --since "1 hour ago" | grep -E "(error|panic|provider_error)"

# 重启
sudo systemctl restart wearorder-api

# 备份数据库
sudo cp /opt/wearorder/data/wearorder.db ~/wearorder-$(date +%F).db
```

## API 协议

iOS 客户端调用示例：

```http
POST /v1/ai/generate-outfit HTTP/1.1
Content-Type: application/json
X-Device-ID: 6F2A9E12-...

{
  "user_prompt": "今天去咖啡馆",
  "weather_summary": "晴 22°C，体感 21°C",
  "candidates": {
    "top": [
      {"id": "uuid-1", "name": "白衬衫", "color": "白", "season": "四季", "style_tags": ["简洁","通勤"], "is_favorite": true},
      {"id": "uuid-2", "name": "薄荷绿T恤", "color": "薄荷绿", "season": "春夏"}
    ],
    "bottom": [...],
    "shoes": [...]
  }
}
```

返回：

```json
{
  "title": "通勤简约",
  "reason": "白衬衫配深色牛仔裤干净利落，搭配白鞋适合咖啡馆轻松场景。",
  "top_item_id": "uuid-1",
  "bottom_item_id": "uuid-7",
  "shoes_item_id": "uuid-12",
  "provider_name": "DeepSeek-Chat",
  "model_identifier": "DeepSeek-Chat/deepseek-chat",
  "prompt_tokens": 1240,
  "completion_tokens": 180
}
```

## 安全 & 合规

- **生成式 AI 算法备案**：在中国境内对外提供生成式 AI 服务，除 ICP 备案外可能还需要算法备案。咨询律师，预算 ¥3000-8000
- **API Key 存储**：明文存于 SQLite。数据库文件权限 600，只有 wearorder 用户可读
- **管理员认证**：bcrypt 密码哈希 + session cookie + secure + httpOnly
- **限流**：默认每设备每天 30 次，可在 env 调整
- **TLS**：必须经 Nginx 反代，应用本身不对外暴露 HTTP
- **TODO（v0.2）**：Apple JWT 验证（目前只用 X-Device-ID 做限流标识，下一步会加 Sign in with Apple ID 验证）
