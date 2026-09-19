import 'package:get/get.dart';
import 'package:intl/intl.dart';

class DateTimeHelper {
  DateTimeHelper._();

  static String timeCover(String? value) {
    if (value != null) {
      var dateTime = DateTime.parse(value);
      // var locale = Get.locale;
      // String loca = "zh";
      // if (locale != null) {
      //   loca = locale.languageCode;
      // }
      // return DateFormat('yyyy-mm-dd', loca).format(dateTime);
      return DateFormat('yyyy-MM-dd').format(dateTime);
    } else {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  static String timeCoverToMdHs(String value) {
    DateTime dateTime = DateTime.parse(value);
    return "${dateTime.month}${"moon".tr}${dateTime.day}${"d".tr} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  static String dateTimeCoverTOString(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  static int convertDurationTransSecond(Duration duration) {
    // var time = 0;
    // var hours = duration.inHours * 3600;
    // var minuts = duration.inMinutes * 60;
    // var second = duration.inSeconds;
    // var millis = duration.inMilliseconds;

    // time = hours + minuts + second;
    // if (millis != 0) {
    //   time += 1;
    // }

    return duration.inSeconds;
  }

  static String formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours${"h".tr}$minutes${"m".tr}$seconds${"s".tr}';
    } else if (minutes > 0) {
      return '$minutes${"m".tr}$seconds${"s".tr}';
    } else {
      return '$seconds${"s".tr}';
    }
  }

  static String formatSecondsToHms(int seconds) {
    Duration duration = Duration(seconds: seconds);
    // return "${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";

    return "${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  static String coverDurationTransString(Duration duration) {
    var seconds = convertDurationTransSecond(duration);
    return formatSecondsToHms(seconds);
  }

  static Duration converSecondTransDuration(double second) {
    int roundedNumber = second.round().toInt();
    return Duration(milliseconds: roundedNumber * 1000);
  }

  static String fmtTimestamp(int timestamp, String fmt) {
    return DateFormat(
      fmt,
    ).format(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000));
  }

  static String fmtSeconds(
    int totalSeconds, {
    bool showHour = true,
    bool showZero = true,
  }) {
    Duration duration = Duration(seconds: totalSeconds);

    // 获取时分秒（自动处理溢出）
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);

    // 按需拼接字符串
    String result = "";
    if (showHour || hours > 0) {
      result += "${showZero ? hours.toString().padLeft(2, '0') : hours}小时";
    }
    result += "${showZero ? minutes.toString().padLeft(2, '0') : minutes}分";
    result += "${showZero ? seconds.toString().padLeft(2, '0') : seconds}秒";

    return result;
  }
}
