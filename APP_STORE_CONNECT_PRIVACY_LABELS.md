# 衣序 WearOrder App Store Connect 隐私填报稿

最后更新：2026-04-24

## 当前版本建议选择

| App Store Connect 问项 | 建议填写 | 依据 |
| --- | --- | --- |
| Data Collection | Location | 天气功能会在用户授权定位后，把当前位置经纬度发送到 Open-Meteo 获取当日天气预报；用户选择城市天气时，会把城市名称发送到 Open-Meteo 查询对应预报。 |
| Tracking | No | 当前版本不接入广告 SDK，不跨 App/网站追踪用户。 |
| Data Linked to User | No | 当前版本没有账号系统，天气请求不包含姓名、邮箱、衣橱数据、照片、OOTD 或计划内容。 |
| Third-Party Advertising | No | 当前版本无广告。 |
| Developer's Advertising or Marketing | No | 当前版本无营销追踪。 |
| Analytics | No | 当前版本无远程分析 SDK。 |
| Product Personalization | No | 推荐逻辑只在本机基于天气结果、场景和本地衣橱数据运行。 |

## App Store Connect 数据类型建议

| 数据类型 | 建议填写 | 用途 |
| --- | --- | --- |
| Location / Precise Location | Collected, Not Linked to User, Not Used for Tracking | App Functionality：获取本地天气预报，用于首页展示和穿搭推荐。 |

## 设备本地数据说明

App 会在设备本地保存以下内容，用于完成核心功能，但当前版本不由开发者收集：

- 衣物名称、分类、颜色、季节、品牌、尺码、购买价格、购买日期、购买渠道、保养备注、标签、收藏状态、备注和照片。
- OOTD 搭配、今日搭配状态和搭配备注。
- 穿搭计划、提醒开关和提醒时间。
- 用户主动导出的文本报告或 JSON 备份文件。

## 权限对应

| 权限 | 用途 | 隐私备注 |
| --- | --- | --- |
| 相册 | 选择衣物照片 | 照片压缩后保存在本机 SwiftData external storage。 |
| 相机 | 拍摄衣物照片 | 照片压缩后保存在本机 SwiftData external storage。 |
| 通知 | 发送穿搭计划提醒 | 本地通知由用户创建的计划触发。 |
| 定位 / 城市名称 | 获取天气预报 | 经纬度或用户选择的城市名称用于请求 Open-Meteo 当日天气；不保存定位历史。 |

## 需要重新评估的变更

如果后续加入账号、iCloud 同步、远程 AI 识别、分析 SDK、崩溃上报、广告、推送服务器或任何后端存储，需要重新填写 App Store 隐私问卷，并同步更新：

- `PRIVACY.md`
- `docs/privacy-policy.html`
- `APP_STORE_METADATA.md`
- `衣橱存储/PrivacyInfo.xcprivacy`
