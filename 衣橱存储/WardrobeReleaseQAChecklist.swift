import Foundation

enum WardrobeReleaseQAFlow: String, CaseIterable, Identifiable {
    case firstLaunch
    case emptyWardrobe
    case weatherForecast
    case addClothing
    case createOOTD
    case createPlanReminder
    case backupRestore
    case privacySupport

    var id: String { rawValue }

    var order: Int {
        switch self {
        case .firstLaunch: 1
        case .emptyWardrobe: 2
        case .weatherForecast: 3
        case .addClothing: 4
        case .createOOTD: 5
        case .createPlanReminder: 6
        case .backupRestore: 7
        case .privacySupport: 8
        }
    }

    var title: String {
        switch self {
        case .firstLaunch:
            "首次启动"
        case .emptyWardrobe:
            "空衣橱引导"
        case .weatherForecast:
            "天气预报"
        case .addClothing:
            "添加与编辑衣物"
        case .createOOTD:
            "创建 OOTD"
        case .createPlanReminder:
            "创建计划与提醒"
        case .backupRestore:
            "备份恢复"
        case .privacySupport:
            "隐私与支持"
        }
    }

    var entryPoint: String {
        switch self {
        case .firstLaunch:
            "首次安装后打开 App"
        case .emptyWardrobe:
            "首页、衣橱、OOTD 和计划页"
        case .weatherForecast:
            "首页天气卡片和推荐入口"
        case .addClothing:
            "首页快捷操作或衣橱页加号"
        case .createOOTD:
            "首页快捷操作、OOTD 页或推荐结果"
        case .createPlanReminder:
            "首页快捷操作、计划页或 OOTD 详情"
        case .backupRestore:
            "首页数据安全或设置页"
        case .privacySupport:
            "设置页隐私与支持"
        }
    }

    var requiresPhysicalDevice: Bool {
        switch self {
        case .weatherForecast, .addClothing, .createPlanReminder, .backupRestore:
            true
        case .firstLaunch, .emptyWardrobe, .createOOTD, .privacySupport:
            false
        }
    }

    var isReleaseBlocking: Bool {
        true
    }

    var acceptanceCriteria: [String] {
        switch self {
        case .firstLaunch:
            [
                "新安装后不会自动写入演示衣物、OOTD 或计划。",
                "首次引导只在空衣橱且未完成引导时出现。",
                AppReleaseInfo.allowsSampleDataEntry ? "用户可以选择添加第一件衣物、载入示例或稍后再说。" : "正式版本只展示添加第一件衣物或稍后再说，不露出演示数据入口。"
            ]
        case .emptyWardrobe:
            [
                "首页解释 3 步闭环，不出现不可操作入口。",
                "衣橱、OOTD 和计划页都有明确空状态和下一步按钮。",
                "缺少上装或下装时，推荐、OOTD 和计划入口会给出具体原因。"
            ]
        case .weatherForecast:
            [
                "首次进入首页不会展示手动天气或手动温度控件。",
                "授权定位后能读取天气预报，并把今日天气和温度带入推荐。",
                "定位拒绝时可以选择城市天气；定位关闭或网络不可用时有明确反馈，不伪装成真实天气。"
            ]
        case .addClothing:
            [
                "相册和相机权限文案与实际用途一致。",
                "保存前会压缩图片，并保留名称、分类、品牌、尺码和购买信息。",
                "编辑、详情、导出和删除影响提示都能正常工作。"
            ]
        case .createOOTD:
            [
                "有上装和下装或裙装后可以保存 OOTD。",
                "设置今日搭配后首页能读取同一套 OOTD。",
                "包袋和配饰同时存在时，详情页会分别展示。"
            ]
        case .createPlanReminder:
            [
                "计划必须绑定已保存 OOTD 或给出阻塞说明。",
                "未来提醒会创建本地通知，过期或缺失提醒时间会自动关闭开关。",
                "权限拒绝和调度失败会显示用户可理解的反馈。"
            ]
        case .backupRestore:
            [
                "有数据时可以导出 JSON 备份，没有数据时导出入口禁用。",
                "恢复备份会合并衣物、OOTD 和计划，不重复污染数据。",
                "恢复后会重新同步可用的计划提醒，并反馈同步数量。"
            ]
        case .privacySupport:
            [
                "设置页展示本地优先、不追踪、不上传衣橱数据。",
                "隐私政策 URL、支持 URL 和支持邮箱填入真实值后可打开。",
                "App Store 元数据、隐私标签和 App 内说明保持一致。"
            ]
        }
    }
}

enum WardrobeReleaseQAChecklist {
    static let expectedFlowCount = 8

    static var orderedFlows: [WardrobeReleaseQAFlow] {
        WardrobeReleaseQAFlow.allCases.sorted { $0.order < $1.order }
    }

    static var physicalDeviceFlows: [WardrobeReleaseQAFlow] {
        orderedFlows.filter(\.requiresPhysicalDevice)
    }

    static var releaseBlockingFlows: [WardrobeReleaseQAFlow] {
        orderedFlows.filter(\.isReleaseBlocking)
    }

    static let requiredPreflightCommands = [
        "xcodebuild test",
        "./scripts/run_local_smoke_test.sh",
        "./scripts/audit_app_store_readiness.sh --strict"
    ]
}
