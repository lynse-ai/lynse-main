import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class ImageNetwork extends GetView {
  ImageNetwork({
    super.key,
    this.url,
    this.size = 80,
    this.defaultImage = "assets/images_v3/default.png",
  });

  String? url;
  final double size;
  String defaultImage;

  @override
  Widget build(BuildContext context) {
    return url != null && url != ""
        ? Container(
          width: size.w,
          height: size.w,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(shape: BoxShape.circle),
          child: Image.network(
            url!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _defaultImage();
            },
            errorBuilder: (context, error, stackTrace) {
              return _defaultImage();
            },
          ),
        )
        : _defaultImage();
  }

  Widget _defaultImage() {
    return Container(
      width: size.w,
      height: size.w,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle),
      child: Image.asset(
        defaultImage,
        height: size.w,
        width: size.w,
        fit: BoxFit.contain,
      ),
    );
  }
}
