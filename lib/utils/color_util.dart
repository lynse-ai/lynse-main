import 'package:flutter/material.dart';

class ColorUtil {
  static Color fromHexInt(int hex, [double? opacity]) {
    if (hex < 0x0 || hex > 0xFFFFFFFF) {
      throw ArgumentError('Hex传值不正确');
    }

    if (hex <= 0xFFFFFF) {
      return Color.fromRGBO(
        (hex >> 16) & 0xFF,
        (hex >> 8) & 0xFF,
        hex & 0xFF,
        opacity ?? 1.0,
      );
    } else {
      return Color((hex & 0xFFFFFFFF));
    }
  }

  static Color fromHexString(String hex, [double? opacity]) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      return Color.fromRGBO(
        int.parse(hex.substring(0, 2), radix: 16),
        int.parse(hex.substring(2, 4), radix: 16),
        int.parse(hex.substring(4, 6), radix: 16),
        opacity ?? 1.0,
      );
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    } else {
      throw ArgumentError("Hex传值不正确");
    }
  }
}
