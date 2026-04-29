# 衣序 / WearOrder

衣序是一款面向 iPhone 的数字衣橱与 OOTD 计划应用。它帮助用户记录衣物、整理分类、保存穿搭、安排未来计划，并结合天气信息辅助日常搭配决策。

## 语言

- [中文](#中文)
- [English](#english)
- [日本語](#日本語)

---

## 中文

### 项目简介

衣序把日常衣物整理成可搜索、可筛选、可搭配的数字衣橱。用户可以通过拍照或相册导入衣物，保存 OOTD，并把已保存的 OOTD 安排到未来日期中。

### 核心功能

- 数字衣橱：添加、编辑、筛选、排序和删除衣物。
- 批量导入：从相册批量导入衣物照片，并生成缩略图。
- 图片优化：压缩原图、生成缩略图，并提供白底图处理入口。
- 分类整理：支持上装、下装、裙装、外套、鞋履、包、配饰等多类目。
- OOTD：创建、保存和查看每日穿搭。
- 未来计划：把 OOTD 绑定到指定日期，并支持本地提醒。
- 天气辅助：使用 WeatherKit 获取天气，用于搭配参考。
- iCloud 同步：通过 CloudKit 私有数据库同步用户数据。
- Apple ID 登录：使用 Sign in with Apple 作为账号入口。
- 备份恢复：支持本地 JSON 备份导出与恢复。

### 技术栈

- SwiftUI
- SwiftData
- CloudKit
- WeatherKit
- Sign in with Apple
- PhotosUI
- Vision / Core Image
- UserNotifications
- XCTest

### 开发环境

- Xcode 16 或更新版本
- iOS 17.0+
- Apple Developer Program 账号
- 已开启的 App Capabilities：
  - iCloud / CloudKit
  - WeatherKit
  - Sign in with Apple
  - Local Notifications

### 本地运行

```bash
open 衣橱存储.xcodeproj
```

在 Xcode 中选择 `衣橱存储` scheme，然后选择模拟器或真机运行。

### 本地检查

```bash
plutil -lint 衣橱存储/Info.plist 衣橱存储/PrivacyInfo.xcprivacy 衣橱存储/衣橱存储.entitlements
git diff --check
bash scripts/audit_app_store_readiness.sh --strict
```

### 构建

```bash
xcodebuild build \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

### 测试

```bash
xcodebuild test \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

### 当前状态

项目处于 TestFlight 内测准备阶段。AI 搭配能力目前仍是后续规划，不应作为正式生产功能对用户承诺。

---

## English

### Overview

WearOrder is an iPhone app for building a digital wardrobe, saving OOTD looks, and planning outfits for future dates. It helps users import clothing photos, organize wardrobe items, create outfits, and use weather information as styling context.

### Core Features

- Digital wardrobe: add, edit, filter, sort, and delete wardrobe items.
- Batch import: import multiple clothing photos from the photo library.
- Image optimization: compress original photos, generate thumbnails, and prepare white-background processing flows.
- Category organization: tops, bottoms, dresses, outerwear, shoes, bags, accessories, and more.
- OOTD: create, save, and review outfits.
- Future planning: assign saved OOTD looks to calendar dates with local reminders.
- Weather-aware context: uses WeatherKit for weather-based styling input.
- iCloud sync: syncs user data through a private CloudKit database.
- Sign in with Apple: provides the account entry point.
- Local backup: exports and restores wardrobe data with JSON files.

### Tech Stack

- SwiftUI
- SwiftData
- CloudKit
- WeatherKit
- Sign in with Apple
- PhotosUI
- Vision / Core Image
- UserNotifications
- XCTest

### Requirements

- Xcode 16 or newer
- iOS 17.0+
- Apple Developer Program membership
- Enabled App Capabilities:
  - iCloud / CloudKit
  - WeatherKit
  - Sign in with Apple
  - Local Notifications

### Run Locally

```bash
open 衣橱存储.xcodeproj
```

Select the `衣橱存储` scheme in Xcode, then run the app on a simulator or a physical iPhone.

### Local Checks

```bash
plutil -lint 衣橱存储/Info.plist 衣橱存储/PrivacyInfo.xcprivacy 衣橱存储/衣橱存储.entitlements
git diff --check
bash scripts/audit_app_store_readiness.sh --strict
```

### Build

```bash
xcodebuild build \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

### Test

```bash
xcodebuild test \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

### Current Status

The project is in TestFlight preparation. AI styling features are planned for a later stage and should not be presented as production-ready functionality yet.

---

## 日本語

### 概要

WearOrder は、iPhone 向けのデジタルクローゼットと OOTD 計画アプリです。衣類写真の取り込み、カテゴリ整理、コーディネート保存、将来の日付への予定登録、天気情報を参考にしたスタイリングをサポートします。

### 主な機能

- デジタルクローゼット：衣類の追加、編集、絞り込み、並び替え、削除。
- 一括インポート：写真ライブラリから複数の衣類写真を取り込み。
- 画像最適化：元画像の圧縮、サムネイル生成、白背景処理フロー。
- カテゴリ整理：トップス、ボトムス、ワンピース、アウター、シューズ、バッグ、アクセサリーなど。
- OOTD：日々のコーディネートを作成・保存・確認。
- 未来の予定：保存済み OOTD を日付に紐づけ、ローカル通知でリマインド。
- 天気連携：WeatherKit を利用して天気情報を取得し、コーディネートの参考にする。
- iCloud 同期：CloudKit のプライベートデータベースでユーザーデータを同期。
- Apple でサインイン：アカウント入口として Sign in with Apple を利用。
- ローカルバックアップ：JSON ファイルによるエクスポートと復元。

### 技術スタック

- SwiftUI
- SwiftData
- CloudKit
- WeatherKit
- Sign in with Apple
- PhotosUI
- Vision / Core Image
- UserNotifications
- XCTest

### 開発環境

- Xcode 16 以降
- iOS 17.0+
- Apple Developer Program メンバーシップ
- 有効化が必要な App Capabilities：
  - iCloud / CloudKit
  - WeatherKit
  - Sign in with Apple
  - Local Notifications

### ローカル実行

```bash
open 衣橱存储.xcodeproj
```

Xcode で `衣橱存储` scheme を選択し、シミュレータまたは実機で実行します。

### ローカルチェック

```bash
plutil -lint 衣橱存储/Info.plist 衣橱存储/PrivacyInfo.xcprivacy 衣橱存储/衣橱存储.entitlements
git diff --check
bash scripts/audit_app_store_readiness.sh --strict
```

### ビルド

```bash
xcodebuild build \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

### テスト

```bash
xcodebuild test \
  -project 衣橱存储.xcodeproj \
  -scheme 衣橱存储 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

### 現在の状態

このプロジェクトは TestFlight 内部テスト準備段階です。AI スタイリング機能は今後の計画であり、現時点では本番機能として扱わないでください。

---

## Repository Notes

- Keep this repository private unless all public contact information, assets, and internal notes have been reviewed.
- Do not commit certificates, API keys, private keys, passwords, personal Apple ID information, local test photos, or Xcode user state.
- Use `PROJECT_HANDOFF.md` to continue development across different Macs or Codex sessions.
