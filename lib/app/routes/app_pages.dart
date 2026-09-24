import 'package:get/get.dart';
import '../modules/auth/auth_binding.dart';
import '../modules/auth/login_view.dart';
import '../modules/call/call_screen.dart';
import '../modules/call/incoming_call_screen.dart';
import '../modules/chat/chat_binding.dart';
import '../modules/chat/chat_view.dart';
import '../modules/main_admin/main_admin_binding.dart';
import '../modules/main_admin/main_admin_view.dart';
import '../modules/main_student_teacher/student/student_main_view.dart';
import '../modules/main_student_teacher/teacher/teacher_assessments_binding.dart';
import '../modules/main_student_teacher/teacher/teacher_assessments_tab.dart';
import '../modules/main_student_teacher/teacher/teacher_followUp_tab.dart';
import '../modules/main_student_teacher/teacher/teacher_followup_binding.dart';
import '../modules/main_student_teacher/teacher/teacher_main_view.dart';
import '../modules/main_student_teacher/teacher/teacher_reports_tab.dart';
import '../modules/profile/profile_view.dart';
import '../modules/main_student_teacher/quality_admin/quality_admin_assessments_binding.dart';
import '../modules/main_student_teacher/quality_admin/quality_admin_assessments_tab.dart';
import '../modules/main_student_teacher/quality_admin/quality_admin_followUp_tab.dart';
import '../modules/main_student_teacher/quality_admin/quality_admin_followup_binding.dart';
import '../modules/main_student_teacher/quality_admin/quality_admin_main_view.dart';
import '../modules/main_student_teacher/user_main_binding.dart';
import '../modules/notifications/notifications_view.dart';
import '../modules/onboarding/onboarding_binding.dart';
import '../modules/onboarding/onboarding_view.dart';
import '../modules/report_detail/report_detail_binding.dart';
import '../modules/report_detail/report_detail_view.dart';

import '../modules/splash/splash_binding.dart';
import '../modules/splash/splash_view.dart';

import 'app_routes.dart';

/// Route table for a 4-role app (admin / quality_admin / teacher /
/// student). Each role gets its own main-shell route via `UserMainBinding`
/// or a role-specific binding; a couple of routes (profile, teacher
/// reports) intentionally omit their own binding because the controller
/// is already registered with `fenix: true` by the shell binding above
/// them, and is shared across roles.
abstract class AppPages {
  static final pages = <GetPage>[
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: Routes.ONBOARDING,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: Routes.MAIN_ADMIN,
      page: () => const MainAdminView(),
      binding: MainBinding(),
    ),
    GetPage(
      name: Routes.MAIN_TEACHER,
      page: () => const TeacherMainView(),
      binding: UserMainBinding(),
    ),
    GetPage(
      name: Routes.MAIN_STUDENT,
      page: () => const StudentMainView(),
      binding: UserMainBinding(),
    ),
    GetPage(
      name: Routes.MAIN_QUALITY_ADMIN,
      page: () => const QualityAdminMainView(),
      binding: UserMainBinding(),
    ),

    GetPage(
      name: Routes.CHAT,
      page: () => const ChatView(),
      binding: ChatBinding(),
    ),
    GetPage(
      name: Routes.REPORT_DETAIL,
      page: () => const ReportDetailView(),
      binding: ReportDetailBinding(),
    ),
    GetPage(name: Routes.CALL, page: () => const CallScreen()),
    GetPage(name: Routes.INCOMING_CALL, page: () => const IncomingCallScreen()),
    GetPage(name: Routes.NOTIFICATIONS, page: () => const NotificationsView()),

    GetPage(
      name: Routes.TEACHER_ASSESSMENTS,
      page: () => const TeacherAssessmentsTab(),
      binding: TeacherAssessmentsBinding(),
    ),
    GetPage(
      name: Routes.TEACHER_FOLLOW_UP,
      page: () => const TeacherFollowupTab(),
      binding: TeacherFollowupBinding(),
    ),
    // بدون binding خاص — TeacherReportsController مسجّل أصلاً عبر
    // UserMainBinding (fenix: true) عند تحميل واجهة المعلمة الرئيسية.
    GetPage(
      name: Routes.TEACHER_REPORTS,
      page: () => const TeacherReportsTab(),
    ),
    // بدون binding خاص — ProfileController مسجّل أصلاً عبر UserMainBinding
    // (fenix: true)؛ هذا المسار يخدم كل الأدوار (معلمة/طالبة/إدارة).
    GetPage(
      name: Routes.PROFILE,
      page: () => const ProfileView(),
    ),

    GetPage(
      name: Routes.QUALITY_ADMIN_ASSESSMENTS,
      page: () => const QualityAdminAssessmentsTab(),
      binding: QualityAdminAssessmentsBinding(),
    ),
    GetPage(
      name: Routes.QUALITY_ADMIN_FOLLOW_UP,
      page: () => const QualityAdminFollowupTab(),
      binding: QualityAdminFollowupBinding(),
    ),
  ];
}
