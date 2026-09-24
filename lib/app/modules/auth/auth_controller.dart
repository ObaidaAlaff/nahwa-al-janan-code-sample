import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/storage_service.dart';
import '../../services/call_service.dart';
import '../../services/notification_service.dart';
import '../../routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_error.dart';

/// Login controller for a multi-tenant, multi-role app: username +
/// institution code map to a synthetic Supabase Auth email
/// (`username@institutioncode.local`), then the resolved `user_type`
/// drives which of four role-specific home routes to land on.
class AuthController extends GetxController {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final institutionCodeController = TextEditingController(text: 'aljinan');
  RxBool isLoading = false.obs;

  final _supabase = Supabase.instance.client;

  @override
  void onInit() {
    super.onInit();
    institutionCodeController.text = Get.find<StorageService>().institutionCode;
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final institutionCode = institutionCodeController.text.trim();

    if (username.isEmpty || password.isEmpty || institutionCode.isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال جميع البيانات');
      return;
    }

    isLoading.value = true;

    try {
      await _supabase.auth.signInWithPassword(
        email: '$username@$institutionCode.local',
        password: password,
      );

      final response = await _supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response != null) {
        final userType = response['user_type'] as String;
        final userId = response['id'].toString();
        final fullName =
            "${response['first_name']} ${response['fourth_name']}";
        final canViewFinancial = response['can_view_financial'] == true;
        final institutionId = response['institution_id'] as String?;
        final gender = response['gender'] as String? ?? 'female';

        await Get.find<StorageService>().setInstitutionCode(institutionCode);
        await Get.find<StorageService>().saveLogin(
          userId   : userId,
          userType : userType,
          userName : fullName,
          username : username,   // اسم المستخدم للدخول (مثل 2604000)
          canViewFinancial: canViewFinancial,
          institutionId: institutionId,
          gender: gender,
        );

        // ابدأ الاستماع للمكالمات الواردة بعد حفظ بيانات تسجيل الدخول
        Get.find<CallService>().refreshAndListen();

        // احفظ FCM token لاستقبال الإشعارات (موبايل فقط) — ثانوية بالنسبة
        // لتسجيل الدخول. إن فشلت تهيئة NotificationService في main() (مثلاً
        // فشل Firebase على جهاز ما) فهي غير مسجَّلة أصلاً في GetX، وكان
        // Get.find يرمي استثناء "not found" هنا يلتقطه catch(e) العام
        // أسفل الدالة ويُترجَم خطأً إلى "البيانات المطلوبة غير موجودة" —
        // رسالة مضلِّلة تماماً تجعل الدخول يبدو فاشلاً رغم نجاحه الفعلي.
        // الفحص هنا يمنع ذلك: غياب الخدمة لا يجوز أن يُسقِط تسجيل الدخول.
        if (!kIsWeb && Get.isRegistered<NotificationService>()) {
          await Get.find<NotificationService>().saveTokenForUser(userId);
        }

        if (userType == 'admin') {
          Get.offAllNamed(Routes.MAIN_ADMIN);
        } else if (userType == 'quality_admin') {
          Get.offAllNamed(Routes.MAIN_QUALITY_ADMIN);
        } else if (userType == 'teacher') {
          Get.offAllNamed(Routes.MAIN_TEACHER);
        } else {
          Get.offAllNamed(Routes.MAIN_STUDENT);
        }
      } else {
        await _supabase.auth.signOut();
        AppError.show(null,
            fallback: 'تعذّر العثور على بيانات المستخدم');
      }
    } on AuthException catch (_) {
      AppError.show(null,
          fallback: 'اسم المستخدم أو كلمة المرور أو رمز المؤسسة غير صحيح');
    } catch (e) {
      AppError.show(e);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    institutionCodeController.dispose();
    super.onClose();
  }
}
