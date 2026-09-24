import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/storage_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/pending_reports_service.dart';
import '../../core/utils/app_error.dart';

/// Daily memorization ("wird") report — the app's core feature. Handles
/// form state for the 8 daily portions, computes the expected next page
/// from memorization direction and level (ascending/descending, half-page,
/// multi-page, or juz-consolidation), validates against Thursday/Friday
/// exceptions, and saves to Supabase — falling back to an offline local
/// draft when there's no connection.
class ReportDetailController extends GetxController {
  final _supabase      = Supabase.instance.client;
  final _storage       = Get.find<StorageService>();
  final _connectivity  = Get.find<ConnectivityService>();
  final _pendingReports = Get.find<PendingReportsService>();

  // ── State ──
  final isSaving = false.obs;
  bool isReadOnly = false;
  String? reportId;
  // معرّف الطالبة الفعلي لهذا التقرير — عند التعديل من قبل معلمة/مشرف، هذا
  // يبقى معرّف صاحبة التقرير الأصلية، وليس معرّف من يفتح شاشة التعديل.
  String? _reportStudentId;
  String? get _targetStudentId =>
      reportId != null ? (_reportStudentId ?? _storage.userId) : _storage.userId;

  // ── استئناف مسودة محفوظة أوفلاين ──
  String? _draftLocalId;
  bool get isResumingDraft => _draftLocalId != null;

  // ── Observable fields ──
  final Map<String, RxBool>   yesNo            = {};
  final Map<String, TextEditingController> textControllers = {};
  final Map<String, RxString> sectionErrors    = {};
  final pledgeConfirmed = false.obs;
  final grade           = Rx<double?>(null);
  final reportDate      = Rx<DateTime>(DateTime.now());

  // ── تثبيت الجزء: وضع مبسّط بدون الأوراد الثمانية ──
  final isJuzFixed             = false.obs;
  final juzNumberController    = TextEditingController();
  final dailyAchievementController = TextEditingController();
  final juzNumberError         = ''.obs;
  final achievementError       = ''.obs;

  // ── النصف المحفوظ (للمستوى الأول فقط) ──
  final RxnInt memorizeHalf = RxnInt();

  // ── مستوى الطالبة (لتخصيص الواجهة) ──
  final RxnInt studentLevelRx  = RxnInt();
  final RxInt  pagesPerDayRx   = 1.obs;
  final RxBool isHalfPageRx    = false.obs;

  // ── الوجه والنصف المتوقعان بناءً على آخر تقرير ──
  int?   _studentLevel;
  int    _pagesPerDay     = 1;     // عدد الأوجه اليومي (من جدول levels)
  bool   _isHalfPageLevel = false; // نصف وجه (المستوى الأول)
  String _memoDirection   = 'descending';
  int?   _initialMemoPage;
  int?   _lastKnownMemoPage; // fallback: آخر صفحة محفوظة من التقارير أو التقرير الحالي
  bool   get isAscending => _memoDirection == 'ascending';
  int?   _expectedMemoPage;

  // reactive — تُستخدم في Obx بالواجهة
  final RxnInt    expectedHalfRx       = RxnInt();
  final RxnInt    expectedMemoPageRx   = RxnInt();
  final RxnInt    expectedMemoPageToRx = RxnInt();
  final RxBool    isFirstReportRx      = false.obs;
  final RxnString dateErrorRx          = RxnString(); // خطأ تكرار التاريخ

  int? get expectedMemoPage   => _expectedMemoPage;
  int? get expectedHalf       => expectedHalfRx.value;
  bool get isFirstReport      => isFirstReportRx.value;

  // ── يوم الأسبوع الإسلامي بناءً على تاريخ التقرير ──
  int _islamicWeekday() {
    final w = reportDate.value.weekday; // Mon=1..Sun=7
    return ((w - 6 + 7) % 7) + 1;
  }

  bool get isThursday => _islamicWeekday() == 6;
  bool get isFriday   => _islamicWeekday() == 7;

  String _weekdayArabicName() {
    const names = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
    return names[_islamicWeekday() - 1];
  }

  String get reviewDayName => _weekdayArabicName();

  /// نطاق المراجعة الأسبوعية للمحفوظ السابق (للطالبات ذوات initial_memo_page)
  Map<String, dynamic>? get todayReviewRange {
    // الأولوية: initial_memo_page → آخر صفحة من التقارير
    final initPage = _initialMemoPage ?? _lastKnownMemoPage;
    if (initPage == null || initPage <= 0) return null;

    int fromP, toP, juzFrom, juzTo;

    if (isAscending) {
      // تصاعدي: محفوظ = [1, initPage]
      fromP   = 1;
      toP     = initPage;
      juzFrom = 1;
      juzTo   = _juzOf(initPage);
    } else {
      // تنازلي: محفوظ = من أول جزء مكتمل وصاعداً حتى آخر الجدول
      final maxJuz        = _juzTable.length;
      final juz           = _juzOf(initPage);
      final complete      = initPage >= _endOfJuz(juz);
      final firstComplete = complete ? juz : juz + 1;
      if (firstComplete > maxJuz) return null;
      fromP   = _startOfJuz(firstComplete);
      toP     = _endOfJuz(maxJuz);
      juzFrom = firstComplete;
      juzTo   = maxJuz;
    }

    final total  = toP - fromP + 1;
    if (total <= 0) return null;

    final perDay  = (total / 6).ceil();
    final dayIdx  = _islamicWeekday();
    final dayName = reviewDayName;

    if (dayIdx == 7) {
      return {
        'fromPage': fromP, 'toPage': toP,
        'totalPages': total, 'perDay': perDay,
        'dayName': dayName, 'rangeText': null, 'isFriday': true,
      };
    }

    final dayFrom = fromP + (dayIdx - 1) * perDay;
    if (dayFrom > toP) {
      return {
        'fromPage': fromP, 'toPage': toP,
        'totalPages': total, 'perDay': perDay,
        'dayName': dayName, 'rangeText': null,
      };
    }
    final dayTo = (dayFrom + perDay - 1).clamp(fromP, toP);
    return {
      'fromPage': fromP, 'toPage': toP,
      'totalPages': total, 'perDay': perDay,
      'dayName': dayName,
      'rangeText': 'من صفحة $dayFrom إلى صفحة $dayTo',
    };
  }

  // ── Keys ──
  static const boolKeys = [
    'listening_done',
    'tafsir_done',
    'memorize_done',
    'near_review_done',
    'far_review_done',
    'prayer_done',
    'similar_done',
    'tadabur_done',
  ];

  static const textKeys = [
    'listen_page',
    'listen_page_to',
    'tafsir_page',
    'tafsir_page_to',
    'memorize_page',
    'memorize_page_to',
    'near_review_from',
    'near_review_to',
    'near_review_from_2', // نطاق إضافي
    'near_review_to_2',
    'far_review_pages',
    'far_review_from',
    'far_review_to',
    'far_review_from_2',  // نطاق إضافي
    'far_review_to_2',
    'prayer_page',
    'prayer_page_2',      // نطاق إضافي
    'similar_page',
    'similar_page_to',
    'tadabur_page',
    'tadabur_page_to',
  ];

  // ── تحكم إظهار النطاق الإضافي (reactive) ──
  final showNearRange2   = false.obs;
  final showFarRange2    = false.obs;
  final showPrayerRange2 = false.obs;

  @override
  void onInit() {
    super.onInit();

    for (final key in boolKeys) {
      yesNo[key]         = false.obs;
      sectionErrors[key] = ''.obs;
    }
    for (final key in textKeys) {
      textControllers[key] = TextEditingController();
    }

    final args     = Get.arguments as Map<String, dynamic>? ?? {};
    isReadOnly     = args['readOnly'] as bool? ?? false;
    final report   = args['report']   as Map<String, dynamic>? ?? {};
    reportId       = report['id']?.toString();
    // استئناف مسودة محفوظة أوفلاين: نفس شكل بيانات التقرير العادي (بلا id)،
    // فتُملأ الشاشة تلقائياً عبر _loadFromReport كما لو كانت تعديلاً — لكن
    // reportId يبقى null فيُعامَل كتقرير جديد عند الإرسال الفعلي (INSERT).
    _draftLocalId  = args['draftLocalId']?.toString();
    _loadFromReport(report);

    _fetchStudentLevel().then((_) {
      if (!isReadOnly && reportId == null) {
        _loadLastReport();
      }
    });
  }

  void _loadFromReport(Map<String, dynamic> report) {
    _reportStudentId = report['student_id']?.toString();
    for (final key in boolKeys) {
      yesNo[key]!.value = report[key] as bool? ?? false;
    }
    for (final key in textKeys) {
      final val = report[key];
      textControllers[key]!.text = val != null ? val.toString() : '';
    }
    pledgeConfirmed.value = report['pledge_confirmed'] as bool? ?? false;
    grade.value           = (report['grade'] as num?)?.toDouble();
    if (report['report_date'] != null) {
      try {
        reportDate.value = DateTime.parse(report['report_date'].toString());
      } catch (_) {}
    }
    // تثبيت الجزء
    isJuzFixed.value = report['is_juz_fixed'] as bool? ?? false;
    if (isJuzFixed.value) {
      juzNumberController.text = report['juz_number']?.toString() ?? '';
      dailyAchievementController.text =
          report['daily_achievement']?.toString() ?? '';
    }
    // تحميل النصف عند تعديل أو عرض تقرير موجود
    final half = _asInt(report['memorize_half']);
    if (half != null) memorizeHalf.value = half;
    // حفظ صفحة الحفظ من التقرير الحالي كمرجع للمراجعة البعيدة (وضع التعديل)
    final memoRef = _asInt(report['memorize_page_to']) ?? _asInt(report['memorize_page']);
    if (memoRef != null && memoRef > 0) _lastKnownMemoPage = memoRef;
    // إظهار النطاق الإضافي تلقائياً إذا كانت له بيانات
    if (_asInt(report['near_review_from_2']) != null) showNearRange2.value   = true;
    if (_asInt(report['far_review_from_2'])  != null) showFarRange2.value    = true;
    if (_asInt(report['prayer_page_2'])      != null) showPrayerRange2.value = true;
  }

  // ── التحقق من عدم وجود تقرير بنفس التاريخ، وعدم الرجوع لتاريخ سابق ──
  Future<void> checkDateAvailability(DateTime date) async {
    if (isReadOnly) return;
    // أوفلاين: لا فائدة من محاولة شبكة محكوم عليها بالفشل/التأخر — يُترَك
    // الفحص الفعلي لخطوة الحفظ (saveReport)، وهي تتعامل مع الأوفلاين
    // بحفظ مسودة بدل استدعاء هذه الدالة إطلاقاً.
    if (_connectivity.isOffline.value) {
      dateErrorRx.value = null;
      return;
    }
    final studentId = _targetStudentId;
    if (studentId == null) return;
    final dateStr = date.toIso8601String().substring(0, 10);
    try {
      // 1. نفس اليوم مسجَّل مسبقاً
      var dupQuery = _supabase
          .from('daily_reports')
          .select('id')
          .eq('student_id', studentId)
          .eq('report_date', dateStr);
      if (reportId != null) dupQuery = dupQuery.neq('id', reportId!);
      final existing = await dupQuery.maybeSingle();
      if (existing != null) {
        dateErrorRx.value =
            'يوجد تقرير مسجّل بتاريخ $dateStr — لا يمكن إضافة تقرير ثانٍ لنفس اليوم';
        return;
      }

      // 2. تاريخ أقدم من آخر تقرير مسجَّل — ممنوع التراجع للخلف
      var latestFilter = _supabase
          .from('daily_reports')
          .select('report_date')
          .eq('student_id', studentId);
      if (reportId != null) latestFilter = latestFilter.neq('id', reportId!);
      final latest = await latestFilter
          .order('report_date', ascending: false)
          .limit(1)
          .maybeSingle();
      final latestDateStr = latest?['report_date']?.toString();
      if (latestDateStr != null && dateStr.compareTo(latestDateStr) < 0) {
        dateErrorRx.value =
            'لا يمكن إضافة تقرير بتاريخ سابق لآخر تقرير مسجّل ($latestDateStr)';
        return;
      }

      dateErrorRx.value = null;
    } catch (e) {
      dateErrorRx.value = null;
    }
  }

  // ── جلب مستوى الطالبة واتجاه الحفظ ──
  Future<void> _fetchStudentLevel() async {
    try {
      final userId = _storage.userId;
      if (userId == null) return;
      final data = await _supabase
          .from('users')
          .select('memo_direction, initial_memo_page, levels(level_number, pages_count, is_half_page)')
          .eq('id', userId)
          .maybeSingle();
      final lvl            = data?['levels'] as Map<String, dynamic>?;
      _studentLevel        = _asInt(lvl?['level_number']);
      _pagesPerDay         = _asInt(lvl?['pages_count']) ?? 1;
      _isHalfPageLevel     = lvl?['is_half_page'] as bool? ?? false;
      studentLevelRx.value = _studentLevel;
      pagesPerDayRx.value  = _pagesPerDay;
      isHalfPageRx.value   = _isHalfPageLevel;
      _memoDirection       = data?['memo_direction']?.toString() ?? 'descending';
      _initialMemoPage     = _asInt(data?['initial_memo_page']);
    } catch (e) {
      debugPrint('Error fetching student level: $e');
    }
  }

  // ── تحميل آخر تقرير لحساب الوجه والنصف المتوقعين ──
  Future<void> _loadLastReport() async {
    try {
      final userId = _storage.userId;
      if (userId == null) return;
      final data = await _supabase
          .from('daily_reports')
          .select('memorize_page, memorize_page_to, memorize_half')
          .eq('student_id', userId)
          .not('memorize_page', 'is', null)
          .order('report_date', ascending: false)
          .limit(1)
          .maybeSingle();

      // إذا لا توجد تقارير → نتحقق من الحفظ السابق
      final refPage   = data != null ? _asInt(data['memorize_page'])    : _initialMemoPage;
      final refPageTo = data != null ? (_asInt(data['memorize_page_to']) ?? refPage) : _initialMemoPage;
      final refHalf   = data != null ? _asInt(data['memorize_half']) : null;

      // تحديث آخر صفحة محفوظة كـ fallback لحساب المراجعة البعيدة
      final knownPage = refPageTo ?? refPage;
      if (knownPage != null && knownPage > 0) {
        _lastKnownMemoPage = knownPage;
        studentLevelRx.value = _studentLevel; // يُعيد تشغيل Obx في البانر
      }

      if (data == null && _initialMemoPage == null) {
        // أول تقرير حقيقي — لا مرجع
        isFirstReportRx.value     = true;
        _expectedMemoPage         = null;
        expectedMemoPageRx.value  = null;
        expectedMemoPageToRx.value = null;
        expectedHalfRx.value      = null;
      } else {
        isFirstReportRx.value = false;
        final lastPage   = refPage;
        final lastPageTo = refPageTo;
        final lastHalf   = refHalf;

        if (_isHalfPageLevel) {
          // نصف وجه يومياً
          if (lastHalf == null || lastHalf == 2) {
            _expectedMemoPage    = _nextPage(lastPage);
            expectedHalfRx.value = 1;
          } else {
            _expectedMemoPage    = lastPage;
            expectedHalfRx.value = 2;
          }
          expectedMemoPageRx.value   = _expectedMemoPage;
          expectedMemoPageToRx.value = null;
        } else if (_pagesPerDay == 1) {
          // وجه واحد يومياً
          _expectedMemoPage          = _nextPage(lastPageTo);
          expectedMemoPageRx.value   = _expectedMemoPage;
          expectedMemoPageToRx.value = null;
          expectedHalfRx.value       = null;
        } else if (_studentLevel == 4) {
          // مستوى التثبيت — تسلسل خطّي 1→604 دوري (لا يراعي اتجاه الحفظ)
          _expectedMemoPage          = _nextConsolidationPage(lastPageTo);
          expectedMemoPageToRx.value =
              (_expectedMemoPage! + _pagesPerDay - 1).clamp(1, 604);
          expectedMemoPageRx.value   = _expectedMemoPage;
          expectedHalfRx.value       = null;
        } else {
          // أوجه متعددة (حفظ) — مراعٍ لاتجاه الحفظ (تصاعدي/تنازلي)
          _expectedMemoPage = _nextPage(lastPageTo);
          var toPage = _expectedMemoPage!;
          for (int i = 1; i < _pagesPerDay; i++) toPage = _nextPage(toPage);
          expectedMemoPageToRx.value = toPage;
          expectedMemoPageRx.value   = _expectedMemoPage;
          expectedHalfRx.value       = null;
        }
      }
    } catch (e) {
      debugPrint('Error loading last report: $e');
    }
  }

  @override
  void onClose() {
    for (final c in textControllers.values) c.dispose();
    juzNumberController.dispose();
    dailyAchievementController.dispose();
    super.onClose();
  }

  // ── Collect all form data ──
  Map<String, dynamic> _collectData() {
    final data = <String, dynamic>{};
    data['pledge_confirmed'] = pledgeConfirmed.value;
    data['student_id']       = _targetStudentId;
    data['report_date']      =
        reportDate.value.toIso8601String().substring(0, 10);

    if (isJuzFixed.value) {
      // وضع تثبيت الجزء: رقم الجزء + الإنجاز اليومي فقط، بدون أوراد
      data['is_juz_fixed']      = true;
      data['juz_number']        = int.tryParse(juzNumberController.text.trim());
      data['daily_achievement'] = dailyAchievementController.text.trim();
      for (final key in boolKeys) {
        data[key] = false;
      }
      for (final key in textKeys) {
        data[key] = null;
      }
      data['memorize_half'] = null;
      return data;
    }

    data['is_juz_fixed']      = false;
    data['juz_number']        = null;
    data['daily_achievement'] = null;
    for (final key in boolKeys) {
      data[key] = yesNo[key]!.value;
    }
    for (final key in textKeys) {
      final raw = textControllers[key]!.text.trim();
      data[key] = raw.isEmpty ? null : int.tryParse(raw) ?? raw;
    }
    // النصف (لمستوى نصف الوجه فقط)
    data['memorize_half'] = _isHalfPageLevel ? memorizeHalf.value : null;
    return data;
  }

  // ══════════════ التحقق من صحة البيانات ══════════════

  bool _validateForm() {
    // ── وضع تثبيت الجزء: تحقق مبسّط بدون أوراد ──
    if (isJuzFixed.value) {
      juzNumberError.value   = '';
      achievementError.value = '';
      bool valid = true;

      final juzText = juzNumberController.text.trim();
      final juz     = int.tryParse(juzText);
      if (juzText.isEmpty || juz == null || juz < 1 || juz > 30) {
        juzNumberError.value = 'يرجى إدخال رقم جزء صحيح (من 1 إلى 30)';
        valid = false;
      }

      if (dailyAchievementController.text.trim().isEmpty) {
        achievementError.value = 'يرجى كتابة الإنجاز اليومي';
        valid = false;
      }

      return valid;
    }

    // مسح أخطاء سابقة
    for (final key in boolKeys) {
      sectionErrors[key]!.value = '';
    }
    bool valid = true;

    final friday   = isFriday;
    final thursday = isThursday;

    // يوم الجمعة — راحة: لا أوراد مطلوبة
    if (friday) return true;

    final List<String> requiredBoolKeys;
    if (thursday) {
      requiredBoolKeys = ['near_review_done', 'far_review_done', 'prayer_done'];
    } else {
      requiredBoolKeys = boolKeys;
    }

    // 1. يجب أن تكون الأوراد المطلوبة "تم"
    for (final key in requiredBoolKeys) {
      if (!yesNo[key]!.value) {
        sectionErrors[key]!.value = 'يجب تأكيد إتمام هذا الورد قبل الإرسال';
        valid = false;
      }
    }

    // 2-3-4: فحص الحفظ (لا ينطبق ليوم الخميس ولا الجمعة)
    if (!thursday) {
      // 2. فحص وجه البداية المتوقع
      final memoText = textControllers['memorize_page']!.text.trim();
      final memoPage = int.tryParse(memoText);

      if (memoText.isEmpty || memoPage == null) {
        sectionErrors['memorize_done']!.value =
            'يرجى إدخال رقم الوجه المحفوظ';
        valid = false;
      } else if (!isFirstReport &&
          _expectedMemoPage != null &&
          memoPage != _expectedMemoPage) {
        sectionErrors['memorize_done']!.value =
            'الوجه المتوقع هو $_expectedMemoPage — لا يجوز تخطي الصفحات';
        valid = false;
      }

      if (!_isHalfPageLevel && _pagesPerDay > 1) {
        // 3. فحص وجه النهاية لمستويات الأوجه المتعددة
        final toText = textControllers['memorize_page_to']!.text.trim();
        final toPage = int.tryParse(toText);
        if (toText.isEmpty || toPage == null) {
          final prev = sectionErrors['memorize_done']!.value;
          sectionErrors['memorize_done']!.value = prev.isEmpty
              ? 'يرجى إدخال رقم نهاية الوجه المحفوظ'
              : '$prev\nيرجى إدخال رقم نهاية الوجه المحفوظ';
          valid = false;
        } else if (memoPage != null && toPage < memoPage) {
          final prev = sectionErrors['memorize_done']!.value;
          sectionErrors['memorize_done']!.value = prev.isEmpty
              ? 'رقم النهاية يجب أن يكون أكبر من رقم البداية'
              : '$prev\nرقم النهاية يجب أن يكون أكبر من رقم البداية';
          valid = false;
        }
      } else {
        // 3. فحص النصف لمستوى نصف الوجه
        if (_isHalfPageLevel) {
          if (memorizeHalf.value == null) {
            final prev = sectionErrors['memorize_done']!.value;
            sectionErrors['memorize_done']!.value = prev.isEmpty
                ? 'يرجى تحديد النصف (الأول أو الثاني)'
                : '$prev\nيرجى تحديد النصف (الأول أو الثاني)';
            valid = false;
          } else if (!isFirstReport &&
              expectedHalf != null &&
              memorizeHalf.value != expectedHalf) {
            final halfLabel = expectedHalf == 1 ? 'الأول' : 'الثاني';
            final prev = sectionErrors['memorize_done']!.value;
            sectionErrors['memorize_done']!.value = prev.isEmpty
                ? 'النصف المتوقع هو $halfLabel — لا يجوز تخطيه'
                : '$prev\nالنصف المتوقع هو $halfLabel — لا يجوز تخطيه';
            valid = false;
          }
        }

        // 4. مطابقة الأوراد مع وجه الحفظ (للمستويين 1 و 2 فقط)
        final memoPage2 = int.tryParse(
            textControllers['memorize_page']!.text.trim());
        if (memoPage2 != null) {
          _checkPageMatch('listen_page',  'listening_done', memoPage2);
          _checkPageMatch('tafsir_page',  'tafsir_done',    memoPage2);
          _checkPageMatch('similar_page', 'similar_done',   memoPage2);
          _checkPageMatch('tadabur_page', 'tadabur_done',   memoPage2);
          for (final k in ['listening_done', 'tafsir_done',
                            'similar_done',  'tadabur_done']) {
            if (sectionErrors[k]!.value.isNotEmpty) valid = false;
          }
        }
      }
    }

    // 5. المراجعة القريبة: من <= إلى (النطاقين)
    final nrFrom = int.tryParse(textControllers['near_review_from']!.text.trim());
    final nrTo   = int.tryParse(textControllers['near_review_to']!.text.trim());
    if (nrFrom != null && nrTo != null && nrFrom > nrTo) {
      sectionErrors['near_review_done']!.value =
          'رقم البداية يجب أن يكون أصغر من رقم النهاية';
      valid = false;
    }
    if (showNearRange2.value) {
      final f2 = int.tryParse(textControllers['near_review_from_2']!.text.trim());
      final t2 = int.tryParse(textControllers['near_review_to_2']!.text.trim());
      if (f2 != null && t2 != null && f2 > t2) {
        sectionErrors['near_review_done']!.value =
            'النطاق الإضافي: رقم البداية يجب أن يكون أصغر من رقم النهاية';
        valid = false;
      }
    }

    // 6. المراجعة البعيدة: من <= إلى (النطاقين)
    final frFrom = int.tryParse(textControllers['far_review_from']!.text.trim());
    final frTo   = int.tryParse(textControllers['far_review_to']!.text.trim());
    if (frFrom != null && frTo != null && frFrom > frTo) {
      sectionErrors['far_review_done']!.value =
          'رقم البداية يجب أن يكون أصغر من رقم النهاية';
      valid = false;
    }
    if (showFarRange2.value) {
      final f2 = int.tryParse(textControllers['far_review_from_2']!.text.trim());
      final t2 = int.tryParse(textControllers['far_review_to_2']!.text.trim());
      if (f2 != null && t2 != null && f2 > t2) {
        sectionErrors['far_review_done']!.value =
            'النطاق الإضافي: رقم البداية يجب أن يكون أصغر من رقم النهاية';
        valid = false;
      }
    }

    // 7. فحص نطاقات الأوراد الأخرى لمستويات الأوجه المتعددة
    if (!thursday && !friday && !_isHalfPageLevel && _pagesPerDay > 1) {
      void _checkRange(String fromKey, String toKey, String sectionKey) {
        final f = int.tryParse(textControllers[fromKey]!.text.trim());
        final t = int.tryParse(textControllers[toKey]!.text.trim());
        if (f != null && t != null && t < f) {
          if (sectionErrors[sectionKey]!.value.isEmpty) {
            sectionErrors[sectionKey]!.value =
                'رقم النهاية يجب أن يكون أكبر من رقم البداية';
          }
          valid = false;
        }
      }
      _checkRange('listen_page',  'listen_page_to',  'listening_done');
      _checkRange('tafsir_page',  'tafsir_page_to',  'tafsir_done');
      _checkRange('similar_page', 'similar_page_to', 'similar_done');
      _checkRange('tadabur_page', 'tadabur_page_to', 'tadabur_done');
    }

    // ── 8. فحص الحقول الإلزامية: كل ورد يجب أن يحتوي رقم الصفحة ──
    void requireField(String fk, String sk, String msg) {
      if (textControllers[fk]!.text.trim().isEmpty) {
        final prev = sectionErrors[sk]!.value;
        sectionErrors[sk]!.value = prev.isEmpty ? msg : '$prev\n$msg';
        valid = false;
      }
    }

    // المراجعة القريبة — مطلوبة في جميع الأيام (عدا الجمعة)
    requireField('near_review_from', 'near_review_done', 'يرجى إدخال صفحة البداية');
    requireField('near_review_to',   'near_review_done', 'يرجى إدخال صفحة النهاية');
    if (showNearRange2.value) {
      requireField('near_review_from_2', 'near_review_done', 'النطاق الإضافي: يرجى إدخال صفحة البداية');
      requireField('near_review_to_2',   'near_review_done', 'النطاق الإضافي: يرجى إدخال صفحة النهاية');
    }

    // المراجعة البعيدة
    requireField('far_review_pages', 'far_review_done', 'يرجى إدخال عدد الصفحات المراجَعة');
    requireField('far_review_from',  'far_review_done', 'يرجى إدخال صفحة البداية');
    requireField('far_review_to',    'far_review_done', 'يرجى إدخال صفحة النهاية');
    if (showFarRange2.value) {
      requireField('far_review_from_2', 'far_review_done', 'النطاق الإضافي: يرجى إدخال صفحة البداية');
      requireField('far_review_to_2',   'far_review_done', 'النطاق الإضافي: يرجى إدخال صفحة النهاية');
    }

    // الصلاة بالمحفوظ
    requireField('prayer_page', 'prayer_done', 'يرجى إدخال رقم الصفحة');
    if (showPrayerRange2.value) {
      requireField('prayer_page_2', 'prayer_done', 'النطاق الإضافي: يرجى إدخال رقم الصفحة');
    }

    // الأوراد المتبقية — لا تُطلب يوم الخميس
    if (!thursday) {
      // الاستماع
      requireField('listen_page', 'listening_done', 'يرجى إدخال رقم الوجه المستمَع');
      if (!_isHalfPageLevel && _pagesPerDay > 1) {
        requireField('listen_page_to', 'listening_done', 'يرجى إدخال رقم نهاية الوجه المستمَع');
      }

      // التفسير
      requireField('tafsir_page', 'tafsir_done', 'يرجى إدخال رقم الوجه المُفسَّر');
      if (!_isHalfPageLevel && _pagesPerDay > 1) {
        requireField('tafsir_page_to', 'tafsir_done', 'يرجى إدخال رقم نهاية الوجه المُفسَّر');
      }

      // المتشابهات
      requireField('similar_page', 'similar_done', 'يرجى إدخال رقم الوجه');
      if (!_isHalfPageLevel && _pagesPerDay > 1) {
        requireField('similar_page_to', 'similar_done', 'يرجى إدخال رقم نهاية الوجه');
      }

      // التدبر
      requireField('tadabur_page', 'tadabur_done', 'يرجى إدخال رقم الوجه');
      if (!_isHalfPageLevel && _pagesPerDay > 1) {
        requireField('tadabur_page_to', 'tadabur_done', 'يرجى إدخال رقم نهاية الوجه');
      }
    }

    return valid;
  }

  void _checkPageMatch(String fieldKey, String sectionKey, int expected) {
    final text = textControllers[fieldKey]!.text.trim();
    if (text.isEmpty) return;
    final page = int.tryParse(text);
    if (page != null && page != expected &&
        sectionErrors[sectionKey]!.value.isEmpty) {
      sectionErrors[sectionKey]!.value =
          'الوجه يجب أن يوافق وجه الحفظ ($expected)';
    }
  }

  void clearSectionError(String key) =>
      sectionErrors[key]?.value = '';

  void clearRange2(String section) {
    switch (section) {
      case 'near':
        textControllers['near_review_from_2']!.clear();
        textControllers['near_review_to_2']!.clear();
        showNearRange2.value = false;
      case 'far':
        textControllers['far_review_from_2']!.clear();
        textControllers['far_review_to_2']!.clear();
        showFarRange2.value = false;
      case 'prayer':
        textControllers['prayer_page_2']!.clear();
        showPrayerRange2.value = false;
    }
  }

  // ── Save (insert or update) ──
  Future<void> saveReport() async {
    // حاجز إعادة دخول فوري — يمنع ضغطة ثانية أثناء تنفيذ ضغطة سابقة (مهم
    // خصوصاً مع نت بطيء، راجع تعليق ضبط isSaving أدناه).
    if (isSaving.value) return;

    if (!pledgeConfirmed.value) {
      Get.snackbar(
        'تنبيه',
        'يرجى الموافقة على الإقرار في أسفل التقرير أولاً',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // التحقق المحلي (حقول إلزامية، تسلسل الصفحات...) يعمل دائماً بلا اتصال.
    if (!_validateForm()) {
      Get.snackbar(
        'يوجد أخطاء في التقرير',
        'يرجى مراجعة الحقول المحددة باللون الأحمر',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    // أوفلاين وتقرير جديد: لا يمكن التحقق من تكرار التاريخ أو الرجوع لتاريخ
    // سابق دون اتصال بالخادم — يُحفظ كمسودة، ويُطلب تأكيده وإرساله فعلياً
    // (بتحقق خادم كامل) عند توفر الاتصال.
    // ملاحظة: هذا مقصور على التقرير الجديد فقط (reportId == null) — مسودة
    // بيانات _collectData() لا تحمل id، فلو استُخدمت لتعديل تقرير موجود
    // (معلمة/مشرف يعدّلان تقرير طالبة) لأنشأت صفاً مكرراً بدل تحديث الأصلي
    // عند التأكيد لاحقاً. التعديل أثناء الأوفلاين يبقى كما كان: يفشل
    // بخطأ واضح فوراً بدل حفظ مسودة قد تُنشئ سجلاً مكرراً.
    // من هنا فصاعداً استدعاءات شبكة فعلية (قد تبطئ مع نت ضعيف) — نضبط
    // isSaving قبلها مباشرة لا بعدها، حتى يظهر مؤشر التحميل ويُعطَّل الزر
    // طوال هذه المدة، بدل أن يبقى الزر مفعَّلاً بصمت فيضغطه المستخدم مجدداً
    // ويُرسِل التقرير مرتين (كان هذا هو السبب الفعلي للإرسال المكرر).
    isSaving.value = true;
    try {
      if (_connectivity.isOffline.value && reportId == null) {
        await _saveAsDraft();
        return;
      }

      // حاجز أخير: تأكد من عدم تكرار التاريخ ومن عدم الرجوع لتاريخ سابق
      await checkDateAvailability(reportDate.value);
      if (dateErrorRx.value != null) {
        Get.snackbar(
          'تنبيه',
          dateErrorRx.value!,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      final data = _collectData();

      if (reportId != null) {
        await _supabase
            .from('daily_reports')
            .update(data)
            .eq('id', reportId!);
      } else {
        await _supabase.from('daily_reports').insert(data);
        // كانت هذه مسودة مستأنفة ونجح إرسالها الفعلي الآن — احذفها من
        // مخزن المسودات حتى لا تظهر كمعلَّقة بعد إرسالها بنجاح.
        if (_draftLocalId != null) await _pendingReports.remove(_draftLocalId!);
      }

      Get.back(result: true);
      Get.snackbar(
        'تم',
        reportId != null ? 'تم تحديث التقرير' : 'تم إرسال التقرير بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
      );
    } catch (e) {
      AppError.show(e, fallback: 'تعذّر حفظ التقرير، يرجى المحاولة مجدداً');
    } finally {
      isSaving.value = false;
    }
  }

  // ── حفظ التقرير كمسودة محلية عند الأوفلاين ──
  Future<void> _saveAsDraft() async {
    final studentId = _targetStudentId;
    if (studentId == null) return;

    // فحص محلي بحت: لا مسودتين بنفس التاريخ (لا يمكن فحص الخادم أوفلاين).
    final dateStr = reportDate.value.toIso8601String().substring(0, 10);
    final hasDuplicateDraft = _pendingReports
        .forStudent(studentId)
        .where((r) => r['local_id'] != _draftLocalId)
        .any((r) => (r['data'] as Map?)?['report_date']?.toString() == dateStr);
    if (hasDuplicateDraft) {
      Get.snackbar(
        'تنبيه',
        'لديكِ بالفعل مسودة محفوظة بتاريخ $dateStr',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    isSaving.value = true;
    try {
      final data = _collectData();
      _draftLocalId = await _pendingReports.save(
        localId  : _draftLocalId,
        studentId: studentId,
        data     : data,
      );
      Get.back(result: 'draft');
      Get.snackbar(
        'تم الحفظ كمسودة',
        'التقرير محفوظ على جهازكِ — سيُطلب تأكيده وإرساله فعلياً عند توفر الاتصال بالإنترنت',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isSaving.value = false;
    }
  }

  /// تجاهل مسودة مستأنَفة بلا إرسال — تُستدعى من زر التجاهل في الشاشة.
  Future<void> discardDraft() async {
    if (_draftLocalId == null) return;
    await _pendingReports.remove(_draftLocalId!);
    Get.back(result: 'discarded');
  }

  // ══════════════ جدول صفحات الأجزاء — تصاعدي ══════════════
  static const List<List<int>> _juzPagesAsc = [
    [1,   21],  // جزء  1
    [22,  41],  // جزء  2
    [42,  61],  // جزء  3
    [62,  81],  // جزء  4
    [82,  101], // جزء  5
    [102, 121], // جزء  6
    [122, 141], // جزء  7
    [142, 161], // جزء  8
    [162, 181], // جزء  9
    [182, 201], // جزء 10
    [202, 221], // جزء 11
    [222, 241], // جزء 12
    [242, 261], // جزء 13
    [262, 281], // جزء 14
    [282, 301], // جزء 15
    [302, 321], // جزء 16
    [322, 341], // جزء 17
    [342, 361], // جزء 18
    [362, 381], // جزء 19
    [382, 401], // جزء 20
    [402, 421], // جزء 21
    [422, 441], // جزء 22
    [442, 461], // جزء 23
    [462, 481], // جزء 24
    [482, 501], // جزء 25
    [502, 521], // جزء 26
    [522, 541], // جزء 27
    [542, 561], // جزء 28
    [562, 581], // جزء 29
    [582, 604], // جزء 30
  ];

  // ══════════════ جدول صفحات الأجزاء — تنازلي ══════════════
  // ⚠️ يرجى تعديل الأرقام حسب الترقيم الصحيح
  static const List<List<int>> _juzPagesDesc = [
    [1,   49],  // جزء  1
    [50,  76],  // جزء  3
    [77,  105],  // جزء  4
    [106,  127], // جزء  5
    [128, 150], // جزء  6
    [151, 176], // جزء  7
    [177, 186], // جزء  8
    [187, 207], // جزء  9
    [208, 221], // جزء 10
    [222, 235], // جزء 12
    [236, 261], // جزء 13
    [262, 281], // جزء 14
    [282, 304], // جزء 15
    [305, 321], // جزء 16
    [322, 341], // جزء 17
    [342, 359], // جزء 18
    [360, 376], // جزء 19
    [377, 396], // جزء 20
    [397, 417], // جزء 21
    [418, 439], // جزء 22
    [440, 457], // جزء 23
    [458, 482], // جزء 24
    [483, 502], // جزء 25
    [503, 520], // جزء 26
    [521, 541], // جزء 27
    [542, 561], // جزء 28
    [562, 581], // جزء 29
    [582, 604], // جزء 30
  ];


  List<List<int>> get _juzTable => isAscending ? _juzPagesAsc : _juzPagesDesc;

  int _startOfJuz(int juz) => _juzTable[juz.clamp(1, 30) - 1][0];
  int _endOfJuz(int juz)   => _juzTable[juz.clamp(1, 30) - 1][1];

  int _juzOf(int page) {
    final t = _juzTable;
    for (int i = 0; i < t.length; i++) {
      if (page <= t[i][1]) return i + 1;
    }
    return 30;
  }

  /// تنازلي بالأجزاء: داخل الجزء يتقدم، عند نهايته يقفز لبداية الجزء السابق
  int _nextMemoPage(int? lastPage) {
    if (lastPage == null || lastPage <= 0) return 582;
    final juz = _juzOf(lastPage);
    if (lastPage < _endOfJuz(juz)) return lastPage + 1;
    if (juz > 1) return _startOfJuz(juz - 1);
    return 1;
  }

  int _nextMemoPageAsc(int? lastPage) {
    if (lastPage == null || lastPage <= 0) return 1;
    if (lastPage >= 604) return 1;
    return lastPage + 1;
  }

  int _nextPage(int? lastPage) =>
      isAscending ? _nextMemoPageAsc(lastPage) : _nextMemoPage(lastPage);

  int _nextConsolidationPage(int? lastPage) {
    if (lastPage == null || lastPage <= 0) return 1;
    if (lastPage >= 604) return 1;
    return lastPage + 1;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
