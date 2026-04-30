# 衣序 / WearOrder 项目交接文档

最后更新：2026-04-30

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
- 上传 TestFlight 前递增 Build Number。当前准备版本是 `1.0.0 (12)`，下一次重新上传建议递增到 `(13)`。

4. 新 Codex 会话可以直接说：

> 读取 `PROJECT_HANDOFF.md`、`DEVELOPMENT_ROADMAP.md`、`RELEASE_CHECKLIST.md` 和当前 `git status`，继续开发衣序。

## 当前产品状态

- 产品定位：数字衣橱、OOTD 保存、未来计划、天气辅助搭配。
- 当前阶段：已进入 TestFlight 内测准备和外部测试审核流程。
- 数据层：SwiftData 本地存储，CloudKit 私有数据库同步已接入。
- 天气层：WeatherKit 已接入，依赖 Apple Developer 后台开启能力和正确 provisioning profile。
- 账号层：Sign in with Apple 已接入，主要用于后续账号体系和同步体验。
- 图片层：已从直接落库原图升级为本地图片文件存储、缩略图、压缩处理和白底图入口。
- 备份层：支持本地 JSON 导出/恢复，恢复流程需要继续保持事务安全。
- 后续开发计划、新功能和接口草案记录在 `DEVELOPMENT_ROADMAP.md`。

## 最近完成的关键修复

- WeatherKit 真机/TestFlight 准备：Xcode Capability 已包含 WeatherKit，代码通过 `WeatherService.shared.weather(for:)` 获取天气，不再使用第三方免费天气端点。Apple Developer 后台需要在 App ID 的 `App Services` 和 `Capabilities` 两处都启用 WeatherKit，保存后重新 Archive，新 TestFlight 包才会带上最新 profile。
- 全球城市天气：城市天气不再默认填上海；支持常见全球城市内置兜底，并对未知城市走系统地理编码。英文重名城市如 `Paris Texas`、`London Ontario` 不会被错误匹配到法国巴黎或英国伦敦。
- 天气错误分类：WeatherKit 和城市地理编码的网络失败会归类为“网络不可用”；WeatherKit entitlement / provisioning 问题会提示需要在 App ID 的 App Services、App Capabilities 和 Xcode Capability 中启用。
- 删除单件衣物、批量删除、清空本地数据：改为先保存 SwiftData 删除事务，成功后再删除图片文件。
- 备份恢复：更新已有衣物时不再提前删除旧图片，保存成功后再清理旧文件。
- `Info.plist` 保留 `remote-notification` 后台模式，因为 CloudKit 同步需要该后台能力；这不是自定义 APNs 推送实现。
- Apple ID 登录、CloudKit、WeatherKit、Privacy Manifest 和 TestFlight 资料已按当前测试版方向整理。
- 首页已精简到天气、今日 OOTD、近期计划等高频入口；数据备份/报告等低频工具迁到设置和二级页。
- 衣橱大数量场景已做首页预览 + 二级页分页：全部单品、入库时间线、分类覆盖都避免在主页面一次性铺满。
- OOTD/计划/预设链路已打通：OOTD 保留为预设库，计划负责把预设安排到日期，创建计划时支持搜索和分页选择预设。
- 1-6 阶段功能已在继续 7-10 前验证通过：本地烟测、App Store readiness、generic iOS build 和 iPhone 17 Pro 模拟器测试均通过。
- 7-10 阶段已补齐到可测状态：OOTD 预设标签、预设库标签筛选/排序、计划地点和天气城市上下文、备份/导出/修复兼容。

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
- 当前工程 Build Number 是 `12`；如果 App Store Connect 已经有 `(12)`，下一包改为 `13`。
- WeatherKit 后台开通后，必须重新 Archive 并安装新的 TestFlight build；旧包不会自动获得新的 entitlement。
- 如果天气仍失败，先区分提示：`网络不可用` 通常是设备网络/地理编码网络问题；`Apple Weather 暂时拒绝了天气请求` 通常是 App ID 的 App Services / App Capabilities、Xcode Capability 或 provisioning profile 没刷新，或安装的仍是旧 TestFlight 包。

## 2026-04-30 1-10 阶段记录

- 当前代码已把 1-6 作为验证基线，再继续实现 7-10。
- 7：OOTD 预设库增加标签字段，创建/编辑 OOTD 时可选择通勤、休闲、周末、约会、正式、运动、旅行、聚会、仪式、校园，也支持自定义标签。
- 7：OOTD 页支持按标签筛选，并支持最近更新、名称、使用次数排序；创建计划时的预设搜索会覆盖预设标签。
- 8：计划新增 `locationName` 和 `weatherCityName`，日常、特殊日子、旅行会展示不同字段文案，为后续 MapKit 地点选择和未来天气做准备。
- 9：导出报告、备份恢复和数据修复已兼容预设标签、地点、天气城市字段，后续 AI Pro 可以读取这些上下文生成未来 OOTD。
- 10：新增/更新单元测试覆盖预设标签标准化，以及备份恢复中的预设标签、地点和天气城市。
- 当前准备上传测试的建议版本：`1.0.0 (12)`。若继续修改后再打包，请递增 Build Number。

## 2026-04-29 天气与测试记录

- 最近天气相关提交：
  - `7e23360 Improve global weather city resolution`
  - `5638dd0 Fix city weather network error classification`
- 已跑验证：
  - `xcodebuild test -project 衣橱存储.xcodeproj -scheme 衣橱存储 -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  - `xcodebuild test -project 衣橱存储.xcodeproj -scheme 衣橱存储 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:衣橱存储Tests/WeatherForecastServiceTests`
  - `bash scripts/run_local_smoke_test.sh`
  - `bash scripts/audit_app_store_readiness.sh --strict`
  - `git diff --check`
- 下一台 Mac 接手后，先确认 `Signing & Capabilities` 中 `Sign in with Apple`、`iCloud / CloudKit`、`WeatherKit` 仍在，并确认 Team 是付费开发者团队。
- TestFlight 真机天气必测：
  - 授权定位后首页应显示 Apple Weather 真实天气。
  - 拒绝定位后选择 `Tokyo`、`New York`、`London`、`Paris`、`Seoul` 等城市应能获取天气。
  - 输入重名城市如 `Paris, Texas, United States` 应通过系统地理编码解析，不应被内置巴黎兜底抢走。
  - 断网时应提示网络不可用，不应提示城市不存在。

## 2026-04-29 换机打包记录

- 这一节是历史记录；当前最新建议版本以 `2026-04-30 1-10 阶段记录` 为准。
- 当时准备给 TestFlight 继续测试的版本是 `1.0.0 (8)`。
- 最新提交：
  - `f8238ee Bump build number to 5`
  - `03ad549 Document TestFlight weather handoff`
  - `5638dd0 Fix city weather network error classification`
  - `7e23360 Improve global weather city resolution`
- 已确认 Xcode build settings：
  - `MARKETING_VERSION = 1.0.0`
  - `CURRENT_PROJECT_VERSION = 8`
  - `CODE_SIGN_STYLE = Automatic`
  - 不要在 Build Settings 里手动固定 `CODE_SIGN_IDENTITY = Apple Distribution`；否则 Xcode 自动签名会和手动分发签名冲突。
- 当前仓库已推送到 GitHub：`https://github.com/jhb175/wearorder-ios`
- 新 Mac 接手步骤：

```bash
git clone https://github.com/jhb175/wearorder-ios.git
cd wearorder-ios
git status
```

- 如果新 Mac 已经 clone 过：

```bash
cd wearorder-ios
git pull
git status
```

- 打包前在 Xcode 确认：
  - Team 选择付费 Apple Developer Program 团队。
  - Bundle Identifier 是 `com.ramsey.wearorder`。
  - Signing & Capabilities 中有 `Sign in with Apple`、`WeatherKit`。
  - Archive 前构建号必须大于 App Store Connect 已上传 build；当前最新建议版本见本文上方记录。
- WeatherKit 第 6 版失败后的处理：App ID 后台已经开启 WeatherKit，归档包也包含 `com.apple.developer.weatherkit`。第 7 版保留自动签名，避免 `Automatically manage signing` 和手动 `Apple Distribution` 冲突；重新 Archive 时让 Xcode 生成/选择包含 WeatherKit 的 provisioning profile。
- 2026-04-29 21:02 已验证 Release generic iOS build 成功，构建日志里包含 `com.apple.developer.weatherkit = 1`。如果 Xcode 仍报签名问题，先 Clean Build Folder，再重新 Archive。
- 第 8 版修正 WeatherKit 错误分类：明确识别 `WeatherError.permissionDenied`，避免把所有天气权限拒绝误报成“尚未配置完成”。
- 如果 WeatherKit 真机仍提示不可用，先确认安装的是 `1.0.0 (8)` 或更新版本，并在 Organizer 上传后重新安装 TestFlight 包；旧 TestFlight 包不会自动获得新签名能力。

## 2026-04-30 天气商业化审查记录

- 天气服务选择：继续使用 Apple WeatherKit，适合正式商业化版本；代码和发布文档不再引用 Open-Meteo 免费非商业端点。
- App 内归因：首页天气卡和天气详情页保留 Apple Weather attribution 入口。
- 全球城市：城市天气走内置常用城市兜底 + 系统地理编码 + WeatherKit，不是上海专用。
- 当前修复：
  - 首页启动会尊重用户保存的天气来源：如果用户上次选择城市天气，下次启动会继续用该城市拉取真实预报。
  - WeatherKit 错误分类收窄：普通网络错误不再误报为 WeatherKit 配置错误。
  - App 内 WeatherKit 配置提示改为明确要求 App ID 的 `App Services` 和 `Capabilities` 双开通。
- 真机仍不可用时的优先排查：
  1. Developer 后台 `Certificates, Identifiers & Profiles` -> `Identifiers` -> `com.ramsey.wearorder`。
  2. `App Services` 标签页勾选 WeatherKit 并保存。
  3. `Capabilities` 标签页勾选 WeatherKit 并保存。
  4. Xcode `Signing & Capabilities` 中保留 WeatherKit。
  5. Clean Build Folder，重新 Archive，上传新的 TestFlight build，并在手机上安装该新 build。

## 下一步优先级

1. 真机完整测试：添加衣物、批量导入、编辑、删除、OOTD、计划、提醒、天气、Apple ID 登录、CloudKit 同步。
2. 用 50 / 100 / 300 件衣物数据做性能测试，重点看衣橱二级页分页、筛选、时间线、分类覆盖和图片解码。
3. TestFlight 收集反馈后进入 `1.0.1` 修复版，优先修真实手机上的卡顿、崩溃和保存失败。
4. AI 功能暂不进生产主路径，先保留规划或 feature flag，避免用户点到不可用页面。
5. 后续再做 Pro 版能力：AI 聊天搭配、局部换单品、旅行/心情/未来天气计划生成。

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
