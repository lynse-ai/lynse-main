import 'package:dting/pages/device/voice_details/voicedetails_controller.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/store/dting_store.dart';
import 'package:get/get.dart';

class ConcelController extends GetxController {
  var appController = Get.find<DtingStore>();
  var detailController = Get.find<VoiceDetailsController>();
  var teamFileController = Get.find<TeamFileController>();
  var homeController = Get.find<HomeIndexController>();

  bool get isNotEmpty =>
      appController.selectFileInfo.value.transcribeTaskId != null &&
      detailController.conclData.value.conclusionText != null &&
      detailController.conclData.value.conclusionText != "";

  var defalutConcl =
      """
# 灵斯记：AI驱动的智能录音与分析系统

**灵斯记（Dting）**是一款深度融合专业硬件与AI大模型的智能录音解决方案，旨在革新声音信息的采集与利用方式。

## 🎙 产品亮点

- **高保真录音硬件支持**
  - 定制化高保真录音卡
  - 支持 **32位浮点录音**
  - 高达 **130dB 动态范围**
  - 适用于会议、访谈、课堂等全场景，清晰、真实捕捉声音

- **AI 智能文本处理能力**
  - 深度集成阿里云 **通义大模型**
  - **中英文及多方言精准转写**（准确率超98%）
  - **智能区分说话人**
  - 自动生成**结构化摘要**，提炼核心论点与行动项（支持长达2小时音频）
  - 一键输出**关键信息时间戳**
  - 自动生成**思维导图**，提升信息组织效率

- **安全与协同**
  - 所有录音及分析结果**实时同步至加密云端**
  - 支持**多端协同访问**
  - 确保数据的**安全存储与管理**

## 🚀 解决核心痛点

- 手动整理耗时
- 长音频处理效率低
- 功能单一无法满足多场景需求

## 🎯 典型应用场景

- **商务会议**：厘清责任分工
- **媒体采访**：快速提取高光片段
- **学术研究**：构建结构化知识图谱
- **法律取证**：满足合规要求

## 🌟 产品理念

> “谛听万物、明辨真知”

灵斯记持续升级“声音 → 知识”的转化能力，致力于成为用户**高效理解与利用声音信息的智能中枢**。
""".obs;
  // var loading = false.obs;
  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  void onClose() {
    print("退出concel");
    Get.delete<ConcelController>();
    super.onClose();
  }
}
