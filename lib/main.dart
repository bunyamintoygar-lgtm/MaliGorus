import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/repositories/auth_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';

import 'package:flutter/foundation.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Supabase Başlatma
  await Supabase.initialize(
    url: 'https://yvytejobimltbefxrsjc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2eXRlam9iaW1sdGJlZnhyc2pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzAxNTAsImV4cCI6MjA5MjU0NjE1MH0.DtDI1BJxjnr1kgxjME9AU9wU7TCBUwY-u0PqOcz7hHI',
  );

  // Firebase Başlatma (Web'de seçenekler olmadan hata verdiği için kontrol ekliyoruz)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      // Bildirim Servisini Başlat
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('Firebase başlatılamadı (Dosyalar eksik olabilir): $e');
    }
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: const ProviderScope(
        child: MaliGorusApp(),
      ),
    ),
  );
}

class MaliGorusApp extends ConsumerWidget {
  const MaliGorusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouter);

    // Oturum değişikliklerini dinle ve token'ı güncelle
    ref.listen(authStateProvider, (previous, next) {
      final session = next.asData?.value.session;
      if (session != null) {
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          NotificationService.updateToken();
        }
      }
    });

    return MaterialApp.router(
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: MediaQuery.removePadding(
            context: context,
            child: Builder(
              builder: (ctx) {
                final viewInsets = MediaQuery.of(ctx).viewInsets;
                final isKeyboardVisible = viewInsets.bottom > 0;
                // Klavye açıkken içeriğin altına kapat barı (42px) kadar padding ekle
                final extraBottomPadding = isKeyboardVisible ? 42.0 : 0.0;
                return Stack(
                  children: [
                    MediaQuery(
                      data: MediaQuery.of(ctx).copyWith(
                        viewInsets: viewInsets.copyWith(
                          bottom: viewInsets.bottom + extraBottomPadding,
                        ),
                      ),
                      child: child!,
                    ),
                    if (isKeyboardVisible)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: viewInsets.bottom,
                        child: Material(
                          color: const Color(0xFFF5F5F7),
                          elevation: 1,
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFD1D1D6), width: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'common_close'.tr(),
                                    style: const TextStyle(
                                      color: Color(0xFF007AFF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
      title: 'MaliGörüş',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
