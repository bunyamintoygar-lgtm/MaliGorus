import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/profile_completion_screen.dart';
import '../../features/home/main_shell.dart';
import '../../features/surveys/create_survey_screen.dart';
import '../../features/credits/credit_details_screen.dart';
import '../../features/credits/credit_earn_screen.dart';
import '../../features/credits/credit_history_screen.dart';
import '../../features/chat/chat_detail_screen.dart';
import '../../features/listings/listings_screen.dart';
import '../../features/listings/create_listing_screen.dart';
import '../../features/listings/listing_detail_screen.dart';
import '../../data/models/listing_model.dart';
import '../../features/admin/credit_config_screen.dart';
import '../../features/admin/admin_level_config_screen.dart';
import '../../features/discussions/create_discussion_screen.dart';
import '../../features/discussions/create_consultation_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/profile_photo_screen.dart';
import '../../features/profile/other_profile_screen.dart';
import '../../features/profile/follows_list_screen.dart';
import '../../features/connections/participants_screen.dart';
import '../../features/connections/participant_detail_screen.dart';
import '../../features/discussions/discussion_detail_screen.dart';
import '../../features/discussions/consultation_detail_screen.dart';
import '../../data/models/discussion_model.dart';
import '../../features/referral/referral_landing_screen.dart';
import '../../features/credits/credit_gift_screen.dart';
import '../../features/reports/report_user_screen.dart';
import '../../features/admin/admin_reports_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_users_screen.dart';
import '../../features/admin/admin_listings_screen.dart';
import '../../features/admin/admin_announcements_screen.dart';
import '../../features/admin/admin_policies_screen.dart';
import '../../features/admin/admin_faqs_screen.dart';
import '../../features/admin/admin_support_requests_screen.dart';
import '../../features/profile/policies_viewer_screen.dart';
import '../../features/profile/help_support_screen.dart';
import '../../features/profile/about_us_screen.dart';
import '../../features/profile/security_settings_screen.dart';
import '../../features/admin/admin_market_products_screen.dart';
import '../../features/admin/admin_market_product_form_screen.dart';
import '../../features/admin/admin_market_product_hub_screen.dart';
import '../../features/admin/admin_market_requests_screen.dart';
import '../../features/profile/notification_settings_screen.dart';
import '../../features/profile/blocked_users_screen.dart';
import '../../features/market/market_dashboard_screen.dart';
import '../../features/market/documents_templates_screen.dart';
import '../../features/market/certificate_programs_screen.dart';
import '../../features/market/live_training_screen.dart';
import '../../features/market/events_screen.dart';
import '../../features/market/consulting_services_screen.dart';
import '../../features/market/market_cart_screen.dart';
import '../../features/market/market_detail_screen.dart';
import '../../features/market/market_purchase_success_screen.dart';
import '../../data/models/market_product_model.dart';

class AuthListenable extends ChangeNotifier {
  AuthListenable(Stream<AuthState> authStateChanges) {
    authStateChanges.listen((event) {
      notifyListeners();
    });
  }
}

final appRouter = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: AuthListenable(authRepo.authStateChanges),
    redirect: (context, state) async {
      final user = authRepo.currentUser;
      final isAuthRoute = state.matchedLocation == '/login' || 
                          state.matchedLocation == '/register' || 
                          state.matchedLocation == '/forgot-password';
      final isPublicRoute = isAuthRoute || state.matchedLocation.startsWith('/policies');

      // Referans sayfası auth gerektirmez
      if (state.matchedLocation.startsWith('/ref/')) {
        return null;
      }

      if (user == null) {
        return isPublicRoute ? null : '/login';
      }

      final profileCompleted = await authRepo.isProfileCompleted();
      final completingProfile = state.matchedLocation == '/profile-completion';

      if (!profileCompleted) {
        return completingProfile ? null : '/profile-completion';
      }

      if (state.matchedLocation == '/login' || state.matchedLocation == '/register' || state.matchedLocation == '/') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/profile-completion', builder: (context, state) => const ProfileCompletionScreen()),
      GoRoute(path: '/home', builder: (context, state) => const MainShell()),
      GoRoute(path: '/create-survey', builder: (context, state) => const CreateSurveyScreen()),
      GoRoute(path: '/credits', builder: (context, state) => const CreditDetailsScreen()),
      GoRoute(
        path: '/credit-earn',
        builder: (context, state) {
          final scrollToPackages = state.extra == 'packages' || state.uri.queryParameters['scrollTo'] == 'packages';
          return CreditEarnScreen(scrollToPackages: scrollToPackages);
        },
      ),
      GoRoute(
        path: '/chat/detail', 
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ChatDetailScreen(
            otherUserId: extra['userId'],
            otherUserName: extra['userName'],
            otherUserAvatar: extra['userAvatar'],
            otherUserTitle: extra['userTitle'],
            otherUserHighestLevel: extra['userHighestLevel'],
          );
        },
      ),
      GoRoute(path: '/listings', builder: (context, state) => const ListingsScreen()),
      GoRoute(
        path: '/create-listing', 
        builder: (context, state) => CreateListingScreen(listing: state.extra as ListingModel?),
      ),
      GoRoute(
        path: '/listing-detail',
        builder: (context, state) => ListingDetailScreen(listing: state.extra as ListingModel),
      ),
      GoRoute(path: '/admin/config', builder: (context, state) => const AdminCreditConfigScreen()),
      GoRoute(path: '/admin/levels', builder: (context, state) => const AdminLevelConfigScreen()),
      GoRoute(path: '/help-support', builder: (context, state) => const HelpSupportScreen()),
      GoRoute(path: '/about', builder: (context, state) => const AboutUsScreen()),
      GoRoute(path: '/security', builder: (context, state) => const SecuritySettingsScreen()),
      GoRoute(path: '/admin/reports', builder: (context, state) => const AdminReportsScreen()),
      GoRoute(path: '/admin/dashboard', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/users', builder: (context, state) => const AdminUsersScreen()),
      GoRoute(path: '/admin/listings', builder: (context, state) => const AdminListingsScreen()),
      GoRoute(path: '/admin/announcements', builder: (context, state) => const AdminAnnouncementsScreen()),
      GoRoute(path: '/admin/policies', builder: (context, state) => const AdminPoliciesScreen()),
      GoRoute(path: '/admin/faqs', builder: (context, state) => const AdminFAQsScreen()),
      GoRoute(path: '/admin/support-requests', builder: (context, state) => const AdminSupportRequestsScreen()),
      GoRoute(
        path: '/report',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ReportScreen(
            reportedId: extra['reportedId'],
            reportedTitle: extra['reportedTitle'],
            contentType: extra['contentType'] ?? 'user',
          );
        },
      ),
      GoRoute(
        path: '/create-discussion', 
        builder: (context, state) {
          final discussion = state.extra as DiscussionModel?;
          return CreateDiscussionScreen(discussion: discussion);
        },
      ),
      GoRoute(
        path: '/create-consultation', 
        builder: (context, state) {
          final discussion = state.extra as DiscussionModel?;
          return CreateConsultationScreen(discussion: discussion);
        },
      ),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/participants', builder: (context, state) => const ParticipantsScreen()),
      GoRoute(
        path: '/participant-detail/:id',
        builder: (context, state) => ParticipantDetailScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile/photo',
        builder: (context, state) {
          final initialUrl = state.extra as String?;
          return ProfilePhotoScreen(initialAvatarUrl: initialUrl);
        },
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) => OtherProfileScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile/:id/follows',
        builder: (context, state) {
          final userId = state.pathParameters['id']!;
          final tab = state.uri.queryParameters['tab'] ?? 'followers';
          return FollowsListScreen(userId: userId, initialTab: tab);
        },
      ),
      GoRoute(
        path: '/profile/other/:id',
        builder: (context, state) => OtherProfileScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/credit-gift',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CreditGiftScreen(
            userId: extra['userId'],
            userName: extra['userName'],
          );
        },
      ),
      GoRoute(
        path: '/discussion/detail',
        builder: (context, state) {
          final discussion = state.extra as DiscussionModel;
          if (discussion.type == 'danisma') {
            return ConsultationDetailScreen(discussion: discussion);
          }
          return DiscussionDetailScreen(discussion: discussion);
        },
      ),
      GoRoute(
        path: '/ref/:code',
        builder: (context, state) => ReferralLandingScreen(
          referralCode: state.pathParameters['code']!,
        ),
      ),
      GoRoute(
        path: '/policies',
        builder: (context, state) => const PoliciesViewerScreen(),
      ),
      GoRoute(
        path: '/policies/:id',
        builder: (context, state) => StandalonePolicyScreen(slug: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/help-support',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(path: '/admin/market-products', builder: (context, state) => const AdminMarketProductsScreen()),
      GoRoute(
        path: '/admin/market-products/form',
        builder: (context, state) {
          MarketProductModel? product;
          int? initialStep;
          if (state.extra is MarketProductModel) {
            product = state.extra as MarketProductModel;
          } else if (state.extra is Map<String, dynamic>) {
            final map = state.extra as Map<String, dynamic>;
            final rawProduct = map['product'];
            if (rawProduct is MarketProductModel) {
              product = rawProduct;
            } else if (rawProduct is Map<String, dynamic>) {
              product = MarketProductModel.fromJson(rawProduct);
            }
            initialStep = map['initialStep'] as int?;
          }
          return AdminMarketProductFormScreen(
            product: product,
            initialStep: initialStep,
          );
        },
      ),
      GoRoute(
        path: '/admin/market-products/hub',
        builder: (context, state) {
          MarketProductModel? product;
          if (state.extra is MarketProductModel) {
            product = state.extra as MarketProductModel;
          } else if (state.extra is Map<String, dynamic>) {
            product = MarketProductModel.fromJson(state.extra as Map<String, dynamic>);
          }
          return AdminMarketProductHubScreen(
            product: product!,
          );
        },
      ),
      GoRoute(path: '/admin/market-requests', builder: (context, state) => const AdminMarketRequestsScreen()),
      GoRoute(path: '/notification-settings', builder: (context, state) => const NotificationSettingsScreen()),
      GoRoute(path: '/blocked-users', builder: (context, state) => const BlockedUsersScreen()),
      GoRoute(path: '/credits/history', builder: (context, state) => const CreditHistoryScreen()),
      GoRoute(path: '/market', builder: (context, state) => const MarketDashboardScreen()),
      GoRoute(path: '/market/documents', builder: (context, state) => const DocumentsTemplatesScreen()),
      GoRoute(path: '/market/certificates', builder: (context, state) => const CertificateProgramsScreen()),
      GoRoute(path: '/market/live-training', builder: (context, state) => const LiveTrainingScreen()),
      GoRoute(path: '/market/events', builder: (context, state) => const EventsScreen()),
      GoRoute(path: '/market/consulting', builder: (context, state) => const ConsultingServicesScreen()),
      GoRoute(path: '/market/cart', builder: (context, state) => const MarketCartScreen()),
      GoRoute(
        path: '/market/purchase-success',
        builder: (context, state) {
          final items = state.extra as List<MarketProductModel>;
          return MarketPurchaseSuccessScreen(purchasedItems: items);
        },
      ),
      GoRoute(
        path: '/market/detail',
        builder: (context, state) {
          final product = state.extra as MarketProductModel;
          return MarketDetailScreen(product: product);
        },
      ),
    ],
  );
});
