import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('pubspec.yaml');
  if (!await file.exists()) {
    print('Hata: pubspec.yaml bulunamadı.');
    return;
  }

  final lines = await file.readAsLines();
  final newLines = <String>[];
  String? newVersion;

  for (var line in lines) {
    if (line.startsWith('version:')) {
      final parts = line.split('+');
      if (parts.length == 2) {
        final versionPrefix = parts[0]; // version: 1.0.0
        final buildNumber = int.tryParse(parts[1].trim());
        if (buildNumber != null) {
          final newBuildNumber = buildNumber + 1;
          newVersion = '$versionPrefix+$newBuildNumber';
          newLines.add(newVersion);
          continue;
        }
      }
    }
    newLines.add(line);
  }

  if (newVersion != null) {
    await file.writeAsString(newLines.join('\n') + '\n');
    print('🚀 Versiyon güncellendi: $newVersion');

    // Supabase RPC aracılığıyla min_app_version'u güncelle
    final cleanVersion = newVersion.replaceAll('version:', '').trim();
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('https://yvytejobimltbefxrsjc.supabase.co/rest/v1/rpc/update_min_version'));
      request.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2eXRlam9iaW1sdGJlZnhyc2pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzAxNTAsImV4cCI6MjA5MjU0NjE1MH0.DtDI1BJxjnr1kgxjME9AU9wU7TCBUwY-u0PqOcz7hHI');
      request.headers.add('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2eXRlam9iaW1sdGJlZnhyc2pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzAxNTAsImV4cCI6MjA5MjU0NjE1MH0.DtDI1BJxjnr1kgxjME9AU9wU7TCBUwY-u0PqOcz7hHI');
      request.headers.add('Content-Type', 'application/json');

      final payload = json.encode({
        'new_version': cleanVersion,
      });

      request.write(payload);
      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        print('🌐 Veritabanındaki min_app_version başarıyla güncellendi: $cleanVersion');
      } else {
        print('⚠️ Veritabanı güncelleme başarısız (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('⚠️ Veritabanı güncelleme hatası: $e');
    } finally {
      client.close();
    }
    
    print('📦 AppBundle derlemesi başlatılıyor...');
    final process = await Process.start(
      'flutter', 
      ['build', 'appbundle'], 
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
    
    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      print('✅ Derleme başarıyla tamamlandı.');
    } else {
      print('❌ Derleme hata ile sonuçlandı (Exit code: $exitCode).');
    }
  } else {
    print('Hata: pubspec.yaml içinde version satırı bulunamadı veya formatı yanlış (Örn: 1.0.0+1 olmalı).');
  }
}
