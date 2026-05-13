import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

final fileServiceProvider = Provider((ref) => FileService());

class FileService {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // Resim Seç (Profil vb. için)
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    return await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
  }


  // Doküman Seç (Danışma ekleri için)
  Future<PlatformFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'png'],
      withData: true, // Web için gerekli
    );
    return result?.files.first;
  }

  // Genel Yükleme Metodu (XFile desteği ile)
  Future<String?> uploadFile({
    required dynamic file, // XFile veya PlatformFile
    required String bucket,
    required String folder,
  }) async {
    try {
      Uint8List? bytes;
      String name;

      if (file is XFile) {
        bytes = await file.readAsBytes();
        name = file.name;
      } else if (file is PlatformFile) {
        bytes = file.bytes;
        name = file.name;
      } else {
        return null;
      }

      if (bytes == null) return null;

      final extension = p.extension(name).toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final path = '$folder/$fileName';

      // MIME type tahmini
      String contentType = 'application/octet-stream';
      if (extension == '.pdf') contentType = 'application/pdf';
      else if (extension == '.jpg' || extension == '.jpeg') contentType = 'image/jpeg';
      else if (extension == '.png') contentType = 'image/png';
      else if (extension.startsWith('.doc')) contentType = 'application/msword';
      else if (extension.startsWith('.xls')) contentType = 'application/vnd.ms-excel';

      await _client.storage.from(bucket).uploadBinary(
        path, 
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );

      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }
  Future<bool> deleteFile(String url, String bucket) async {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.sublist(uri.pathSegments.indexOf(bucket) + 1).join('/');
      await _client.storage.from(bucket).remove([path]);
      return true;
    } catch (e) {
      print('Delete Error: $e');
      return false;
    }
  }
}
