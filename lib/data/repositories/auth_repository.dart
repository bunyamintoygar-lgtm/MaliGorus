import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());



final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;

  Future<bool> isProfileCompleted() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final response = await _client
        .from('profiles')
        .select('profile_completed')
        .eq('id', user.id)
        .single();
    
    return response['profile_completed'] ?? false;
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> verifyResetToken(String email, String token) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  Future<void> verifySignupOTP(String email, String token) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : 'com.maligorus.app://login-callback',
        );
        return;
      }

      // Android/iOS Native Google Sign In
      // ÖNEMLİ: serverClientId olarak Supabase Dashboard -> Authentication -> Providers -> Google
      // kısmındaki "Web Client ID" değerini kullanmalısınız.
      const webClientId = '792441054305-97ibrrkdg03kei2es0nknr7900urounm.apps.googleusercontent.com';
      
      // Google Sign In 7.x sürümü için yeni API kullanımı
      await GoogleSignIn.instance.initialize(
        serverClientId: webClientId,
      );
      
      final googleUser = await GoogleSignIn.instance.authenticate();
      final displayName = googleUser.displayName;
      if (displayName != null && displayName.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('oauth_full_name', displayName);
      }
      
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Google ID Token bulunamadı.';
      }

      // google_sign_in 7.0+ sürümünde accessToken, authorizationClient üzerinden alınmalıdır.
      final scopes = ['email', 'profile', 'openid'];
      var authorization = await googleUser.authorizationClient.authorizationForScopes(scopes);
      
      // Eğer sessizce alınamadıysa (nadir), yetkilendirme iste.
      authorization ??= await googleUser.authorizationClient.authorizeScopes(scopes);
      
      final accessToken = authorization.accessToken;

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    if (!kIsWeb && Platform.isIOS) {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final givenName = credential.givenName;
      final familyName = credential.familyName;
      if (givenName != null || familyName != null) {
        final prefs = await SharedPreferences.getInstance();
        final name = '${givenName ?? ''} ${familyName ?? ''}'.trim();
        if (name.isNotEmpty) {
          await prefs.setString('oauth_full_name', name);
        }
      }

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw 'Apple ID token bulunamadı.';
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );
    } else {
      await _client.auth.signInWithOAuth(OAuthProvider.apple);
    }
  }
}


