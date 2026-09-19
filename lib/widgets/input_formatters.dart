// import 'package:flutter/services.dart';

// class OnlyLetterNumberFormatter extends TextInputFormatter {
//   final RegExp _emojiRegex = RegExp(
//     r'[\u{1F600}-\u{1F64F}]|' // 表情符号
//     r'[\u{1F300}-\u{1F5FF}]|' // 符号&图形
//     r'[\u{1F680}-\u{1F6FF}]|' // 交通工具&地图
//     r'[\u{2600}-\u{26FF}]|' // 杂项符号
//     r'[\u{2700}-\u{27BF}]', // 印刷符号
//     unicode: true,
//   );
//   @override
//   TextEditingValue formatEditUpdate(
//     TextEditingValue oldValue,
//     TextEditingValue newValue,
//   ) {
//     // 过滤掉 emoji
//     String newText = newValue.text.replaceAll(_emojiRegex, '');
//     return TextEditingValue(
//       text: newText,
//       selection: TextSelection.collapsed(offset: newText.length),
//     );
//   }
// }
