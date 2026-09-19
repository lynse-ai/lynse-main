import 'package:image_picker/image_picker.dart';

class ImageHelper {
  ImageHelper._();

  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> getPhoto(ImageSource source) async {
    try {
      return await _picker.pickImage(source: source);
    } catch (e) {
      return null;
    }
  }

  static Future<XFile?> getVideo(ImageSource source) async {
    try {
      return await _picker.pickVideo(source: source);
    } catch (e) {
      return null;
    }
  }
}
