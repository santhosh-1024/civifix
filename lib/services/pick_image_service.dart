import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PickImageService {
  static Future<Uint8List?> pickImageBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true, // IMPORTANT for web
    );

    if (result == null) return null;
    return result.files.single.bytes;
  }
}
