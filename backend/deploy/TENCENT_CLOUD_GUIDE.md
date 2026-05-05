# 腾讯云 Debian 12 部署详解

衣序 AI 后端在腾讯云上的完整部署流程。涵盖：服务器准备、域名解析、防火墙、HTTPS 证书、systemd 服务、首次配置、运维。

> **本指南假设**：你已经买好腾讯云服务器（轻量应用服务器或 CVM 都行），登得进去，有一个域名（最好用 `api.your-domain.com` 这种二级域名）。

---

## Phase 0：决策清单（开工前过一遍）

- [ ] **域名怎么搞？**
  - 国内备案：用国内 IP 必须 ICP 备案；如果你的备案是阿里云接的，腾讯云上必须做"新增接入"
  - 海外服务器：腾讯云香港轻量服务器，无需备案，但访问国内会慢一点
  - 海外域名 + 临时测试：`.app` / `.dev` / `.io` 等无需 ICP，但不能上架国区 App Store
- [ ] **二级域名选哪个？**
  - 推荐 `api.your-domain.com`（标准做法，给未来留扩展空间）
- [ ] **服务器规格？**
  - 最小：2 核 2G 40G，腾讯云轻量应用服务器 ¥40-60/月
  - 推荐：2 核 4G，跑得更松快
  - 衣序后端是纯 I/O 等待型（等 LLM 返回），CPU 用得很少
- [ ] **服务器系统？**
  - 选 **Debian 12**。本指南所有命令针对 Debian 12 写的
- [ ] **登录方式？**
  - **强烈推荐改成 SSH key 登录，关掉密码登录**。第一次配置见 Phase 1.5

---

## Phase 1：服务器初始化

### 1.1 连接服务器

第一次登录腾讯云控制台 → 实例 → "登录" → 用密码登录。

```bash
ssh root@你的服务器公网IP
# 输入密码
```

> 后续每次部署都用这条命令进服务器。本文档的"在服务器上执行"指的就是这个 shell。

### 1.2 系统基础升级

```bash
# 在服务器上执行
apt update
apt upgrade -y
apt install -y curl wget nginx git ufw fail2ban
```

### 1.3 创建非 root 用户（可选但推荐）

直接用 root 跑服务是反模式。先创建一个普通用户，后面 sudo 进 root：

```bash
# 在服务器上执行
adduser yourname              # 设置一个强密码
usermod -aG sudo yourname     # 加入 sudo 组
```

---

## Phase 1.5：SSH 安全加固（**强烈推荐做完再继续**）

### 1.5.1 在你**本地 Mac** 生成 SSH key（如果没有）

```bash
# 在本地 Mac 终端执行
ssh-keygen -t ed25519 -C "wearorder-deploy"
# 按回车接受默认路径 ~/.ssh/id_ed25519
# 设一个强密码（每次用 key 时输入，不进任何日志）
```

### 1.5.2 把公钥上传到服务器

```bash
# 在本地 Mac 终端执行
ssh-copy-id root@你的服务器IP
# 输入 root 密码（最后一次）
```

### 1.5.3 验证免密登录

```bash
ssh root@你的服务器IP   # 应该不再提示密码（只问你 key 的 passphrase）
```

### 1.5.4 关闭密码登录（**重要**）

```bash
# 在服务器上执行
nano /etc/ssh/sshd_config
# 找到这两行，确保是这样：
#   PasswordAuthentication no
#   PubkeyAuthentication yes
# 保存退出（Ctrl-O, Enter, Ctrl-X）
systemctl restart ssh
```

> 这一步做完，**只有手里有私钥的人能登录**。即使密码泄露也没用。

### 1.5.5 启用 fail2ban

```bash
# 在服务器上执行
systemctl enable --now fail2ban
fail2ban-client status sshd   # 应该显示 active
```

> fail2ban 会自动 ban 掉暴力尝试 SSH 的 IP。

---

## Phase 2：装 Go 工具链

Debian 12 的 apt 装 Go 是 1.19 版本，**太老不能用**。直接下载官方二进制：

```bash
# 在服务器上执行
cd /tmp
wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
source /etc/profile.d/go.sh
go version    # 应输出 go1.22.5
```

---

## Phase 3：拉代码 + 编译

### 3.1 给 GitHub 配 SSH key（如果是私有仓库）

```bash
# 在服务器上执行
ssh-keygen -t ed25519 -C "tencent-server-deploy"
# 接受默认路径，可以不设密码（仅这台服务器用，方便 cron 自动部署）
cat ~/.ssh/id_ed25519.pub
# 复制输出，加到 GitHub → Settings → SSH and GPG keys → New SSH key
```

### 3.2 克隆 + 编译

```bash
# 在服务器上执行
sudo mkdir -p /srv && sudo chown $(whoami) /srv
cd /srv
git clone git@github.com:jhb175/wearorder-ios.git wearorder
cd wearorder
sudo bash backend/deploy/install.sh
```

`install.sh` 自动做的事：
- 创建 `wearorder` 系统用户
- 在 `/opt/wearorder/` 编译并安装二进制
- 在 `/etc/wearorder/` 写入配置模板
- 安装 systemd 单元

---

## Phase 4：首次配置

### 4.1 生成 session secret

```bash
# 在服务器上执行
openssl rand -hex 32
# 输出一个 64 字符的随机串，复制下来
```

### 4.2 编辑配置

```bash
sudo nano /etc/wearorder/wearorder.env
```

需要改的字段：

```dotenv
LISTEN_ADDR=127.0.0.1:8080
DATA_PATH=/opt/wearorder/data/wearorder.db
ADMIN_USERNAME=admin
ADMIN_INITIAL_PASSWORD=换成一个强密码    # 至少 12 位
SESSION_SECRET=刚才 openssl 生成的 64 字符串
RATE_LIMIT_PER_DAY=30                    # 每个用户每天 30 次
BURST_LIMIT_PER_MINUTE=5                 # 每分钟最多 5 次
REQUEST_TIMEOUT_SEC=60
```

### 4.3 启动服务

```bash
# 在服务器上执行
sudo systemctl enable --now wearorder-api
sudo systemctl status wearorder-api
# 应该显示 active (running)
```

### 4.4 看启动日志（找 admin 临时密码）

```bash
sudo journalctl -u wearorder-api -n 50 --no-pager
```

如果你在配置里**没**填 `ADMIN_INITIAL_PASSWORD`，日志里会有一行：

```
Admin bootstrap password (CHANGE IT AFTER FIRST LOGIN):
  user: admin
  pass: 8a3f2c7d
```

记下来，但**第一次登录后立即去后台换掉**。

### 4.5 本机健康检查

```bash
# 在服务器上执行
curl http://127.0.0.1:8080/healthz
# 应输出: ok
```

如果输出 `ok`，后端服务跑起来了。下一步是把它通过 HTTPS 暴露出去。

---

## Phase 5：DNS + 防火墙

### 5.1 域名 DNS 指向服务器

去你的域名服务商（阿里云 / 腾讯云 / Namecheap 等）控制台：
- 解析记录类型：`A`
- 主机记录：`api`（即 `api.violent.top`）
- 记录值：你的服务器公网 IP
- TTL：默认 600 即可

### 5.2 验证 DNS 生效

```bash
# 在你本地 Mac 上执行
dig +short api.violent.top
# 应输出你的服务器 IP
```

> DNS 全球生效可能需要 5-30 分钟。

### 5.3 开放防火墙

腾讯云有**两道墙**，必须都开：

#### 墙 1：腾讯云控制台安全组

- 控制台 → 轻量应用服务器（或 CVM）→ 防火墙 → 添加规则
- 端口 22（SSH）：TCP，来源建议改成你常用 IP，不要 0.0.0.0/0
- 端口 80（HTTP）：TCP，0.0.0.0/0
- 端口 443（HTTPS）：TCP，0.0.0.0/0

#### 墙 2：服务器系统防火墙（ufw）

```bash
# 在服务器上执行
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

### 5.4 验证外部能访问

```bash
# 在你本地 Mac 上执行
curl http://api.violent.top
# 应该看到 nginx 默认页（"Welcome to nginx"）
# 如果连不上 → 检查腾讯云控制台安全组 + ufw
```

---

## Phase 6：Nginx 反代 + Let's Encrypt HTTPS

### 6.1 装 certbot

```bash
# 在服务器上执行
sudo apt install -y certbot python3-certbot-nginx
```

### 6.2 配置 Nginx 反代

```bash
# 在服务器上执行
sudo cp /srv/wearorder/backend/deploy/nginx.conf.example /etc/nginx/sites-available/wearorder-api
sudo nano /etc/nginx/sites-available/wearorder-api
# 把所有 `api.your-domain.com` 替换成 `api.violent.top`（或你的实际域名）
sudo ln -sf /etc/nginx/sites-available/wearorder-api /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default     # 删默认站，防冲突
sudo nginx -t                                # 应输出 syntax is ok
sudo systemctl reload nginx
```

### 6.3 申请 HTTPS 证书

```bash
# 在服务器上执行
sudo certbot --nginx -d api.violent.top
# 邮箱：填你的邮箱（用于证书过期提醒）
# Terms：A（同意）
# 是否自动重定向 HTTP → HTTPS：选 2（重定向）
```

certbot 会自动：
- 申请证书
- 改 Nginx 配置加 SSL
- 配置自动续期（90 天到期前自动续）

### 6.4 验证 HTTPS

```bash
# 在你本地 Mac 上执行
curl https://api.violent.top/healthz
# 应输出: ok
```

如果你看到 `ok`，**整个网络栈跑通了**。

---

## Phase 7：登录后台 + 加 LLM Provider

### 7.1 浏览器打开后台

```
https://api.violent.top/admin/login
```

用 `admin` + 你设置的临时密码登录。

### 7.2 立即修改密码

进总览页 → "修改密码" → 设置一个新密码。

### 7.3 添加第一个 LLM Provider

进"AI 服务商"页面。推荐起步配置：

#### 主路：DeepSeek（最便宜 + 中文好）

- 名称：`DeepSeek-Chat`
- base_url：`https://api.deepseek.com/v1`
- API Key：去 https://platform.deepseek.com/ 充值后拿
- model：`deepseek-chat`
- priority：`100`（数字越小越优先）
- 启用：✓

#### 备路：通义千问 / 腾讯混元（防 DeepSeek 故障）

- 名称：`Qwen-Plus`
- base_url：`https://dashscope.aliyuncs.com/compatible-mode/v1`
- API Key：阿里云 → 模型服务灵积 → API Key
- model：`qwen-plus`
- priority：`200`
- 启用：✓

### 7.4 联调测试

进"联调测试"页面：
- 选刚加的 provider
- prompt 留默认
- 点"发送"

应该看到 LLM 返回的一句话。**测试成功 → 全栈跑通了**。

---

## Phase 8：iOS App 接入

### 8.1 在 Info.plist 写入 base URL

打开 Xcode → 项目 → `衣橱存储` target → Info.plist：

| Key | Type | Value |
|---|---|---|
| `WEARORDER_AI_BASE_URL` | String | `https://api.violent.top` |

或者用 xcconfig 文件区分 Debug / Release。

### 8.2 验证

打包到 TestFlight，真机测试 AI 入口。如果国行设备能进 AI 页面 → 客户端云端通路打通。

---

## Phase 9：日常运维

### 看日志

```bash
sudo journalctl -u wearorder-api -f          # 实时
sudo journalctl -u wearorder-api --since "1 hour ago" | grep -E "(error|panic)"
```

### 重启 / 更新

```bash
# 在服务器上执行
cd /srv/wearorder
git pull
sudo bash backend/deploy/install.sh   # 自动重新编译 + 重启
```

### 备份数据库

```bash
# 在服务器上执行（写到 cron 每天跑）
sudo cp /opt/wearorder/data/wearorder.db ~/wearorder-$(date +%F).db
# 或更标准的方式：
sudo sqlite3 /opt/wearorder/data/wearorder.db ".backup '/var/backups/wearorder-$(date +%F).db'"
```

### 监控调用情况

后台 → "调用日志" → 看最近 200 条
后台 → "总览" → 看 24 小时统计

### 扩容

CPU / 内存吃紧再说。当前规格能撑到月活 10000 左右。

---

## 故障排查

| 症状 | 检查 |
|---|---|
| 服务起不来 | `sudo journalctl -u wearorder-api -n 100` 看 panic 信息 |
| 502 Bad Gateway | 后端进程死了 → `systemctl status wearorder-api`；或 Nginx 配置错 → `nginx -t` |
| HTTPS 证书过期 | `sudo certbot renew --dry-run` 测续期；`sudo systemctl status certbot.timer` 看自动续期任务 |
| 调 API 超时 | 后端日志看 LLM provider 是否返回 error；后台联调测试也能看出来 |
| 限流误伤 | 调高 `RATE_LIMIT_PER_DAY` / `BURST_LIMIT_PER_MINUTE`，重启服务 |

---

## ICP 备案补做

App 上线 App Store 中国区前，必须完成：

1. **主体备案**（如果还没）— 你说有阿里的备案，主体一栏可以复用
2. **腾讯云接入备案** — 进腾讯云控制台 → 备案 → 新增接入
   - 上传材料：身份证 / 公司证件 + 域名证书 + 服务器订单
   - 审核：腾讯云初审 1-3 天 + 通信管理局 7-15 天
3. **算法备案 / 深度合成备案**（生成式 AI 服务必需）
   - 网信办 → 算法备案系统
   - 周期更长，建议早办

---

## 安全 checklist（上线前过一遍）

- [ ] SSH 密码登录已关闭
- [ ] root 用户禁止 SSH 登录（用普通用户 + sudo）
- [ ] fail2ban 启用
- [ ] ufw 开启，只放 22 / 80 / 443
- [ ] HTTPS 证书有效，自动续期工作
- [ ] admin 临时密码已改
- [ ] `wearorder.env` 文件权限 600（`sudo chmod 600 /etc/wearorder/wearorder.env`）
- [ ] SQLite 数据库定时备份
- [ ] 调用日志能看出异常请求模式
- [ ] LLM API Key 不直接出现在前端代码或 Git 仓库里（只在服务器后台填）
