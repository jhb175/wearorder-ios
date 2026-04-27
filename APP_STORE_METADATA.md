# 衣序 App Store 元数据草稿

最后更新：2026-04-24

## 基础信息

- 上架状态：待最终人工 QA，公开 Privacy Policy URL、Support URL 和真实支持邮箱已配置。
- App 名称：衣序
- 英文名：WearOrder
- 副标题：让每天穿搭更有序
- 类别：生活
- 年龄分级建议：4+
- 版本：1.0
- Bundle ID：com.ramsey.wearorder
- 支持设备：iPhone
- Privacy Policy URL：https://jhb175.github.io/wearorder-legal/privacy-policy.html
- Support URL：https://jhb175.github.io/wearorder-legal/support.html
- 联系邮箱：1434143178@231316546.xyz
- 隐私标签填写稿：`APP_STORE_CONNECT_PRIVACY_LABELS.md`

## 简短宣传语

把衣物、OOTD 和穿搭计划都留在本机，轻松整理每天穿什么。

## App Store 描述

衣序是一款本地优先的数字衣橱工具，英文名 WearOrder。你可以记录衣物照片、分类、季节、品牌、尺码、购买信息和风格标签，保存常用 OOTD，把搭配安排到未来日期，并用本地通知提醒自己查看当天穿搭。

核心能力：

- 记录衣物、照片、颜色、季节、品牌、尺码、价格、购买渠道、保养备注和风格标签。
- 查看衣橱报告，了解颜色、季节、品牌、尺码、购买渠道和金额统计。
- 保存 OOTD，设置今日搭配，并查看搭配缺失位置。
- 按天气、温度、场景和风格生成本地规则推荐。
- 创建穿搭计划，开启一次性本地提醒。
- 导出文本报告或 JSON 备份，并可从备份恢复。
- 查看数据健康、通知状态和隐私说明。

隐私说明：

当前版本不需要账号登录，不接入广告追踪，也不会把衣物照片、穿搭记录或计划上传到开发者服务器。照片、衣物、OOTD 和计划默认保存在设备本地。天气功能会在用户授权定位后，把当前位置经纬度发送到 Open-Meteo 获取当日预报；用户也可以选择常用城市，App 会将城市名称发送到 Open-Meteo 查询天气。天气结果用于首页展示和穿搭推荐。

## 关键词草稿

衣橱,穿搭,OOTD,搭配,衣物管理,计划提醒,本地备份,服装整理

## 权限文案

- 相册：用于选择衣物照片并保存到本地衣橱，照片只保存在本机。
- 相机：用于拍摄衣物照片并保存到本地衣橱，照片只保存在本机。
- 通知：用于发送用户创建的穿搭计划提醒。

## 审核备注

本 App 不需要登录。所有核心功能均可离线使用。推荐系统为本地规则逻辑，不调用远程 AI 服务。JSON 备份和文本报告由用户通过系统文件/分享面板自行导出。

## 上架前必须替换

- Privacy Policy URL 已预填：https://jhb175.github.io/wearorder-legal/privacy-policy.html。
- Support URL 已预填：https://jhb175.github.io/wearorder-legal/support.html。
- 联系邮箱已配置：1434143178@231316546.xyz；提交前必须确认该邮箱可长期收信。
- 同步填写 `衣橱存储/AppReleaseInfo.swift` 中的 `privacyPolicyURLString`、`supportURLString` 和 `supportEmail`，让 App 内设置页也能打开公开入口。
- 可运行 `./scripts/configure_release_contacts.sh --privacy-url <公开隐私政策 URL> --support-url <公开支持 URL> --support-email <支持邮箱>` 同步更新 App 内配置、元数据草稿和本地网页模板。
- 发布网页后运行 `./scripts/audit_app_store_readiness.sh --strict`，并用浏览器或 `curl -I -L` 确认两个公开 URL 返回 200。
