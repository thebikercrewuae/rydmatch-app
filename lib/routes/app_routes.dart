import 'package:flutter/material.dart';
import '../presentation/discovery_screen/discovery_screen.dart';
import '../presentation/profile_setup_screen/profile_setup_screen.dart';
import '../presentation/profile_view_screen/profile_view_screen.dart';
import '../presentation/matches_screen/matches_screen.dart';
import '../presentation/main_screen/main_screen.dart';
import '../presentation/login_screen/login_screen.dart';
import '../presentation/registration_screen/registration_screen.dart';
import '../presentation/chat_screen/chat_screen.dart';
import '../presentation/garage_screen/garage_screen.dart';
import '../presentation/settings_screen/settings_screen.dart';
import '../presentation/privacy_policy_screen/privacy_policy_screen.dart';
import '../presentation/terms_of_service_screen/terms_of_service_screen.dart';
import '../presentation/premium_subscription_screen/premium_subscription_screen.dart';
import '../presentation/ride_groups_screen/ride_groups_screen.dart';
import '../presentation/ride_analytics_screen/ride_analytics_screen.dart';
import '../presentation/emergency_sos_screen/emergency_sos_screen.dart';
import '../presentation/blocked_users_screen/blocked_users_screen.dart';
import '../presentation/report_user_screen/report_user_screen.dart';
import '../presentation/post_ride_rating_screen/post_ride_rating_screen.dart';
import '../presentation/badges_achievements_screen/badges_achievements_screen.dart';
import '../presentation/route_planner_screen/route_planner_screen.dart';
import '../presentation/ride_feed_screen/ride_feed_screen.dart';
import '../presentation/create_post_screen/create_post_screen.dart';
import '../presentation/notifications_screen/notifications_screen.dart';
import '../presentation/onboarding_screen/onboarding_screen.dart';
import '../presentation/leaderboard_screen/leaderboard_screen.dart';
import '../presentation/reset_password_screen/reset_password_screen.dart';
import '../presentation/verification_screen/verification_screen.dart';
import '../presentation/admin_verification_screen/admin_verification_screen.dart';
import '../presentation/admin_diagnostics_screen/admin_diagnostics_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String onboarding = '/onboarding-screen';
  static const String discovery = '/discovery-screen';
  static const String profileSetup = '/profile-setup-screen';
  static const String profileView = '/profile-view-screen';
  static const String matches = '/matches-screen';
  static const String main = '/main-screen';
  static const String login = '/login-screen';
  static const String registration = '/registration-screen';
  static const String chat = '/chat-screen';
  static const String garage = '/garage-screen';
  static const String settings = '/settings-screen';
  static const String privacyPolicy = '/privacy-policy-screen';
  static const String termsOfService = '/terms-of-service-screen';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String premiumSubscription = '/premium-subscription-screen';
  static const String rideGroups = '/ride-groups-screen';
  static const String rideAnalytics = '/ride-analytics-screen';
  static const String emergencySos = '/emergency-sos-screen';
  static const String reportUser = '/report-user-screen';
  static const String blockUserConfirmation = '/block-user-confirmation-screen';
  static const String blockedUsers = '/blocked-users-screen';
  static const String postRideRating = '/post-ride-rating-screen';
  static const String badgesAchievements = '/badges-achievements-screen';
  static const String routePlanner = '/route-planner-screen';
  static const String rideFeed = '/ride-feed-screen';
  static const String createPost = '/create-post-screen';
  static const String notifications = '/notifications-screen';
  static const String leaderboard = '/leaderboard-screen';
  static const String resetPassword = '/reset-password';
  static const String verificationScreen = '/verification-screen';
  static const String adminVerificationScreen = '/admin-verification-screen';
  static const String adminDiagnosticsScreen = '/admin-diagnostics-screen';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const RegistrationScreen(),
    onboarding: (context) => const OnboardingScreen(),
    discovery: (context) => const DiscoveryScreen(),
    profileSetup: (context) => const ProfileSetupScreen(),
    profileView: (context) => const ProfileViewScreen(),
    matches: (context) => const MatchesScreen(),
    main: (context) => const MainScreen(),
    login: (context) => const LoginScreen(),
    registration: (context) => const RegistrationScreen(),
    chat: (context) => const ChatScreen(),
    garage: (context) => const GarageScreen(),
    settings: (context) => const SettingsScreen(),
    privacyPolicy: (context) => const PrivacyPolicyScreen(),
    termsOfService: (context) => const TermsOfServiceScreen(),
    terms: (context) => const TermsOfServiceScreen(),
    privacy: (context) => const PrivacyPolicyScreen(),
    premiumSubscription: (context) => const PremiumSubscriptionScreen(),
    rideGroups: (context) => const RideGroupsScreen(),
    rideAnalytics: (context) => const RideAnalyticsScreen(),
    emergencySos: (context) => const EmergencySosScreen(),
    reportUser: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        return ReportUserScreen(
          reportedUserId: args['reportedUserId'] as String? ?? '',
          reportedUserName: args['reportedUserName'] as String? ?? 'User',
          reportedUserImage: args['reportedUserImage'] as String?,
        );
      }
      return const ReportUserScreen(
        reportedUserId: '',
        reportedUserName: 'User',
      );
    },
    blockUserConfirmation: (context) => const _BlockUserPlaceholder(),
    blockedUsers: (context) => const BlockedUsersScreen(),
    postRideRating: (context) => const PostRideRatingScreen(),
    badgesAchievements: (context) => const BadgesAchievementsScreen(),
    routePlanner: (context) => const RoutePlannerScreen(),
    rideFeed: (context) => const RideFeedScreen(),
    createPost: (context) => const CreatePostScreen(),
    notifications: (context) => const NotificationsScreen(),
    leaderboard: (context) => const LeaderboardScreen(),
    resetPassword: (context) => const ResetPasswordScreen(),
    verificationScreen: (context) => const VerificationScreen(),
    adminVerificationScreen: (context) => const AdminVerificationScreen(),
    adminDiagnosticsScreen: (context) => const AdminDiagnosticsScreen(),
  };
}

// Placeholder widgets for modal-only screens (they are shown via show() methods)
class _BlockUserPlaceholder extends StatelessWidget {
  const _BlockUserPlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
