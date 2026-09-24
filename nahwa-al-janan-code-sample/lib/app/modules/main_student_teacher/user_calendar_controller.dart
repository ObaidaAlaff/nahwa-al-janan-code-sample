import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/storage_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_cache_service.dart';

/// Monthly progress-calendar controller: which days a student submitted a
/// daily report, plus that day's full report on tap. Offline-first — a
/// rolling 30-day cache backs both the month grid and day lookups so the
/// calendar stays usable (read-only) with no connection.
class UserCalendarController extends GetxController {
  final _supabase     = Supabase.instance.client;
  final _storage      = Get.find<StorageService>();
  final _connectivity = Get.find<ConnectivityService>();
  final _offlineCache = Get.find<OfflineCacheService>();

  // ── حالة الأوفلاين (وضع القراءة فقط، مقصورة على آخر 30 يوم) ──
  RxBool get isOffline => _connectivity.isOffline;
  final Rx<DateTime?> lastCachedAt = Rx<DateTime?>(null);

  // ── الشهر المعروض ──
  final RxInt displayYear  = DateTime.now().year.obs;
  final RxInt displayMonth = DateTime.now().month.obs;

  // ── اليوم المختار ──
  final Rxn<int> selectedDay = Rxn<int>();

  // ── أيام الشهر التي يوجد بها تقرير ──
  final Rx<Set<int>> monthReportDays = Rx<Set<int>>(<int>{});

  // ── تقرير اليوم المختار ──
  final Rxn<Map<String, dynamic>> selectedReport = Rxn();

  // ── حالات التحميل ──
  final isLoadingMonth  = false.obs;
  final isLoadingReport = false.obs;

  String? get userId => _storage.userId;

  /// هل يمكن الانتقال للشهر التالي (لا يتجاوز الشهر الحالي)
  bool get canGoNext {
    final now = DateTime.now();
    return !(displayYear.value == now.year &&
             displayMonth.value == now.month);
  }

  @override
  void onInit() {
    super.onInit();
    _loadMonthReports();
  }

  /// يُستدعى من زر "إعادة المحاولة" في بانر الأوفلاين.
  Future<void> retryConnection() => _loadMonthReports();

  // ═══════════════════════════════════════════
  //  التنقل بين الأشهر
  // ═══════════════════════════════════════════
  void prevMonth() {
    if (displayMonth.value == 1) {
      displayMonth.value = 12;
      displayYear.value--;
    } else {
      displayMonth.value--;
    }
    _resetSelection();
    _loadMonthReports();
  }

  void nextMonth() {
    if (!canGoNext) return;
    if (displayMonth.value == 12) {
      displayMonth.value = 1;
      displayYear.value++;
    } else {
      displayMonth.value++;
    }
    _resetSelection();
    _loadMonthReports();
  }

  void _resetSelection() {
    selectedDay.value    = null;
    selectedReport.value = null;
  }

  // ═══════════════════════════════════════════
  //  كاش أوفلاين: تقارير آخر 30 يوم كاملة (يغذّي كلاً من قائمة أيام
  //  الشهر المعروض وتقرير أي يوم مختار عند الأوفلاين)
  // ═══════════════════════════════════════════
  String get _last30CacheKey => 'student_reports_last30_$userId';

  Future<void> _syncLast30DaysCache() async {
    if (userId == null || _connectivity.isOffline.value) return;
    try {
      final cutoffStr = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String()
          .substring(0, 10);
      final data = await _supabase
          .from('daily_reports')
          .select('*')
          .eq('student_id', userId!)
          .gte('report_date', cutoffStr)
          .timeout(const Duration(seconds: 10));

      await _offlineCache.save(
        key: _last30CacheKey,
        items: List<Map<String, dynamic>>.from(data),
        dateOf: (item) =>
            DateTime.tryParse(item['report_date']?.toString() ?? ''),
      );
    } catch (e) {
      debugPrint('[UserCalendar] _syncLast30DaysCache: $e');
    }
  }

  void _applyMonthDaysFromCache() {
    final cached = _offlineCache.read(_last30CacheKey);
    if (cached == null) return;
    lastCachedAt.value = cached.cachedAt;
    final year  = displayYear.value;
    final month = displayMonth.value;
    final days = <int>{};
    for (final r in cached.data) {
      final d = DateTime.tryParse(r['report_date']?.toString() ?? '');
      if (d != null && d.year == year && d.month == month) days.add(d.day);
    }
    monthReportDays.value = days;
  }

  void _applyDayReportFromCache(int day) {
    final cached = _offlineCache.read(_last30CacheKey);
    if (cached == null) return;
    lastCachedAt.value = cached.cachedAt;
    final year  = displayYear.value;
    final month = displayMonth.value;
    final dateStr =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    Map<String, dynamic>? found;
    for (final r in cached.data) {
      if ((r['report_date']?.toString() ?? '').startsWith(dateStr)) {
        found = r;
        break;
      }
    }
    selectedReport.value = found;
  }

  // ═══════════════════════════════════════════
  //  جلب أيام التقارير للشهر المعروض
  // ═══════════════════════════════════════════
  Future<void> _loadMonthReports() async {
    if (userId == null) return;
    isLoadingMonth.value    = true;
    monthReportDays.value   = <int>{};

    if (_connectivity.isOffline.value) await _connectivity.checkReachable();
    if (_connectivity.isOffline.value) {
      // ما زلنا فعلياً أوفلاين بعد إعادة الفحص — نتخطى الشبكة ونذهب لكاش
      // آخر 30 يوم مباشرة (النطاق المدعوم أوفلاين فقط، حسب الطلب).
      _applyMonthDaysFromCache();
      isLoadingMonth.value = false;
      return;
    }

    try {
      final year  = displayYear.value;
      final month = displayMonth.value;
      String pad(int v) => v.toString().padLeft(2, '0');
      final firstDay   = '$year-${pad(month)}-01';
      final lastDayNum = DateTime(year, month + 1, 0).day;
      final lastDay    = '$year-${pad(month)}-${pad(lastDayNum)}';

      final data = await _supabase
          .from('daily_reports')
          .select('report_date')
          .eq('student_id', userId!)
          .gte('report_date', firstDay)
          .lte('report_date', lastDay)
          .timeout(const Duration(seconds: 10));

      final days = (data as List).map((r) {
        final s = r['report_date']?.toString() ?? '';
        return s.length >= 10
            ? (int.tryParse(s.substring(8, 10)) ?? 0)
            : 0;
      }).where((d) => d > 0).toSet();

      monthReportDays.value = days;
      _connectivity.reportSuccess();
      // مزامنة كاش آخر 30 يوم بالخلفية (بدون انتظار) كل ما نجح جلب حي.
      unawaited(_syncLast30DaysCache());
    } catch (e) {
      debugPrint('Error loading month reports: $e');
      _connectivity.reportFailure();
      _applyMonthDaysFromCache();
    } finally {
      isLoadingMonth.value = false;
    }
  }

  // ═══════════════════════════════════════════
  //  اختيار يوم وجلب تقريره
  // ═══════════════════════════════════════════
  Future<void> selectDay(int day) async {
    selectedDay.value    = day;
    selectedReport.value = null;
    await _loadDayReport(day);
  }

  Future<void> _loadDayReport(int day) async {
    if (userId == null) return;
    isLoadingReport.value = true;

    if (_connectivity.isOffline.value) {
      _applyDayReportFromCache(day);
      isLoadingReport.value = false;
      return;
    }

    try {
      final year  = displayYear.value;
      final month = displayMonth.value;
      String pad(int v) => v.toString().padLeft(2, '0');
      final dateStr = '$year-${pad(month)}-${pad(day)}';

      final data = await _supabase
          .from('daily_reports')
          .select('*')
          .eq('student_id', userId!)
          .eq('report_date', dateStr)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      selectedReport.value = data;
      _connectivity.reportSuccess();
    } catch (e) {
      debugPrint('Error loading day report: $e');
      _connectivity.reportFailure();
      _applyDayReportFromCache(day);
    } finally {
      isLoadingReport.value = false;
    }
  }
}
