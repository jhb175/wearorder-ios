# 衣序 / WearOrder 后续开发路线图

最后更新：2026-04-30

这个文件用于在不同 Mac、不同 Codex 会话之间同步产品计划、技术接口和下一步开发顺序。不要在这里记录 Apple ID、邮箱、手机号、服务器密码、证书、API Key 或任何私人凭据。

## 当前基线

- 仓库：`https://github.com/jhb175/wearorder-ios`
- 当前阶段：TestFlight 内测准备和真实手机测试前收口。
- 数据策略：SwiftData 本地优先，CloudKit 私有数据库同步衣物元数据、OOTD 和计划。
- 图片策略：衣物原图/缩略图存 App 沙盒文件，SwiftData 存文件名和元数据；当前 CloudKit 一期不主动同步原图。
- 天气策略：WeatherKit 获取当前定位或城市兜底天气，用于首页和推荐上下文。
- 账号策略：Sign in with Apple 已接入，作为后续同步、会员和 AI 功能的账号基础。
- AI 策略：AI 入口保留规划，不作为当前生产主路径；真实 AI 功能进入 Pro/会员版后再开放。

## 1-10 功能完成度

| 编号 | 模块 | 当前目标 | 当前完成度 | 下一步 |
| --- | --- | --- | --- | --- |
| 1 | 数据安全 | 删除、恢复、CloudKit fallback 和图片文件事务安全 | 约 90% | TestFlight 真机观察 iCloud 状态和备份恢复路径 |
| 2 | 天气系统 | WeatherKit 商业化天气、城市兜底、错误分类和归因 | 约 90% | 真机验证定位、城市天气和不同网络状态 |
| 3 | 首页精简 | 首页只保留天气、今日 OOTD、近期计划和高频入口 | 约 90% | 真机检查首页首屏是否清爽，必要时继续移除低频入口 |
| 4 | 衣橱大数量优化 | 300 件单品时主页面不一次性铺满，图片解码不阻塞主流程 | 约 90% | 真机导入 50/100/300 件，检查滚动、筛选、批量选择、时间线 |
| 5 | OOTD 体验打磨 | 首页可一眼看到今日 OOTD，预设库支持分页和搜索 | 约 90% | 真机检查今日卡片图片清晰度、预设库分页、详情跳转 |
| 6 | 计划日历化 | 用日历展示未来计划，计划负责把 OOTD 放进日期 | 约 90% | 检查同日多计划、提醒失败、日期切换和计划详情 |
| 7 | 预设穿搭 | OOTD 保留为预设库，一套预设可重复安排到未来日期 | 约 96% | 真机检查一键安排日期、同日已有计划提示和计划列表展示 |
| 8 | 计划上下文 | 日常、特殊日子、旅行分别记录地点、天气城市和未来天气摘要 | 约 92% | TestFlight 真机验证未来 7-10 天天气摘要和超出预报范围提示 |
| 9 | 预设快速套用 | 从计划页直接把常用 OOTD 安排到未来日期 | 约 93% | 真机检查横向预设入口、选中日期套用和未补全预设提示 |
| 10 | 交接和测试 | 文档、备份、导出、数据修复、测试覆盖同步更新 | 约 90% | TestFlight 收集真实问题后进入 1.0.1 修复 |

## 2026-04-30 1-10 验证与开发记录

- 1-6 已在继续开发前完成本地验证：烟测、App Store readiness、generic iOS build 和 iPhone 17 Pro 模拟器测试均通过。
- 7-10 已继续推进：OOTD 预设标签、预设库标签筛选和排序、计划地点/天气城市字段、备份/导出/数据修复兼容和对应单元测试。
- 第 8 阶段继续补齐：计划详情、计划列表和一周视图会根据计划日期 + 天气城市读取 WeatherKit 未来天气摘要；列表只预取前 8 条，避免打开计划页时高频请求。
- 第 9 阶段继续补齐：从 OOTD 预设卡片或详情页可直接“安排到日期”，自动推断日常/特别日/旅行类型，同日已有计划时提示新增不覆盖；计划页新增“快速套用预设”横向入口，可按当前日历选中日期把完整 OOTD 预设安排到未来日期。
- 当前打包建议版本：`1.0.0 (15)`。下一次重新上传 TestFlight 需要继续递增 Build Number。
- 仍然建议 TestFlight 真机重点看：添加衣物卡顿、批量导入、天气权限/城市天气、未来计划天气、CloudKit 同步、OOTD 预设安排到未来日期。

## 下一阶段开发顺序

1. TestFlight 真机 QA
   - 覆盖添加衣物、批量导入、编辑、删除、OOTD、计划、提醒、天气、Apple ID 登录、CloudKit 同步。
   - 用 5 名内部测试员先跑核心路径，记录崩溃、卡顿和保存失败。

2. 性能工程二期
   - 对 50/100/300 件单品分别测试首页、衣橱、筛选、时间线、分类覆盖、OOTD 预设库。
   - 重点观察图片解码、批量导入预览、天气动画和 SwiftUI body 重算。
   - 如真机仍卡顿，优先做：批量导入预览缓存、天气动画降级、列表分页阈值和图片缓存成本调整。

3. 1.0.1 修复版
   - 只收真实测试反馈中的 P0/P1 问题。
   - 不新增大功能，避免在内测初期扩大风险面。
   - 每次修改后递增 Build Number，例如 `1.0.0 (4)`、`1.0.0 (5)`。

4. 产品精修
   - 首页继续压缩信息密度。
   - 衣橱二级页增加批量修正、批量删除和批量标签。
   - OOTD 详情增加更清晰的穿搭拼图和单品替换入口。
   - 计划页强化冲突提示：同日多排、失效提醒、未绑定 OOTD。

5. AI Pro 方案
   - 先做架构和付费边界，不直接放进免费主路径。
   - AI 功能包括：聊天搭配、局部换单品、添加单品后重新推荐、推送到未来日期、旅行/地点/心情/未来天气搭配。

## 新功能路线

### 1. OOTD 局部换单品

目标：用户看到一套 OOTD 后，可以只换上衣、下装、外套、鞋子、包或配饰。

实现方向：

- 复用现有推荐引擎和 slot 逻辑。
- 在 OOTD 详情页增加“替换单品”入口。
- 选择某个 slot 后只展示匹配该 slot 的候选单品。
- 替换后更新 OOTD 并保留原计划绑定。

### 2. 预设库增强

目标：预设不仅是已保存 OOTD 列表，而是可复用的穿搭资产。

实现方向：

- 已增加预设标签：通勤、休闲、周末、约会、正式、运动、旅行、聚会、仪式、校园。
- 已支持预设标签筛选、名称搜索、最近更新/名称/使用次数排序。
- 已支持从 OOTD 预设卡片、详情页和计划页直接安排到日期，保留原 OOTD，不覆盖同日已有计划。
- 创建计划时会搜索预设标题、备注、单品字段和预设标签。
- 下一步再做预设收藏、批量整理和更细的季节/场景组合筛选。

### 3. 衣橱批量管理

目标：300 件单品以上也能快速整理。

实现方向：

- 批量删除：已实现基础能力，继续强化影响提示。
- 批量改分类、季节、颜色、标签、收藏。
- 批量补资料：品牌、尺码、购买渠道。
- 批量白底处理：需要加入队列和进度提示，避免主线程卡顿。

### 4. 图片质量与白底图

目标：用户随手拍也能变成好看的数字衣橱图片。

实现方向：

- 保留原图压缩版、缩略图和白底处理图。
- 白底图生成入口先保持本地处理；后续 AI Pro 可做更精细抠图。
- 后台队列处理图片，处理完成后回写当前记录。
- 增加失败反馈，不静默失败。

### 5. iCloud 同步二期

目标：多设备同步更可靠。

实现方向：

- 当前同步衣物元数据、OOTD、计划。
- 后续评估是否同步缩略图，不建议直接同步原图。
- 增加同步状态提示：等待同步、已同步、冲突、失败。
- 冲突策略：优先保留最新 `updatedAt`，必要时提供手动合并入口。

### 6. AI 搭配师 Pro

目标：会员功能，提供更强的穿搭建议和计划生成。

核心能力：

- 聊天式搭配：用户描述场景、心情、地点、旅行天数。
- 结合衣橱：AI 只能从用户已有衣物中选择，避免推荐不存在的衣服。
- 结合未来天气：根据 WeatherKit 获取目标日期/城市天气。
- 局部换单品：用户说“鞋子换一双更休闲的”，只替换鞋子。
- 一键安排：满意后保存为 OOTD，或推送到未来某一天的计划。

商业边界：

- 免费版保留本地规则推荐。
- Pro 版开放 AI 聊天、旅行计划、未来多日搭配、局部换单品。
- AI 请求必须经过自有后端代理，不能把模型 API Key 放进 iOS App。

## 接口和服务规划

### Apple 能力

| 能力 | 当前状态 | 用途 | 注意事项 |
| --- | --- | --- | --- |
| Sign in with Apple | 已接入 | 账号体系、后续会员识别 | 当前不上传账号信息到自有服务器 |
| CloudKit | 已接入 | 私有 iCloud 同步 | 当前不主动同步衣物原图 |
| WeatherKit | 已接入 | 天气卡、天气推荐、未来计划天气 | 需要 Developer 后台能力和正确 provisioning profile |
| TestFlight | 已接入流程 | 内测分发 | 每次上传递增 Build Number |
| In-App Purchase | 未接入 | Pro 会员、AI 额度 | 上线 AI 前再接 |
| Push Notifications | 未接入自有 APNs | 后续远程提醒/运营通知 | 当前只有本地提醒；CloudKit 可保留 remote notification 背景能力 |

### 后端服务

当前版本不依赖自有后端。后续如果做 AI Pro，建议国内云服务器承担以下职责：

- AI API 代理：隐藏模型 API Key，做鉴权、限流、日志和成本控制。
- 会员校验：接收 App Store Server Notifications 或校验交易凭证。
- 任务队列：处理复杂 AI 图片抠图、批量分析、长任务。
- 公开网页：隐私政策、支持页面、版本公告。
- 远程推送：后期需要运营通知或跨设备提醒时再接 APNs。

建议最小后端接口：

```http
POST /v1/ai/style-chat
POST /v1/ai/generate-outfit
POST /v1/ai/replace-item
POST /v1/ai/plan-trip
POST /v1/subscription/verify
POST /v1/apple/server-notifications
GET  /health
```

接口原则：

- iOS 端只发送必要字段，不上传无关照片和私人备注。
- 服务端不长期保存用户衣橱明细，除非用户明确开启云端 AI 记忆。
- 所有请求必须带用户授权态和会员态。
- AI 日志默认脱敏，避免保存真实邮箱、Apple ID、定位原始经纬度。

### AI 请求数据结构草案

```json
{
  "user_id": "apple_sub_or_internal_user_id",
  "locale": "zh-Hans",
  "request": {
    "scene": "commute",
    "mood": "clean and professional",
    "date": "2026-05-02",
    "city": "Shanghai",
    "weather_summary": "cloudy, 22C"
  },
  "wardrobe_items": [
    {
      "id": "item_uuid",
      "name": "浅灰短袖",
      "category": "上装",
      "color": "浅灰",
      "season": "四季",
      "tags": ["休闲", "通勤"],
      "has_photo": true
    }
  ],
  "constraints": {
    "must_use_item_ids": [],
    "avoid_item_ids": [],
    "replace_slot": "shoes"
  }
}
```

返回结构草案：

```json
{
  "title": "干净通勤 OOTD",
  "reason": "小雨天气建议带外套，灰白蓝组合显得干净专业。",
  "items": {
    "top": "item_uuid",
    "bottom": "item_uuid",
    "outerwear": "item_uuid",
    "shoes": "item_uuid",
    "bag": null,
    "accessory": null
  },
  "actions": ["save_ootd", "add_to_plan", "replace_item"]
}
```

## 代码整理计划

### P1：性能和稳定性

- 继续检查删除、恢复、批量操作是否都是“保存成功后再清理文件”。
- 批量导入预览不要在 body 内同步解码图片。
- 天气动画默认降级为静态或低频动画，并遵守 Reduce Motion。
- 大列表统一分页或二级页展示，不在主页面无限铺开。

### P2：结构拆分

- 把 `ContentView` 中的设计系统拆出：
  - `AppBackground.swift`
  - `CardSurface.swift`
  - `HomeButtonStyles.swift`
  - `HomeMetrics.swift`
- 把 Mock/Preview 数据从正式模型文件中移到 `PreviewSupport`。
- 删除未引用的旧 UI 区块，避免后续误接回生产路径。

### P3：本地化

- 当前语言切换主要影响系统 Locale，完整四语文案还未完成。
- 后续用 `Localizable.xcstrings` 管理中文、英文、日文、韩文。
- 先本地化主路径：首页、衣橱、添加衣物、OOTD、计划、设置。

## 每次开发结束必须做

1. 检查：

```bash
git status -sb
git diff --check
plutil -lint 衣橱存储/Info.plist 衣橱存储/PrivacyInfo.xcprivacy 衣橱存储/衣橱存储.entitlements
bash scripts/audit_app_store_readiness.sh --strict
xcodebuild build -project 衣橱存储.xcodeproj -scheme 衣橱存储 -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

2. 需要时跑测试：

```bash
xcodebuild test -project 衣橱存储.xcodeproj -scheme 衣橱存储 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

3. 提交信息必须包含仓库地址：

```bash
git commit -m "Short change summary" -m "Repo: https://github.com/jhb175/wearorder-ios"
git push origin main
```
