# 衣序 WearOrder App Store Connect 隐私填报稿

最后更新：2026-04-29

## 当前版本建议选择

| App Store Connect 问项 | 建议填写 | 依据 |
| --- | --- | --- |
| Data Collection | Contact Info, User ID, Location | Apple ID 登录会在本机保存用户标识，并在用户同意时保存姓名和邮箱；天气功能会在用户授权定位后，通过 Apple WeatherKit 使用当前位置经纬度获取当日天气预报；用户选择城市天气时，会使用系统地理编码将城市名称转换为坐标后查询 Apple Weather。 |
| Tracking | No | 当前版本不接入广告 SDK，不跨 App/网站追踪用户。 |
| Data Linked to User | Yes for Apple ID account fields; No for weather location | Apple ID 用户标识、姓名和邮箱用于账号状态，属于账号相关数据；天气请求不包含 Apple ID、衣橱数据、照片、OOTD 或计划内容。 |
| Third-Party Advertising | No | 当前版本无广告。 |
| Developer's Advertising or Marketing | No | 当前版本无营销追踪。 |
| Analytics | No | 当前版本无远程分析 SDK。 |
| Product Personalization | No | 推荐逻辑只在本机基于天气结果、场景和本地衣橱数据运行。 |

## App Store Connect 数据类型建议

| 数据类型 | 建议填写 | 用途 |
| --- | --- | --- |
| Contact Info / Name | Collected, Linked to User, Not Used for Tracking | App Functionality：用户同意通过 Apple ID 提供姓名时，用于本机账号展示。 |
| Contact Info / Email Address | Collected, Linked to User, Not Used for Tracking | App Functionality：用户同意通过 Apple ID 提供邮箱时，用于本机账号展示和后续会员识别。 |
| Identifiers / User ID | Collected, Linked to User, Not Used for Tracking | App Functionality：保存 Apple 返回的稳定用户标识，用于本机账号状态和后续会员识别。 |
| Location / Precise Location | Collected, Not Linked to User, Not Used for Tracking | App Functionality：获取本地天气预报，用于首页展示和穿搭推荐。 |

## 设备本地数据说明

App 会在设备本地保存以下内容，用于完成核心功能。开启 iCloud 的设备会通过 Apple CloudKit 将衣物元数据、OOTD 和计划同步到用户自己的 iCloud 私有数据库；开发者不会通过自有服务器读取这些内容：

- Apple ID 登录返回的用户标识，以及用户同意提供的姓名和邮箱地址，保存在本机 Keychain。
- 衣物名称、分类、颜色、季节、品牌、尺码、购买价格、购买日期、购买渠道、保养备注、标签、收藏状态、备注和照片。
- OOTD 搭配、今日搭配状态和搭配备注。
- 穿搭计划、提醒开关和提醒时间。
- 用户主动导出的文本报告或 JSON 备份文件。

当前 CloudKit 一期不主动同步衣物原图，图片仍保存在本机 App 沙盒和用户主动导出的备份中。

## 权限对应

| 权限 | 用途 | 隐私备注 |
| --- | --- | --- |
| Apple ID 登录 | 账号状态、后续会员和 AI 功能识别 | 保存 Apple 返回的用户标识，以及用户同意提供的姓名和邮箱地址；当前版本不上传到开发者自有服务器。 |
| 相册 | 选择衣物照片 | 照片压缩后保存在本机 App 沙盒，当前 CloudKit 一期不主动同步原图。 |
| 相机 | 拍摄衣物照片 | 照片压缩后保存在本机 App 沙盒，当前 CloudKit 一期不主动同步原图。 |
| 通知 | 发送穿搭计划提醒 | 本地通知由用户创建的计划触发。 |
| 定位 / 城市名称 | 获取天气预报 | 经纬度用于请求 Apple WeatherKit 当日天气；用户选择的城市名称会用于系统地理编码并在本机保存，不保存定位历史。 |
| iCloud | 跨设备同步衣橱 | 通过 Apple CloudKit 同步衣物元数据、OOTD 和计划到用户私有 iCloud 数据库，不进入开发者自有服务器。 |

## 需要重新评估的变更

如果后续加入远程 AI 识别、分析 SDK、崩溃上报、广告、推送服务器或任何开发者自有后端存储，需要重新填写 App Store 隐私问卷，并同步更新：

- `PRIVACY.md`
- `docs/privacy-policy.html`
- `APP_STORE_METADATA.md`
- `衣橱存储/PrivacyInfo.xcprivacy`
