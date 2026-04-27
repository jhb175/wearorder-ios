# 衣序 WearOrder 内部 TestFlight 验证记录

最后更新：2026-04-27

## 当前结论

当前代码已经通过本机自动检查，但还没有完成真机权限与真实使用路径验证。建议先进入内部 TestFlight 或 Xcode 真机安装测试，不建议直接提交公开上架。

## 自动检查记录

| 检查项 | 状态 | 备注 |
| --- | --- | --- |
| 公开 Privacy Policy URL | 通过 | `https://jhb175.github.io/wearorder-legal/privacy-policy.html` 返回 HTTP 200。 |
| 公开 Support URL | 通过 | `https://jhb175.github.io/wearorder-legal/support.html` 返回 HTTP 200。 |
| `git diff --check` | 通过 | 未发现补丁空白错误。 |
| `./scripts/audit_app_store_readiness.sh --strict` | 通过 | 上架资料、隐私清单、公开联系方式和素材风险检查通过。 |
| `./scripts/run_local_smoke_test.sh` | 通过 | 包含 generic iOS、模拟器 build-for-testing 和 Release generic iOS 构建。 |
| `xcodebuild test` | 通过 | iPhone 17 Pro / iOS 26.4.1 模拟器测试通过。 |
| Release 模拟器构建 | 通过 | iPhone 17 Pro / iOS 26.4.1 模拟器 Release 构建通过。 |

## 真机必测路径

| 顺序 | 路径 | 状态 | 通过标准 |
| --- | --- | --- | --- |
| 1 | 首次安装启动 | 待测 | 不自动载入示例数据；空衣橱引导自然；Release 不露出演示入口。 |
| 2 | 相机拍衣物 | 待测 | 相机权限文案正确；拍摄后能压缩保存；失败有反馈。 |
| 3 | 相册导入衣物 | 待测 | 相册权限文案正确；图片可导入；分类和颜色建议不覆盖手动修改。 |
| 4 | 编辑与删除衣物 | 待测 | 编辑能保存；删除前能看到关联 OOTD 和计划影响。 |
| 5 | 天气定位 | 待测 | 授权定位后显示真实预报；天气推荐入口不绕过预报。 |
| 6 | 城市天气兜底 | 待测 | 拒绝定位后能选择城市；天气来源展示清楚。 |
| 7 | 创建并保存 OOTD | 待测 | 上装加下装或裙装可保存；包袋和配饰详情都能显示。 |
| 8 | 创建计划 | 待测 | 必须绑定 OOTD；同日计划和缺失搭配提示合理。 |
| 9 | 本地通知提醒 | 待测 | 未来提醒能触发；拒绝权限、过期时间和缺失时间都有反馈。 |
| 10 | 备份与恢复 | 待测 | JSON 可导出；恢复后衣物、OOTD、计划关系完整；提醒同步结果可见。 |
| 11 | 设置页隐私支持 | 待测 | 隐私政策、支持页面和邮件入口都能打开。 |
| 12 | 重置本地数据 | 待测 | 必须输入确认文案；重置后不残留旧计划提醒。 |

## TestFlight 上传前放行标准

- 自动检查全部通过。
- 真机必测路径 1-12 全部通过，或者记录明确的非阻塞问题。
- App Store Connect 隐私问卷按 `APP_STORE_CONNECT_PRIVACY_LABELS.md` 填写完成。
- 截图按 `APP_STORE_SCREENSHOTS.md` 重新拍摄并确认没有测试数据、私人邮箱之外的个人信息或未授权素材。
- Xcode Archive 使用真实 Apple Developer Team 签名成功。
