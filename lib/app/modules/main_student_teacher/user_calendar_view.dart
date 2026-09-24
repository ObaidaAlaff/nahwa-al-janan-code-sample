import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/background_scaffold.dart';
import '../../core/widgets/offline_banner.dart';
import '../../routes/app_routes.dart';
import 'user_calendar_controller.dart';

/// Progress-calendar screen — a color-coded month grid (green = submitted,
/// red = missed, amber = holiday) that doubles as an activity heatmap,
/// plus the full report for whichever day is tapped.
class UserCalendarView extends GetView<UserCalendarController> {
  const UserCalendarView({super.key});

  // ── ترويسات أيام الأسبوع (السبت → الجمعة) ──
  static const _dayHeaders = ['سبت', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمس', 'جمع'];

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    children: [
                      Obx(() => controller.isOffline.value
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: OfflineBanner(
                                cachedAt: controller.lastCachedAt.value,
                                onRetry: controller.retryConnection,
                              ),
                            )
                          : const SizedBox.shrink()),
                      _buildMonthNavigator(),
                      const SizedBox(height: 14),
                      _buildCalendarGrid(),
                      const SizedBox(height: 6),
                      _buildLegend(),
                      const SizedBox(height: 20),
                      _buildSelectedDayReport(),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
                // شاشات عريضة: تقويم + تقرير اليوم عمود واحد طبيعي
                // (ليس بطاقات لوحة قيادة) → عرض أقصى مُوسَّط فقط.
                if (constraints.maxWidth < 800) return content;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: content,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== الهيدر (بنفس أسلوب التبويبات الأخرى) ====================
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        image: DecorationImage(
          image: AssetImage('assets/zokhroofa.png'),
          fit: BoxFit.fitWidth,
          opacity: 0.03,
        ),
      ),
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Text(
            'تقويم التقارير',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
      ),
    );
  }

  // ==================== منتقي الشهر ====================
  Widget _buildMonthNavigator() {
    return Obx(() {
      final year  = controller.displayYear.value;
      final month = controller.displayMonth.value;
      final canNext = controller.canGoNext;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppTheme.alpha),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // السهم التالي (يسار في RTL)
            IconButton(
              onPressed: canNext ? controller.nextMonth : null,
              icon: Icon(
                Icons.chevron_left_rounded,
                size: 28,
                color: canNext ? AppColors.primaryGreen : Colors.grey[300],
              ),
            ),
            // اسم الشهر والسنة
            Column(
              children: [
                Text(
                  _arabicMonth(month),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '$year',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
            // السهم السابق (يمين في RTL)
            IconButton(
              onPressed: controller.prevMonth,
              icon: const Icon(
                Icons.chevron_right_rounded,
                size: 28,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ==================== شبكة التقويم ====================
  Widget _buildCalendarGrid() {
    return Obx(() {
      final year         = controller.displayYear.value;
      final month        = controller.displayMonth.value;
      final reportDays   = controller.monthReportDays.value;
      final selectedDay  = controller.selectedDay.value;
      final isLoading    = controller.isLoadingMonth.value;
      final now          = DateTime.now();
      final today        = (year == now.year && month == now.month) ? now.day : -1;
      final daysInMonth  = DateTime(year, month + 1, 0).day;

      // offset: كم خلية فارغة قبل أول يوم (الأسبوع يبدأ السبت)
      // Dart weekday: Mon=1..Sat=6..Sun=7
      final firstWeekday = DateTime(year, month, 1).weekday;
      final startOffset  = (firstWeekday - 6 + 7) % 7;

      final totalCells = startOffset + daysInMonth;
      final rows       = (totalCells / 7).ceil();

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppTheme.alpha),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── ترويسة الأيام ──
            Row(
              children: _dayHeaders
                  .map((h) => Expanded(
                        child: Center(
                          child: Text(
                            h,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              Column(
                children: List.generate(rows, (row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: List.generate(7, (col) {
                        final cellIndex = row * 7 + col;
                        final day       = cellIndex - startOffset + 1;

                        if (day < 1 || day > daysInMonth) {
                          return const Expanded(child: SizedBox(height: 40));
                        }

                        final dayDate   = DateTime(year, month, day);
                        final isFriday  = dayDate.weekday == 5; // Dart Fri=5
                        final isFuture  = today != -1 && day > today;
                        final isToday   = day == today;
                        final hasReport = reportDays.contains(day);
                        final isSelected = day == selectedDay;

                        Color bgColor;
                        Color textColor;

                        if (isFuture) {
                          bgColor   = Colors.grey.withValues(alpha: 0.07);
                          textColor = Colors.black26;
                        } else if (isFriday) {
                          bgColor   = Colors.amber.withValues(alpha: 0.18);
                          textColor = Colors.orange.shade800;
                        } else if (hasReport) {
                          bgColor   = AppColors.primaryGreen.withValues(alpha: 0.18);
                          textColor = AppColors.primaryGreen;
                        } else {
                          bgColor   = Colors.red.withValues(alpha: 0.13);
                          textColor = Colors.red.shade600;
                        }

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => controller.selectDay(day),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : bgColor,
                                borderRadius: BorderRadius.circular(8),
                                border: isToday && !isSelected
                                    ? Border.all(
                                        color: AppColors.primaryGreen,
                                        width: 1.5)
                                    : isSelected
                                        ? null
                                        : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryGreen
                                              .withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: (isToday || isSelected)
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
          ],
        ),
      );
    });
  }

  // ==================== مفتاح الألوان ====================
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(AppColors.primaryGreen.withValues(alpha: 0.18),
            AppColors.primaryGreen, 'سلّمت'),
        const SizedBox(width: 14),
        _legendItem(Colors.red.withValues(alpha: 0.13), Colors.red.shade600,
            'لم تسلّم'),
        const SizedBox(width: 14),
        _legendItem(Colors.amber.withValues(alpha: 0.18), Colors.orange.shade800,
            'إجازة'),
      ],
    );
  }

  Widget _legendItem(Color bg, Color textColor, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: textColor)),
      ],
    );
  }

  // ==================== تقرير اليوم المختار ====================
  Widget _buildSelectedDayReport() {
    return Obx(() {
      final day = controller.selectedDay.value;

      // لم يُختر يوم بعد
      if (day == null) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: AppTheme.alpha),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.touch_app_outlined, size: 40, color: Colors.black26),
              SizedBox(height: 10),
              Text(
                'اضغطي على يوم من التقويم\nلعرض تقريره',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black38, height: 1.6),
              ),
            ],
          ),
        );
      }

      final isLoadingR = controller.isLoadingReport.value;

      if (isLoadingR) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: AppTheme.alpha),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: const Center(
            child: CircularProgressIndicator(
                color: AppColors.primaryGreen, strokeWidth: 2),
          ),
        );
      }

      final report = controller.selectedReport.value;

      // لا يوجد تقرير لهذا اليوم
      if (report == null) {
        final year  = controller.displayYear.value;
        final month = controller.displayMonth.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: AppTheme.alpha),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.event_busy_outlined,
                  size: 40, color: Colors.black26),
              const SizedBox(height: 10),
              Text(
                'لا يوجد تقرير ليوم $day ${_arabicMonth(month)} $year',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Colors.black54, height: 1.6),
              ),
            ],
          ),
        );
      }

      // ── عرض التقرير ──
      return _buildReportCard(report);
    });
  }

  // ==================== كارد التقرير (بنفس تصميم ReportsTab) ====================
  Widget _buildReportCard(Map<String, dynamic> report) {
    final date = DateTime.tryParse(report['report_date']?.toString() ?? '');
    final dateLine = date != null
        ? '${date.day} ${_arabicMonth(date.month)} ${date.year}'
        : (report['report_date']?.toString() ?? '');
    final weekdayLine = date != null ? _weekdayArabic(date) : '';
    final notes = report['notes']?.toString().trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.alpha),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── التاريخ + النجمات ──
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    AppColors.primaryGreen.withValues(alpha: 0.15),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 20, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateLine,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(weekdayLine,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
              _buildWirdStars(report),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 8),

          // ── تفاصيل الأوراد ──
          _buildWirdDetails(report),

          // ملاحظات
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 8),
            _infoRow(Icons.notes_outlined, 'الملاحظات', notes),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 10),

          // ── زر عرض التقرير الكامل ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed(
                Routes.REPORT_DETAIL,
                arguments: {'report': report, 'readOnly': true},
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('عرض التقرير كاملاً',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontFamily: 'Tajawal',
                  height: 1.5),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _weekdayArabic(DateTime d) {
    const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[d.weekday - 1];
  }

  // ==================== نجمات + تفاصيل الأوراد (بنفس منطق ReportsTab) ====================
  Widget _buildWirdStars(Map<String, dynamic> report) {
    if (report['is_juz_fixed'] == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'جزء ${report['juz_number'] ?? '-'}',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen),
        ),
      );
    }
    const wirdKeys = [
      'listening_done',
      'tafsir_done',
      'memorize_done',
      'near_review_done',
      'far_review_done',
      'prayer_done',
      'similar_done',
      'tadabur_done',
    ];

    final doneCount = wirdKeys.where((k) => report[k] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                final lit = i < doneCount;
                return Icon(
                  lit ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: lit ? Colors.amber : Colors.grey[300],
                );
              }),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (i) {
                final lit = (i + 4) < doneCount;
                return Icon(
                  lit ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: lit ? Colors.amber : Colors.grey[300],
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWirdDetails(Map<String, dynamic> r) {
    if (r['is_juz_fixed'] == true) {
      final achievement = r['daily_achievement']?.toString() ?? '';
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 15, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              achievement.isNotEmpty ? achievement : 'لا يوجد وصف',
              style: const TextStyle(
                  fontSize: 12, color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      );
    }
    int? v(String key) {
      final val = r[key];
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    bool done(String key) => r[key] == true;

    // نص النطاق: إذا وُجد "إلى" يعرض "من X إلى Y" وإلا "ص X"
    String range(int? from, int? to) {
      if (from == null) return '';
      if (to != null && to != from) return 'من ص $from إلى ص $to';
      return 'ص $from';
    }

    // الاستماع
    final listenDetail = range(v('listen_page'), v('listen_page_to'));

    // التفسير
    final tafsirDetail = range(v('tafsir_page'), v('tafsir_page_to'));

    // الحفظ
    final memoBase  = range(v('memorize_page'), v('memorize_page_to'));
    final half      = r['memorize_half'];
    final halfLabel = half == 1 ? '(النصف الأول)' : half == 2 ? '(النصف الثاني)' : '';
    final memoDetail = [memoBase, halfLabel].where((s) => s.isNotEmpty).join(' ');

    // المراجعة القريبة (مع النطاق الإضافي)
    final nrLines = <String>[
      range(v('near_review_from'), v('near_review_to')),
      if (v('near_review_from_2') != null)
        range(v('near_review_from_2'), v('near_review_to_2')),
    ].where((s) => s.isNotEmpty).toList();

    // المراجعة البعيدة (مع عدد الصفحات والنطاق الإضافي)
    final frBase = [
      if (v('far_review_pages') != null) '${v('far_review_pages')} ص —',
      range(v('far_review_from'), v('far_review_to')),
    ].where((s) => s.isNotEmpty).join(' ');
    final frLines = <String>[
      frBase,
      if (v('far_review_from_2') != null)
        range(v('far_review_from_2'), v('far_review_to_2')),
    ].where((s) => s.isNotEmpty).toList();

    // الصلاة (مع الصفحة الثانية)
    final prayerLines = <String>[
      if (v('prayer_page') != null) 'ص ${v('prayer_page')}',
      if (v('prayer_page_2') != null) 'ص ${v('prayer_page_2')}',
    ];

    // المتشابهات
    final similarDetail = range(v('similar_page'), v('similar_page_to'));

    // التدبر
    final tadaburDetail = range(v('tadabur_page'), v('tadabur_page_to'));

    final wards = <Map<String, dynamic>>[
      {'name': 'الاستماع',         'done': done('listening_done'), 'lines': listenDetail.isNotEmpty  ? [listenDetail]  : <String>[]},
      {'name': 'التفسير',          'done': done('tafsir_done'),    'lines': tafsirDetail.isNotEmpty  ? [tafsirDetail]  : <String>[]},
      {'name': 'الحفظ',            'done': done('memorize_done'),  'lines': memoDetail.isNotEmpty    ? [memoDetail]    : <String>[]},
      {'name': 'المراجعة القريبة', 'done': done('near_review_done'), 'lines': nrLines},
      {'name': 'المراجعة البعيدة', 'done': done('far_review_done'),  'lines': frLines},
      {'name': 'الصلاة بالمحفوظ', 'done': done('prayer_done'),    'lines': prayerLines},
      {'name': 'المتشابهات',       'done': done('similar_done'),   'lines': similarDetail.isNotEmpty ? [similarDetail] : <String>[]},
      {'name': 'التدبر',           'done': done('tadabur_done'),   'lines': tadaburDetail.isNotEmpty ? [tadaburDetail] : <String>[]},
    ];

    return Column(
      children: wards.map((w) {
        final isDone = w['done'] as bool;
        final name   = w['name']  as String;
        final lines  = w['lines'] as List<String>;
        final color  = isDone ? AppColors.primaryGreen : Colors.grey;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أيقونة الحالة
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 15,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              // اسم الورد
              SizedBox(
                width: 100,
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              // التفاصيل (من ... إلى ...)
              if (lines.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines
                        .map((l) => Text(
                              l,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── اسم الشهر بالعربية ──
  static String _arabicMonth(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
