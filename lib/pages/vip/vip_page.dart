// import 'package:dting/model/personal_model/vip_package_model.dart';
// import 'package:dting/pages/vip/vip_controller.dart';
// import 'package:dting/utils/color_util.dart';
// import 'package:dting/widgets/app_bar.dart';
// import 'package:dting/widgets/image_network.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

// class VipPage extends GetView<VipController> {
//   const VipPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: double.infinity,
//       width: double.infinity,
//       decoration: BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage('assets/images/vip/vip-background.png'),
//           fit: BoxFit.fill,
//         ),
//       ),
//       child: SingleChildScrollView(
//         child: Column(
//           children: [
//             AppBarWidgets.getAppBar(
//               title: "Dting AI Member".tr,
//               textAlign: TextAlign.center,
//               backgroundColor: Colors.transparent,
//             ),
//             Container(
//               padding: EdgeInsets.only(left: 18.w, right: 18.w, bottom: 30.w),
//               child: Column(
//                 children: [
//                   _userbox(),
//                   SizedBox(height: 30.w),
//                   _lock(),
//                   SizedBox(height: 30.w),
//                   _title("Member Upgrade".tr),
//                   SizedBox(height: 20.w),

//                   _switch(),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _title(String title) {
//     return Container(
//       height: 36.w,
//       decoration: BoxDecoration(
//         boxShadow: [
//           BoxShadow(
//             offset: Offset(0, 0),
//             blurRadius: 30,
//             spreadRadius: 0,
//             color: ColorUtil.fromHexString("#9475FF", 0.5),
//           ),
//         ],
//       ),
//       child: Text(
//         title,
//         style: TextStyle(
//           color: ColorUtil.fromHexString("#7857ED"),
//           fontWeight: FontWeight.w600,
//           fontSize: 26.w,
//           height: 30 / 26,
//         ),
//       ),
//     );
//   }

//   Widget _switch() {
//     return Obx(
//       () => Column(
//         children: [
//           Container(
//             height: 38.w,
//             width: 144.w,
//             padding: EdgeInsets.all(2.w),
//             decoration: BoxDecoration(
//               color: ColorUtil.fromHexString("#7857ED"),
//               borderRadius: BorderRadius.circular(8.w),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 GestureDetector(
//                   onTap: () {
//                     controller.monthOrYear.value = 0;
//                   },
//                   child: Container(
//                     width: 70.w,
//                     height: 34.w,
//                     alignment: Alignment.center,

//                     decoration:
//                         controller.monthOrYear.value == 0
//                             ? BoxDecoration(
//                               color: ColorUtil.fromHexString("#FFFFFF"),
//                               borderRadius: BorderRadius.circular(6.w),
//                             )
//                             : BoxDecoration(),
//                     child: Text(
//                       "Monthly subscription".tr,
//                       style: TextStyle(
//                         color: ColorUtil.fromHexString(
//                           controller.monthOrYear.value == 0
//                               ? "#1E1E1E"
//                               : "#FFFFFF",
//                         ),
//                         fontWeight: FontWeight.w700,
//                         fontSize: 16.w,
//                         height: 19 / 16,
//                       ),
//                     ),
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     controller.monthOrYear.value = 1;
//                   },
//                   child: Container(
//                     width: 70.w,
//                     height: 34.w,
//                     alignment: Alignment.center,
//                     decoration:
//                         controller.monthOrYear.value == 1
//                             ? BoxDecoration(
//                               color: ColorUtil.fromHexString("#FFFFFF"),
//                               borderRadius: BorderRadius.circular(6.w),
//                             )
//                             : BoxDecoration(),
//                     child: Text(
//                       "Annual subscription".tr,
//                       style: TextStyle(
//                         color: ColorUtil.fromHexString(
//                           controller.monthOrYear.value == 1
//                               ? "#1E1E1E"
//                               : "#FFFFFF",
//                         ),
//                         fontWeight: FontWeight.w700,
//                         fontSize: 16.w,
//                         height: 19 / 16,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(height: 20.w),
//           IndexedStack(
//             index: controller.monthOrYear.value,
//             children: [_monthCard(), _yearCard()],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _monthCard() {
//     return Obx(
//       () => Column(
//         children: [
//           _play(
//             topTitle:
//                 "${controller.mothProPackage.value.packageType}   ${"symbol".tr}${controller.mothProPackage.value.price}/${"Month".tr}",
//             bottomTitle:
//                 "${"Daily low to:".tr}${"symbol".tr}${controller.calculateDayPrice(controller.mothProPackage.value.price)}/${"Day".tr}",
//             ontap: () {
//               controller.play(controller.mothProPackage.value);
//             },
//           ),
//           SizedBox(height: 20.w),
//           _play(
//             topTitle:
//                 "${controller.mothUnlimitedPackage.value.packageType}   ${"symbol".tr}${controller.mothUnlimitedPackage.value.price}/${"Month".tr}",
//             bottomTitle:
//                 "${"Daily low to:".tr}${"symbol".tr}${controller.calculateDayPrice(controller.mothUnlimitedPackage.value.price)}/${"Day".tr}",
//             ontap: () {
//               controller.play(controller.mothUnlimitedPackage.value);
//             },
//           ),
//           SizedBox(height: 50.w),
//           _title("Membership benefits".tr),
//           SizedBox(height: 25.w),
//           tableWIdget(
//             proTrans: controller.mothProPackage.value,
//             unlimited: controller.mothUnlimitedPackage.value,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _yearCard() {
//     return Obx(
//       () => Column(
//         children: [
//           _play(
//             topTitle:
//                 "${controller.yearProPackage.value.packageType}   ${"symbol".tr}${controller.yearProPackage.value.price}/${"Month".tr}",
//             bottomTitle:
//                 "${"Daily low to:".tr}${"symbol".tr}${controller.calculateDayPrice(controller.yearProPackage.value.price)}/${"Day".tr}",
//             ontap: () {
//               controller.play(controller.yearProPackage.value);
//             },
//           ),
//           SizedBox(height: 20.w),
//           _play(
//             topTitle:
//                 "${controller.yearUnlimitedPackage.value.packageType}   ${"symbol".tr}${controller.yearUnlimitedPackage.value.price}/${"Month".tr}",
//             bottomTitle:
//                 "${"Daily low to:".tr}${"symbol".tr}${controller.calculateDayPrice(controller.yearUnlimitedPackage.value.price)}/${"Day".tr}",
//             ontap: () {
//               controller.play(controller.yearUnlimitedPackage.value);
//             },
//           ),
//           SizedBox(height: 50.w),
//           _title("Membership benefits".tr),
//           SizedBox(height: 25.w),
//           tableWIdget(
//             proTrans: controller.yearProPackage.value,
//             unlimited: controller.yearUnlimitedPackage.value,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget tableWIdget({
//     required VIPackageModel proTrans,
//     required VIPackageModel unlimited,
//   }) {
//     return Obx(
//       () => Table(
//         border: TableBorder(
//           horizontalInside: BorderSide(
//             color: ColorUtil.fromHexString("#EAE1FF"),
//             width: 1.w,
//           ),
//         ),
//         columnWidths: {
//           0: FlexColumnWidth(1.5),
//           1: FlexColumnWidth(),
//           3: FlexColumnWidth(),
//           4: FlexColumnWidth(),
//         },
//         children: [
//           TableRow(
//             children: [
//               SizedBox(),
//               Container(
//                 padding: EdgeInsets.only(top: 12.w, bottom: 12.w),
//                 child: Text(
//                   "Free users".tr,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: ColorUtil.fromHexString("#000000"),
//                     fontWeight: FontWeight.w500,
//                     fontSize: 12.w,
//                     height: 14 / 12,
//                   ),
//                 ),
//               ),

//               Container(
//                 height: 29.w,
//                 width: 70.w,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   image: DecorationImage(
//                     image: AssetImage('assets/images/vip/pro.png'),
//                     fit: BoxFit.fitHeight,
//                   ),
//                 ),
//                 child: Text(
//                   "Pro",
//                   style: TextStyle(
//                     color: ColorUtil.fromHexString("#FFFFFF"),
//                     fontWeight: FontWeight.w600,
//                     fontSize: 12.w,
//                     height: 22 / 12,
//                   ),
//                 ),
//               ),

//               Container(
//                 height: 29.w,
//                 width: 70.w,
//                 alignment: Alignment.center,

//                 decoration: BoxDecoration(
//                   image: DecorationImage(
//                     image: AssetImage('assets/images/vip/unlimited.png'),
//                     fit: BoxFit.fitWidth,
//                   ),
//                 ),
//                 child: Text(
//                   "Unlimited",
//                   style: TextStyle(
//                     color: ColorUtil.fromHexString("#FFFFFF"),
//                     fontWeight: FontWeight.w500,
//                     fontSize: 12.w,
//                     height: 14 / 12,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           _tableRow(
//             cell1: "Daily Writing Duration".tr,
//             cell2:
//                 "${controller.transData(controller.freePackage.value.transMinute)}${"min".tr}/${"M".tr}",
//             cell3:
//                 "${controller.transData(proTrans.transMinute)}${"min".tr}/${"M".tr}",
//             cell4: "Infinite".tr,
//           ),
//           _tableRow(
//             cell1: "Visual Mind Maps".tr,
//             cell2:
//                 (proTrans.visualizationSupport == 1 ? "Support" : "Unsupport")
//                     .tr,
//             cell3:
//                 (proTrans.visualizationSupport == 1 ? "Support" : "Unsupport")
//                     .tr,
//             cell4:
//                 (unlimited.visualizationSupport == 1 ? "Support" : "Unsupport")
//                     .tr,
//           ),
//           _tableRow(
//             cell1: "Overview of Recording".tr,
//             cell2:
//                 (controller.freePackage.value.recordingConclusionSupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//             cell3:
//                 (proTrans.recordingConclusionSupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//             cell4:
//                 (unlimited.recordingConclusionSupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//           ),
//           _tableRow(
//             cell1: "Summary of Recording".tr,
//             cell2:
//                 (controller.freePackage.value.recordingSummarySupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//             cell3:
//                 (proTrans.recordingSummarySupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//             cell4:
//                 (unlimited.recordingSummarySupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//           ),
//           _tableRow(
//             cell1: "Distinguish speakers".tr,
//             cell2:
//                 (controller.freePackage.value.speakerDetectionSupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//             cell3:
//                 (proTrans.speakerDetectionSupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//             cell4:
//                 (unlimited.speakerDetectionSupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//           ),
//           _tableRow(
//             cell1: "Audio Import".tr,
//             cell2:
//                 (controller.freePackage.value.audioImportSupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//             cell3:
//                 (proTrans.audioImportSupport == 1 ? "Support" : "Unsupport").tr,
//             cell4:
//                 (unlimited.audioImportSupport == 1 ? "Support" : "Unsupport")
//                     .tr,
//           ),
//           _tableRow(
//             cell1: "${"Supporting multiple types".tr}\n${"Export format".tr}",
//             cell2:
//                 (controller.freePackage.value.multiGuideSupport == 1
//                         ? "Support"
//                         : "Unsupport")
//                     .tr,
//             cell3:
//                 (proTrans.multiGuideSupport == 1 ? "Support" : "Unsupport").tr,
//             cell4:
//                 (unlimited.multiGuideSupport == 1 ? "Support" : "Unsupport").tr,
//           ),
//           _tableRow(
//             cell1: "${"Cloud recording".tr}\n${"File storage".tr}",
//             cell2:
//                 "${controller.transByteToG(controller.freePackage.value.ossStorageQuota)}G",
//             cell3: "${controller.transByteToG(proTrans.ossStorageQuota)}G",
//             cell4: "${controller.transByteToG(unlimited.ossStorageQuota)}G",
//           ),
//         ],
//       ),
//     );
//   }

//   TableRow _tableRow({
//     String cell1 = "",
//     String cell2 = "",
//     String cell3 = "",
//     String cell4 = "",
//   }) {
//     return TableRow(
//       children: [
//         cell(cell1, alignment: Alignment.centerLeft),
//         cell(cell2),
//         cell(cell3),
//         cell(cell4),
//       ],
//     );
//   }

//   TableCell cell(
//     String cell, {
//     AlignmentGeometry alignment = Alignment.center,
//   }) {
//     return TableCell(
//       child: Container(
//         height: 58.w,
//         alignment: alignment,
//         child: Text(
//           cell,
//           style: TextStyle(
//             color: ColorUtil.fromHexString("#000000"),
//             fontWeight: FontWeight.w500,
//             fontSize: 12.w,
//             height: 14 / 12,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _play({
//     String topTitle = "",
//     String bottomTitle = "",
//     required Callback ontap,
//   }) {
//     return Stack(
//       alignment: Alignment.centerRight,
//       children: [
//         Container(
//           width: Get.width,
//           alignment: Alignment.centerLeft,
//           child: Stack(
//             fit: StackFit.loose,
//             clipBehavior: Clip.none,
//             children: [
//               Container(
//                 alignment: Alignment.centerLeft,
//                 width: 303.w,
//                 height: 88.w,
//                 padding: EdgeInsets.only(left: 20.w),
//                 decoration: BoxDecoration(
//                   color: ColorUtil.fromHexString("#F0F0F0", 0.3),
//                   borderRadius: BorderRadius.circular(20.w),
//                   border: Border(
//                     top: BorderSide(
//                       color: ColorUtil.fromHexString("#FFFFFF", 0.5),
//                       width: 1.w,
//                     ),
//                     bottom: BorderSide(
//                       color: ColorUtil.fromHexString("#FFFFFF", 0.5),
//                       width: 1.w,
//                     ),
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       offset: Offset(-2, 4),
//                       blurRadius: 10,
//                       spreadRadius: 0,
//                       color: ColorUtil.fromHexString("#919191", 0.05),
//                     ),
//                     BoxShadow(
//                       offset: Offset(-7, 17),
//                       blurRadius: 18,
//                       spreadRadius: 0,
//                       color: ColorUtil.fromHexString("#919191", 0.04),
//                     ),
//                     BoxShadow(
//                       offset: Offset(-27, 66),
//                       blurRadius: 29,
//                       spreadRadius: 0,
//                       color: ColorUtil.fromHexString("#919191", 0.01),
//                     ),
//                     BoxShadow(
//                       offset: Offset(-15, 37),
//                       blurRadius: 24,
//                       spreadRadius: 0,
//                       color: ColorUtil.fromHexString("#919191", 0.03),
//                     ),
//                     BoxShadow(
//                       offset: Offset(0, 4),
//                       blurRadius: 4,
//                       spreadRadius: 0,
//                       color: ColorUtil.fromHexString("#FFFFFF", 0.25),
//                     ),
//                     BoxShadow(
//                       offset: Offset(0, -5),
//                       blurRadius: 4,
//                       spreadRadius: 0,
//                       color: ColorUtil.fromHexString("#FFFFFF", 0.25),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           topTitle,
//                           style: TextStyle(
//                             color: ColorUtil.fromHexString("#161616"),
//                             fontWeight: FontWeight.w500,
//                             fontSize: 18.w,
//                             height: 22 / 18,
//                           ),
//                         ),
//                         SizedBox(height: 12.w),
//                         Text(
//                           bottomTitle,
//                           style: TextStyle(
//                             color: ColorUtil.fromHexString("#1E1E1E"),
//                             fontWeight: FontWeight.w500,
//                             fontSize: 14.w,
//                             height: 22 / 14,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),

//         GestureDetector(
//           onTap: ontap,
//           child: Container(
//             height: 43.w,
//             width: 70.w,
//             alignment: Alignment.center,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(100.w),
//               image: DecorationImage(
//                 image: AssetImage('assets/images/vip/play.png'),
//                 fit: BoxFit.fill,
//               ),
//             ),
//             child: Text(
//               "Play".tr,
//               style: TextStyle(
//                 color: ColorUtil.fromHexString("#FFFFFF"),
//                 fontWeight: FontWeight.w600,
//                 fontSize: 12.w,
//                 letterSpacing: 2,
//                 height: 22 / 12,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _lock() {
//     return Container(
//       height: 90.w,
//       decoration: BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage('assets/images/vip/lock-background.png'),
//           fit: BoxFit.fill,
//         ),
//       ),
//       padding: EdgeInsets.all(11.w),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 Text(
//                   "Unlock Dting membershi".tr,
//                   style: TextStyle(
//                     color: ColorUtil.fromHexString("#161616"),
//                     fontWeight: FontWeight.w500,
//                     fontSize: 16.w,
//                     height: 22 / 16,
//                   ),
//                 ),
//                 Text(
//                   "Binding Dting devices can activate Starter membership benefits"
//                       .tr,

//                   style: TextStyle(
//                     overflow: TextOverflow.clip,
//                     color: ColorUtil.fromHexString("#1E1E1E"),
//                     fontWeight: FontWeight.w500,
//                     fontSize: 13.w,
//                     height: 22 / 13,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           GestureDetector(
//             onTap: () {
//               controller.unlock();
//             },
//             child: Container(
//               height: 30.w,
//               width: 68.w,
//               clipBehavior: Clip.antiAlias,
//               alignment: Alignment.center,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(100.w),
//                 image: DecorationImage(
//                   image: AssetImage('assets/images/vip/play.png'),
//                   fit: BoxFit.fill,
//                 ),
//               ),
//               child: Text(
//                 "Unlock".tr,
//                 style: TextStyle(
//                   color: ColorUtil.fromHexString("#FFFFFF"),
//                   fontWeight: FontWeight.w600,
//                   fontSize: 12.w,
//                   height: 22 / 12,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _userbox() {
//     var phone = controller.appController.userInfo.value.username;
//     if (phone != null) {
//       phone = phone.substring(0, 3) + '*' * 4 + phone.substring(3 + 4);
//     }
//     return Row(
//       children: [
//         ImageNetwork(
//           url: controller.appController.userInfo.value.avatarUrl,
//           size: 26,
//         ),
//         SizedBox(width: 7.w),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               controller.appController.userInfo.value.nickname ?? "--".tr,
//               style: TextStyle(
//                 color: ColorUtil.fromHexString("#1D2129"),
//                 fontWeight: FontWeight.w500,
//                 fontSize: 17.w,
//                 height: 24 / 17,
//               ),
//             ),
//             Text(
//               phone ?? "",
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 color: ColorUtil.fromHexString("#1D2129"),
//                 fontWeight: FontWeight.w500,
//                 fontSize: 17.w,
//                 height: 24 / 17,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }
