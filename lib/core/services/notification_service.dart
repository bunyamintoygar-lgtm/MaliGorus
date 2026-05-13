import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    // 1. İzinleri İste
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Bildirim izni verildi.');
      
      // 2. Token Al ve Kaydet
      await updateToken();

      // 3. Yerel Bildirimleri Yapılandır
      await _setupLocalNotifications();

      // 4. Foreground (Ön Plan) Mesaj Dinleyicisi
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. Background (Arka Plan) Tıklama Dinleyicisi
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // 6. Token Yenilenme Dinleyicisi
      _messaging.onTokenRefresh.listen(_saveTokenToSupabase);
    }
  }

  static Future<void> updateToken() async {
    try {
      // APNS Token kontrolünü kaldırıp doğrudan Token almaya çalışalım
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token başarıyla alındı: $token');
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('FCM Token alma hatası: $e');
    }
  }


  static Future<void> _saveTokenToSupabase(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('fcm_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'device_type': Platform.isAndroid ? 'android' : 'ios',
        'last_seen': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, token');
    } catch (e) {
      print('Token kaydetme hatası: $e');
    }
  }

  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);

    // Android için bildirim kanalını oluştur
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', 
      'Yüksek Öncelikli Bildirimler',
      description: 'Bu kanal önemli bildirimler için kullanılır.',
      importance: Importance.max,
    );

    await androidImplementation?.createNotificationChannel(channel);
  }

  static void _handleForegroundMessage(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    
    // Görsel URL'sini hem notification'dan hem data'dan kontrol et
    String? imageUrl = android?.imageUrl ?? message.data['image_url'];

    if (notification != null) {
      String? largeIconPath;
      
      // Eğer görsel varsa indir
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(imageUrl));
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/notif_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          largeIconPath = filePath;
        } catch (e) {
          debugPrint('Bildirim görseli indirilemedi: $e');
        }
      }

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Yüksek Öncelikli Bildirimler',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFF1a237e),
            largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
            styleInformation: largeIconPath != null 
                ? BigPictureStyleInformation(
                    FilePathAndroidBitmap(largeIconPath),
                    largeIcon: FilePathAndroidBitmap(largeIconPath),
                    contentTitle: notification.title,
                    summaryText: notification.body,
                  ) 
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    // Bildirime tıklandığında yapılacak işlemler (Örn: belirli bir sayfaya yönlendirme)
    print('Bildirime tıklandı: ${message.data}');
  }
}
