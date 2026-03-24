import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class SyncService {
    // Удалить файл из Supabase по публичной ссылке или пути
    Future<void> deleteImageByUrl(String url) async {
      try {
        // Извлекаем путь внутри bucket (после /object/notes/)
        final uri = Uri.parse(url);
        final idx = uri.path.indexOf('/notes/');
        if (idx == -1) return;
        final path = uri.path.substring(idx + '/notes/'.length);
        await _supabase.storage.from('notes').remove([path]);
      } catch (e) {
        debugPrint('Ошибка удаления из Supabase: $e');
      }
    }

    // Удалить несколько файлов
    Future<void> deleteImagesByUrls(List<String> urls) async {
      for (final url in urls) {
        if (url.startsWith('http')) {
          await deleteImageByUrl(url);
        }
      }
    }
  final String userId;
  SyncService(this.userId);

  final _supabase = Supabase.instance.client;

  Future<List<String>> uploadImages(List<String> paths) async {
    List<String> resultUrls = [];

    for (String path in paths) {
      // Если это уже ссылка — пропускаем
      if (path.startsWith('http')) {
        resultUrls.add(path);
        continue;
      }

      File file = File(path);
      if (!await file.exists()) {
        resultUrls.add("");
        continue;
      }

      try {
        // 1. СЖАТИЕ (Оптимизация места)
        final tempDir = await getTemporaryDirectory();
        final targetPath = p.join(
          tempDir.path,
          "${DateTime.now().millisecondsSinceEpoch}.jpg",
        );

        final XFile? compressedFile =
            await FlutterImageCompress.compressAndGetFile(
              file.absolute.path,
              targetPath,
              quality: 70,
              minWidth: 1024,
            );

        if (compressedFile == null) {
          resultUrls.add("");
          continue;
        }

        // 2. ЗАГРУЗКА В SUPABASE
        final fileName =
            '$userId/${DateTime.now().millisecondsSinceEpoch}${p.extension(path)}';

        await _supabase.storage
            .from('notes')
            .upload(
              fileName,
              File(compressedFile.path),
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );

        // 3. ПОЛУЧЕНИЕ ССЫЛКИ
        final String publicUrl = _supabase.storage
            .from('notes')
            .getPublicUrl(fileName);
        resultUrls.add(publicUrl);

        // Удаляем временный сжатый файл
        await File(compressedFile.path).delete();
      } catch (e) {
        debugPrint('Ошибка Supabase: $e');
        resultUrls.add(""); // В случае ошибки не добавляем локальный путь
      }
    }
    return resultUrls;
  }
}
