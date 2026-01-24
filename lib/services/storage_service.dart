import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadComplaintImage(File file, {required String folder}) async {
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    final ref = _storage.ref().child("$folder/$fileName");

    await ref.putFile(file);

    return await ref.getDownloadURL();
  }
}
