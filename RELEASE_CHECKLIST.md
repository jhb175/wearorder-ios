# 衣序 WearOrder 发布检查清单

最后更新：2026-04-24

## Xcode

- Scheme：衣橱存储
- Bundle ID：com.ramsey.wearorder
- Deployment Target：iOS 17.0
- Supported Platforms：iPhoneOS / iPhoneSimulator
- Targeted Device Family：iPhone
- App Icon：Assets.xcassets/AppIcon.appiconset/AppIcon.png
- 隐私清单：衣橱存储/PrivacyInfo.xcprivacy
- 出口合规：ITSAppUsesNonExemptEncryption = NO

## TestFlight 前

- 运行 XCTest。
- 运行 scripts/run_local_smoke_test.sh。
- 运行 `./scripts/audit_app_store_readiness.sh` 查看上架资料占位项。
- 拿到真实公开链接后，运行 `./scripts/configure_release_contacts.sh` 同步写入隐私政策 URL、支持 URL 和支持邮箱。
- 真实 URL 和邮箱替换完成后，运行 `./scripts/audit_app_store_readiness.sh --strict`，必须通过。
- 用 `TESTFLIGHT_INTERNAL_QA.md` 记录本轮自动检查和真机路径结果。
- 在 Xcode 的 Signing & Capabilities 中选择真实 Apple Development Team；未选择 Team 时真机 Release 构建会失败。
- 按 `APP_STORE_QA.md` 完成 7 条上架前真实体验路径。
- 对照 `APP_STORE_CONNECT_PRIVACY_LABELS.md` 填写 App Store 隐私问卷。
- 在 `衣橱存储/AppReleaseInfo.swift` 填入隐私政策 URL、支持 URL 和支持邮箱，并在设置页确认三项都显示为可打开入口。
- 真机验证添加衣物、拍照、相册选择、编辑、删除。
- 真机验证创建 OOTD、设置今日搭配、复制搭配、加入计划。
- 真机验证通知授权、提醒创建、权限拒绝提示。
- 真机验证 WeatherKit Capability 已开启、定位授权、拒绝定位、城市天气兜底、网络不可用时的天气预报提示和“按今日预报去搭配”入口。
- 验证 JSON 备份导出、恢复、清空数据二次确认。
- 对照 `APP_STORE_SCREENSHOTS.md` 检查 5 个 App Store 预览场景。

## App Store Connect

- 填写 APP_STORE_METADATA.md 中的名称、副标题、描述和关键词。
- 部署 docs/privacy-policy.html 和 docs/support.html，并把真实 HTTPS 链接填入 App Store Connect。
- 确认 ASSET_LICENSES.md 已记录所有 App 图标、截图和宣传素材来源。
- 按 `APP_STORE_SCREENSHOTS.md` 上传至少 6.9 英寸或 6.7 英寸 iPhone 截图。
- 隐私标签按 `APP_STORE_CONNECT_PRIVACY_LABELS.md` 填写：Location / Precise Location 用于 App Functionality，不追踪，不关联用户。
- 如后续加入云同步、AI 图片识别、崩溃分析或订阅，需要重新评估隐私标签和权限文案。
