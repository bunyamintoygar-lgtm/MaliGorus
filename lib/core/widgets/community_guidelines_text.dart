import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class CommunityGuidelinesText extends StatelessWidget {
  const CommunityGuidelinesText({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text.rich(
          TextSpan(
            text: 'İçerik paylaşarak ',
            style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.4),
            children: [
              TextSpan(
                text: 'Topluluk Kuralları',
                style: const TextStyle(
                  color: AppTheme.actionBlue,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    // Kullanım koşulları/Sözleşme sayfasına yönlendir
                    context.push('/policies/terms_of_service');
                  },
              ),
              const TextSpan(text: '\'nı kabul etmiş sayılırsınız.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
