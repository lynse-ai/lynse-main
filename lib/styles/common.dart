import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

extension BoldTextExtension on Text {
  Text boldTitle({
    double fontSize = 14,
    Color? color,
    TextOverflow? overflow,
    int? maxLine,
    TextAlign textAlign = TextAlign.left,
    double? height,
    TextDecoration? decoration,
    double? decorationThickness,
    Color? decorationColor,
    double? letterSpacing,
  }) {
    return Text(
      data ?? '',
      maxLines: maxLine,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        height: height,
        fontWeight: FontWeight.w500,
        fontSize: fontSize.w,
        letterSpacing: letterSpacing,
        decoration: decoration,
        decorationThickness: decorationThickness,
        decorationColor: decorationColor,
      ),
    );
  }

  Text mainTitle({
    double fontSize = 14,
    Color? color,
    TextOverflow? overflow,
    int? maxLine,
    double? height,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Text(
      data ?? '',
      maxLines: maxLine,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(
        height: height,
        decoration: TextDecoration.none,
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: fontSize.w,
      ),
    );
  }

  Text descText({
    double fontSize = 14,
    Color? color,
    TextOverflow? overflow,
    int? maxLine,
    double? height,
    double? letterSpacing,
    TextAlign? textAlign,
    TextDecoration? decoration,
    double? decorationThickness,
    Color? decorationColor,
  }) {
    return Text(
      data ?? '',
      maxLines: maxLine,
      overflow: overflow,
      textAlign: textAlign,
      style: TextStyle(
        height: height,
        color: color,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w400,
        fontSize: fontSize.w,
        decoration: decoration,
        decorationThickness: decorationThickness,
        decorationColor: decorationColor,
      ),
    );
  }
}
