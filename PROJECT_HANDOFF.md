# 衣序 / WearOrder 项目交接文档

最后更新：2026-04-29

这个文件用于在不同 Mac、不同 Codex 会话之间继续开发。它只记录项目状态和工程决策，不记录私人邮箱、Apple ID、证书、密码或聊天原文。

## 如何在另一台 Mac 继续

1. 先同步代码：

```bash
git pull
```

2. 打开项目：

```bash
open 衣橱存储.xcodeproj
```

3. 在 Xcode 检查：

- `Signing & Capabilities` 里的 Team 是否选择付费开发者团队。
- iCloud / CloudKit、WeatherKit、Sign in with Apple 是否仍开启。
- 上传 TestFlight 前递增 Build Number，例如 `1.0.0 (4)`。

4. 新 Codex 会话可以直接说：

> 读取 `PROJECT_HANDOFF.md`、`RELEASE_CHECKLIST.md` 和当前 `git status`，继续开发衣序。

## 当前产品状态

- 产品定位：数字衣橱、OOTD 保存、未来计划、天气辅助搭配。
- 当前阶段：已进入 TestFlight 内测准备和外部测试审核流程。
- 数据层：SwiftData 本地存储，CloudKit 私有数据库同步已接入。
- 天气层：WeatherKit 已接入，依赖 Apple Developer 后台开启能力和正确 provisioning profile。
- 账号层：Sign in with Apple 已接入，主要用于后续账号体系和同步体验。
- 图片层：已从直接落库原图升级为本地图片文件存储、缩略图、压缩处理和白底图入口。
- 备份层：支持本地 JSON 导出/恢复，恢复流程需要继续保持事务安全。

## 最近完成的关键修复

- 删除单件衣物、批量删除、清空本地数据：改为先保存 SwiftData 删除事务，成功后再删除图片文件。
- 备份恢复：更新已有衣物时不再提前删除旧图片，保存成功后再清理旧文件。
- `Info.plist` 保留 `remote-notification` 后台模式，因为 CloudKit 同步需要该后台能力；这不是自定义 APNs 推送实现。
- Apple ID 登录、CloudKit、WeatherKit、Privacy Manifest 和 TestFlight 资料已按当前测试版方向整理。

## 本地验证命令

常规检查：

```bash
plutil -lint 衣橱存储/Info.plist 衣橱存储/PrivacyInfo.xcprivacy 衣橱存储/衣橱存储.entitlements
git diff --check
bash scripts/audit_app_store_readiness.sh --strict
```

构建：

```bash
xcodebuild build \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

测试：

```bash
xcodebuild test \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

注意：`CODE_SIGNING_ALLOWED=NO` 只能验证代码构建和测试，不验证真实签名、WeatherKit entitlement 或 TestFlight provisioning。

## TestFlight 注意事项

- 内部测试员必须先在 App Store Connect 的“用户和访问”里成为团队成员。
- 普通朋友测试建议走外部测试组；外部测试需要 Beta App Review。
- 外部测试审核通过后，测试员通过 TestFlight 邀请安装。
- 每次重新上传都要增加 Build Number；Marketing Version 可以先保持 `1.0.0`。

## 下一步优先级

1. 真机完整测试：添加衣物、批量导入、编辑、删除、OOTD、计划、提醒、天气、Apple ID 登录、CloudKit 同步。
2. 用 50 / 100 / 300 件衣物数据做性能测试，重点看衣橱列表、筛选、时间线、分类覆盖和图片解码。
3. 首页继续精简：只保留天气、今日 OOTD、近期计划和必要入口；低频管理工具放到设置页。
4. OOTD 和计划继续打磨：保留 OOTD 概念，计划负责把 OOTD 放进日期；预设穿搭可作为后续二级能力。
5. AI 功能暂不进生产主路径，先保留规划或 feature flag，避免用户点到不可用页面。
6. TestFlight 收集反馈后，再决定是否进入 1.0.1 修复版。

## 不要提交的内容

- Apple ID、邮箱、手机号、真实姓名、证书私钥、API Key、服务器密码。
- `~/.codex`、Xcode DerivedData、临时截图、微信缓存图片。
- 未授权第三方素材、带水印素材、测试用商品图。
- 本地设备专属配置，例如 `.xcuserdata`。

## Git 工作流

每次换电脑前：

```bash
git status
git add .
git commit -m "Update WearOrder app"
git push
```

另一台电脑开始前：

```bash
git pull
git status
```

如果 `git status` 显示冲突或大量未知文件，先停下来整理，不要直接覆盖。
