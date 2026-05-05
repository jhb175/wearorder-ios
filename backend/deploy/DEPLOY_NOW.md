# 一键 Docker 部署 — 你只需要跑 4 行命令

适用：腾讯云 Debian 12，IP 直连内测，没域名 / 没备案。

> **前提**：你已经按之前的指南改好 root 密码 + 配好 SSH key（强烈推荐）。如果还没做，至少把 root 密码改了再开始。

---

## 在你 Mac 上 SSH 进服务器

```bash
ssh root@43.142.4.108
```

---

## 在服务器上跑这 4 行

```bash
# 1. 装 git（Debian 12 默认有，没装的话才需要这行）
apt update && apt install -y git curl

# 2. 拉代码
mkdir -p /srv && cd /srv
git clone https://github.com/jhb175/wearorder-ios.git wearorder
cd wearorder/backend

# 3. 一键部署（会装 Docker、配防火墙、生成 secret、build + run、healthcheck）
sudo bash deploy/docker-install.sh

# 4. 完成后看输出。最后会打印：
#    - admin 登录 URL
#    - admin 临时密码（系统随机生成，只在你服务器日志里）
```

整个过程 3-5 分钟，主要时间在 `docker build`。

---

## 输出长什么样

成功的话最后会看到类似这个：

```
=========================================================
  wearorder-api is running.
=========================================================

  Admin login URL:  http://43.142.4.108/admin/login
  Public health:    http://43.142.4.108/healthz

  Admin bootstrap password (look for the box below):

    ==============================================================
      Admin bootstrap password (CHANGE IT AFTER FIRST LOGIN):
        user: admin
        pass: 8a3f2c7d
    ==============================================================

  Save the password above into your password manager,
  then login and change it via Admin → Home → 修改密码.
```

那个 `8a3f2c7d` 就是你的临时密码。**用密码管理器存下来，不要发回对话**。

---

## 登录 + 改密码

1. 浏览器打开 `http://43.142.4.108/admin/login`
2. 用户名 `admin`，密码 `8a3f2c7d`（用日志里实际打印的那个）
3. 进总览页 → "修改密码" → 设置一个**新的强密码**（不要复用 `f15015699065` 系列）
4. 进 "AI 服务商" → 添加你的中转 API
   - 名称：随便（例：`MyProxy-DeepSeek`）
   - base_url：你的中转地址（例：`https://api.example.com/v1`）
   - API Key：你的 key
   - model：`deepseek-chat` / `gpt-4o-mini` / 等
   - priority：`100`
   - 启用：✓
5. 进 "联调测试" → 选刚加的 provider → 点"发送"
   - 如果看到 LLM 返回的回复 → 后端通了
   - 如果看到错误 → 把错误贴给我

---

## 然后告诉我两件事

1. **服务器健康检查通过了吗**？（最后那个 `wearorder-api is running` 的横幅出来了吗）
2. **后台联调测试成功了吗**？（你加 provider 之后那个测试页面）

我根据情况帮你处理：
- 如果有错 → 看日志一起 debug
- 如果都 OK → 帮你把 iOS App 的 Info.plist ATS 例外加上，TestFlight 真机就能用

---

## 出问题了怎么办

把这条命令的输出贴给我，我看着办：

```bash
docker compose logs --tail=100 wearorder-api
docker compose ps
curl -i http://127.0.0.1/healthz
```

---

## 想清理重来

```bash
cd /srv/wearorder/backend
docker compose down -v   # 删容器 + 删数据卷
rm -f .env
sudo bash deploy/docker-install.sh   # 重新跑
```
