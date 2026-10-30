# Lynse 个人助手化重构日志（2026-10-03 凌晨）

无人值守执行，8 阶段全部完成，无阻塞跳阶段。

## 最终架构

```
lib/
├── main.dart              # 精简入口：Hive+sqlite → NvEasyPlugin → DeviceSession → AssistantShell
├── core/                  # 纯逻辑层（不 import UI）
│   ├── hardware/          # 硬件抽象层（Xyrix+Neview 双适配器，Phase 0 自 lib/hardware 平移）
│   ├── api/               # （预留：lynse_api 现仍在 lib/http/lynse_api.dart，迁入时改 import）
│   ├── data/              # recording_repository（recordings 表 + 目录扫描入库）
│   └── services/          # device_session / recording_library / playback_service /
│                          # task_center / assistant_service（Mock 后端可切换）
├── ui/                    # OpenMUSE 设计系统复刻：tokens / theme / components(12) / demo 页
├── features/              # shell(4tab+常驻输入条) / today / assistant(chat) /
│                          # recordings(列表+详情含播放) / device / tasks
├── router/                # 仅 assistant_router（shell/chat/recordingDetail/uiDemo）
├── http/lynse_api.dart    # 新后端契约（baseUrl 占位符 lib/config/lynse_backend.dart）
├── intl/                  # 三语翻译（保留，main 引用 Messages()）
├── plugin/                # nv_easy_plugin（已斩断 DtingStore 直连，纯 rawEvents 广播）
└── utils/                 # local_database(Hive) / local_sqldb(sqlite v3)
```

## 阶段与 commit

| Phase | 内容 | Commit |
|---|---|---|
| 0 | 解耦手术：nv_easy_plugin→DtingStore 斩断；hardware 平移 lib/core/；门面 snackbar→sessionNotice；sqlite v3 五表 | d9f516f |
| 1 | OpenMUSE 设计系统：tokens/theme/12 组件/demo 页（/uiDemo） | 44c9b6b |
| 2 | 助手外壳（4 tab+常驻输入条）+ 今日屏 + chat 骨架 | 932c035 |
| 3 | 录音库 sqlite 索引化 + PlaybackService（进度/倍速/段落高亮）+ 详情页接播放 | 7e4c575 |
| 4 | 设备屏换新设计系统（状态/录音控制/传输/快传建链/固件/文件列表/添加流程） | 017f38b |
| 5 | TaskCenter 统一状态机（下载/导入/转写/生成/固件，tasks 表流水）+ 任务屏 | 4824f7a |
| 6 | 助手 Chat 正式版：AssistantBackend 抽象 + Mock 本地真数据应答 + 工具卡 + 会话落库 | 4408b53 |
| 7 | 大删除：~300 旧文件/58k 行（旧 pages/store/service/model/http/路由/utils/widgets/packages），pubspec 40+ 依赖移除 | ac71e65 |

## 验证结果

- `flutter analyze`：0 error 0 warning（仅剩 2 条 intl 文件名历史 lint info）
- `flutter test`：45 用例全绿（Xyrix 协议层回归未受影响）
- 依赖收敛：get/dio/http/hive/sqflite/path_provider/just_audio/flutter_blue_plus/intl/connectivity_plus 等基础包

## 既定决策（已落实）

1. 无账号纯本地第一版：登录/支付/团队/积分/VIP 全删，入口直达助手外壳
2. 状态管理保留 GetX（DeviceSessionController 等 services 均为 GetX controller）
3. Chat UI 先行 + Mock 桩：`AssistantService.backend` 接口化，Lynse 后端就绪后实现 `AssistantBackend` 替换 MockAssistantBackend 即插即用
4. 设计系统复刻 OpenMUSE（MIT）：色板/圆角/字号 1:1，文案全中文

## 已知遗留 / 交给后续任务

1. ~~转写/纪要云端链路未接~~ → **已闭环（10-03 凌晨 M1）**：PRD-02 M1 已在新结构落地（编辑/轮询/重生成/缺陷修复，详见工作区 uncommitted 改动与工作汇报）
2. ~~lynse_api.dart 未迁 lib/core/api/~~ → **已迁（10-03）**：`lib/http/` 已删除，引用统一为 `package:dting/core/api/lynse_api.dart`
3. **行动项（action_items 表）已建但无 UI**：PRD-01（AI 对话+行动项）落地范围
4. **今日屏「待办」统计格仍是占位**：等 action_items 有数据源后接入
5. **真机冒烟未做**（无人值守无法做）：BLE 连接、WiFi 快传、播放器需真机验证
6. **intl 三语仅保留框架**：新 features 页面文案硬编码中文（与 PRD-02 决策一致）
7. assets/ 下旧图片/lottie/svg 大量未清（不影响编译，后续瘦身）

## 给 08:00 M1 任务的提醒

- 详情页在 `lib/features/recordings/recording_detail_page.dart`（播放条+三 tab）
- 轮询状态机优先并入 `core/services/task_center.dart`（TaskType.transcribe/summarize + submit/advance 已预留）
- 设计系统用 `lib/ui/components.dart` + `lib/ui/tokens.dart`（不要用已删除的 context.lynse/LynseCard）
- 草稿 KV 用 Hive basicBox（lib/utils/local_database.dart）
