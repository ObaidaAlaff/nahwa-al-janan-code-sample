import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Weekly top-3-students card — a celebration-poster design (podium
/// layout: 2nd left, 1st center-elevated, 3rd right, matching a real
/// award stand) with a staggered reveal animation. Reused across all four
/// home dashboards (admin, quality admin, teacher, student).
class WeeklyTopCard extends StatefulWidget {
  final List<Map<String, dynamic>> top; // max 3 items [{name, count}]

  const WeeklyTopCard({super.key, required this.top});

  @override
  State<WeeklyTopCard> createState() => _WeeklyTopCardState();
}

class _WeeklyTopCardState extends State<WeeklyTopCard>
    with SingleTickerProviderStateMixin {
  // ── ألوان الملصق المرجعي ──
  static const _greenDeep = Color(0xFF173C2C);
  static const _gold      = Color(0xFFC9A227);
  static const _goldLight = Color(0xFFE7C873);
  static const _silver    = Color(0xFF9AA1AC);
  static const _bronze    = Color(0xFFC08552);
  static const _ink       = Color(0xFF1B2E22);
  static const _maroon    = Color(0xFF8C3B2E);

  // ── حركة دخول واحدة فقط عند الظهور ──
  late final AnimationController _entranceCtrl;
  late final Animation<double> _revealThird;
  late final Animation<double> _revealSecond;
  late final Animation<double> _revealFirst;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();

    _revealThird  = _reveal(0.00, 0.65);
    _revealSecond = _reveal(0.15, 0.80);
    _revealFirst  = _reveal(0.30, 1.00);
  }

  Animation<double> _reveal(double start, double end) => CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.top.isEmpty) return const SizedBox.shrink();

    final first  = widget.top.isNotEmpty ? widget.top[0] : null;
    final second = widget.top.length > 1  ? widget.top[1] : null;
    final third  = widget.top.length > 2  ? widget.top[2] : null;

    return _RevealItem(
      reveal: _revealThird,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _greenDeep.withValues(alpha: 0.22),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── الخلفية المتدرجة ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFBF6EA),
                      Color(0xFFF6EFDD),
                      Color(0xFFF3EAD4),
                    ],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            // ── وهج ذهبي ناعم أعلى اليمين ──
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 170, height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_gold.withValues(alpha: 0.14), Colors.transparent],
                  ),
                ),
              ),
            ),
            // ── نقش هندسي رفيع أعلى اليمين ──
            Positioned(
              top: 0, right: 0,
              child: SizedBox(
                width: 120, height: 120,
                child: CustomPaint(
                  painter: _GeoPatternPainter(color: _gold.withValues(alpha: 0.16)),
                ),
              ),
            ),

            // ── المحتوى ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 30),
                      _buildPodium(first, second, third),
                      const SizedBox(height: 16),
                      _buildQuoteBox(),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // _buildBottomBanner(),
              ],
            ),

            // ── زخارف الزهور في الزوايا العلوية (فوق كل شيء) ──
            Positioned(
              top: -6, left: -8,
              child: IgnorePointer(
                child: SvgPicture.string(_flowerClusterSvg, width: 88),
              ),
            ),
            Positioned(
              top: -2, right: -10,
              child: IgnorePointer(
                child: Transform.flip(
                  flipX: true,
                  child: SvgPicture.string(_flowerSingleSvg, width: 74),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════ الرأس ══════════════════════════
  Widget _buildHeader() {
    return Column(
      children: [
        SvgPicture.string(_crownSvg, width: 30),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.string(_sparkleSvg(_gold), width: 16),
            const SizedBox(width: 6),
            const Text(
              'أبرز طالبات الأسبوع',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _greenDeep,
                fontFamily: 'Tajawal',
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            SvgPicture.string(_sparkleSvg(_gold), width: 13),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'كنّ نجمات هذا الأسبوع',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _ink,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(width: 6),
            SvgPicture.string(_heartSvg(_maroon), width: 14),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════ المنصة ═════════════════════════
  Widget _buildPodium(
    Map<String, dynamic>? first,
    Map<String, dynamic>? second,
    Map<String, dynamic>? third,
  ) {
    // ترتيب بصري ثابت كالمنصة الحقيقية: الثانية يسار، الأولى وسط، الثالثة يمين
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _RevealItem(
            reveal: _revealSecond,
            child: _RankColumn(
              data: second,
              rank: 2,
              color: _silver,
              ringSize: 78,
              pillColor: const Color(0xFFE4E6E9),
              comment: 'أحسنتِ واصلي',
            ),
          ),
        ),
        Expanded(
          child: _RevealItem(
            reveal: _revealFirst,
            child: _RankColumn(
              data: first,
              rank: 1,
              color: _gold,
              ringSize: 104,
              elevated: true,
              pillColor: const Color(0xFFF3E3AC),
              comment: 'مبارك تميزكِ',
            ),
          ),
        ),
        Expanded(
          child: _RevealItem(
            reveal: _revealThird,
            child: _RankColumn(
              data: third,
              rank: 3,
              color: _bronze,
              ringSize: 74,
              pillColor: const Color(0xFFF1DAC5),
              comment: 'جهدكِ يُثمر',
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════ صندوق الاقتباس ═════════════════
  Widget _buildQuoteBox() {
    return CustomPaint(
      painter: _DashedRRectPainter(color: _gold, radius: 18),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                color: _greenDeep,
                shape: BoxShape.circle,
              ),
              child: Center(child: SvgPicture.string(_heartSvg(Colors.white), width: 18)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'كل خطوة تخطينها في طريق القرآن\nتقربكِ مِن الجنة وتزيدكِ نورًا',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                  fontFamily: 'Tajawal',
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════ الشريط السفلي ═══════════════════
  Widget _buildBottomBanner() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            // ── المنحنى العلوي ──
            SizedBox(
              width: double.infinity,
              child: CustomPaint(
                size: const Size(double.infinity, 30),
                painter: _BannerCurvePainter(fill: _greenDeep, stroke: _gold),
              ),
            ),
            // ── الجسم الداكن ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1B4230), Color(0xFF0F2A1E)],
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    bottom: -14, right: -10,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.95,
                        child: SvgPicture.string(_flowerBottomSvg, width: 96),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2, left: 2,
                    child: IgnorePointer(
                      child: SvgPicture.string(_flowerPinkSvg, width: 40),
                    ),
                  ),
                  Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        child: SvgPicture.string(_bookSvg),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'استمرَّي فأنتِ قَادرات على المزيد!',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: _goldLight,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                SvgPicture.string(_sparkleSvg(_goldLight), width: 12),
                              ],
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'اللهم اجعل القرآن ربيع قلوبنا وبلوغنا إلى جنتك',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Color(0xFFEDE6D2),
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                                fontFamily: 'Tajawal',
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  غلاف الدخول: تلاشٍ + ارتفاع خفيف لمرّة واحدة فقط
// ══════════════════════════════════════════════════════════════════
class _RevealItem extends StatelessWidget {
  final Animation<double> reveal;
  final Widget child;

  const _RevealItem({required this.reveal, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reveal,
      builder: (_, __) {
        final v = reveal.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 16),
            child: child,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  عمود مركز واحد على المنصة (حلقة متدرّجة + تاج/إكليل للأولى + بطاقة)
// ══════════════════════════════════════════════════════════════════
class _RankColumn extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int rank;
  final Color color;
  final double ringSize;
  final Color pillColor;
  final String comment;
  final bool elevated;

  const _RankColumn({
    required this.data,
    required this.rank,
    required this.color,
    required this.ringSize,
    required this.pillColor,
    required this.comment,
    this.elevated = false,
  });

  static const _greenDeep = Color(0xFF173C2C);
  static const _greenMid  = Color(0xFF1F5B41);
  static const _gold      = Color(0xFFC9A227);
  static const _ink       = Color(0xFF1B2E22);
  static const _maroon    = Color(0xFF8C3B2E);

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();
    final name  = data!['name']  as String? ?? '';
    final count = data!['count'] as int?    ?? 0;

    final ringPad  = elevated ? 6.0 : 5.0;
    final gapPad   = 4.0;
    final avatarSz = ringSize - (ringPad + gapPad) * 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── الصورة الرمزية + التاج/الإكليل + الشارة ──
        SizedBox(
          width: ringSize + 30,
          height: ringSize + (elevated ? 44 : 18),
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: elevated ? 22 : 10,
                child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // إكليل الغار — الأولى فقط
                      if (elevated) ...[
                        Positioned(
                          right: ringSize - 6,
                          child: SvgPicture.string(_laurelSvg(_gold), width: 30),
                        ),
                        Positioned(
                          left: ringSize - 6,
                          child: Transform.flip(
                            flipX: true,
                            child: SvgPicture.string(_laurelSvg(_gold), width: 30),
                          ),
                        ),
                      ],
                      // التاج — الأولى فقط
                      if (elevated)
                        Positioned(
                          top: -30,
                          child: SvgPicture.string(_crownSvgLarge, width: 42),
                        ),
                      // الحلقة المتدرّجة
                      Container(
                        width: ringSize,
                        height: ringSize,
                        padding: EdgeInsets.all(ringPad),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(color, Colors.white, 0.35)!,
                              color,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _greenDeep.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFE7F1E6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SvgPicture.string(
                                _bustSvg(_greenMid),
                                width: avatarSz * 0.78,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // شارة الرقم
                      Positioned(
                        bottom: -(elevated ? 15.0 : 12.0),
                        child: Container(
                          width: elevated ? 30 : 26,
                          height: elevated ? 30 : 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: elevated ? 13 : 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── البطاقة: شريط الاسم + المحتوى ──
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F1DF),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _greenDeep.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    vertical: elevated ? 12 : 10, horizontal: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_greenMid, _greenDeep],
                  ),
                ),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: elevated ? 12.5 : 11,
                    fontFamily: 'Tajawal',
                    height: 1.25,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 9, 6, 11),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: pillColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count تقرير',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      comment,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: elevated ? 11.5 : 10.5,
                        fontWeight: FontWeight.bold,
                        color: _greenMid,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 4),
                    SvgPicture.string(_heartSvg(_maroon), width: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  رسّامو الزخارف المخصّصة
// ══════════════════════════════════════════════════════════════════

/// نقش هندسي متقاطع رفيع مع تلاشٍ دائري نحو المركز — الزاوية العلوية
class _GeoPatternPainter extends CustomPainter {
  final Color color;
  _GeoPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final shader = RadialGradient(
      center: Alignment.topRight,
      radius: 1.0,
      colors: [color, color.withValues(alpha: 0)],
      stops: const [0.0, 0.75],
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    const step = 10.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GeoPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// إطار منقّط (dashed) مستدير الزوايا — صندوق الاقتباس
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

/// المنحنى العلوي لخلفية الشريط السفلي
class _BannerCurvePainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  _BannerCurvePainter({required this.fill, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fillPath = Path()
      ..moveTo(0, h)
      ..cubicTo(w * 0.24, -h * 0.35, w * 0.76, -h * 0.35, w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fill);

    final strokePath = Path()
      ..moveTo(0, h - 2)
      ..cubicTo(w * 0.24, -h * 0.15, w * 0.76, -h * 0.15, w, h - 2);
    canvas.drawPath(
      strokePath,
      Paint()
        ..color = stroke.withValues(alpha: 0.7)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BannerCurvePainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════
//  SVG مضمّنة — مطابقة لعناصر الملصق المرجعي
// ══════════════════════════════════════════════════════════════════

String _colorHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

/// تاج صغير (للعنوان)
const String _crownSvg = '''
<svg viewBox="0 0 60 44" xmlns="http://www.w3.org/2000/svg">
  <path d="M4 38 L2 14 L16 24 L30 6 L44 24 L58 14 L56 38 Z" fill="#D9A441" stroke="#B9862A" stroke-width="1.5" stroke-linejoin="round"/>
  <circle cx="30" cy="4" r="4" fill="#D9A441"/>
  <circle cx="4" cy="12" r="3" fill="#D9A441"/>
  <circle cx="56" cy="12" r="3" fill="#D9A441"/>
  <rect x="2" y="36" width="56" height="6" rx="2" fill="#C9A227"/>
</svg>
''';

/// تاج أكبر (فوق المركز الأول)
const String _crownSvgLarge = _crownSvg;

/// بريق/نجمة صغيرة بلون متغيّر
String _sparkleSvg(Color color) => '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 0 C12 7 14 9 21 9 C14 9 12 11 12 18 C12 11 10 9 3 9 C10 9 12 7 12 0Z" fill="${_colorHex(color)}"/>
</svg>
''';

/// قلب صغير بلون متغيّر
String _heartSvg(Color color) => '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M12 21s-7.5-4.6-10-9.1C.4 8.5 2 5 5.6 5c2 0 3.5 1.1 4.4 2.6C10.9 6.1 12.4 5 14.4 5 18 5 19.6 8.5 22 11.9 19.5 16.4 12 21 12 21z" fill="${_colorHex(color)}"/>
</svg>
''';

/// تخطيط الجسم (silhouette) للصورة الرمزية
String _bustSvg(Color color) => '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M50,26 C41,26 34,33 34,42 C34,47 36,51 39,54 C25,58 16,68 16,80 L16,86 L84,86 L84,80 C84,68 75,58 61,54 C64,51 66,47 66,42 C66,33 59,26 50,26 Z" fill="${_colorHex(color)}"/>
</svg>
''';

/// غصن غار جانبي بلون متغيّر
String _laurelSvg(Color color) => '''
<svg viewBox="0 0 60 100" xmlns="http://www.w3.org/2000/svg">
  <path d="M50 10 Q10 50 50 90" stroke="${_colorHex(color)}" stroke-width="2.5" fill="none"/>
  <ellipse cx="26" cy="24" rx="11" ry="5" fill="#B7C79A" transform="rotate(-30 26 24)"/>
  <ellipse cx="16" cy="42" rx="11" ry="5" fill="#B7C79A" transform="rotate(-6 16 42)"/>
  <ellipse cx="16" cy="60" rx="11" ry="5" fill="#B7C79A" transform="rotate(20 16 60)"/>
  <ellipse cx="26" cy="78" rx="11" ry="5" fill="#B7C79A" transform="rotate(45 26 78)"/>
</svg>
''';

/// عنقود زهور الزاوية العلوية اليسرى (زهرتان + ساق وأوراق)
const String _flowerClusterSvg = '''
<svg viewBox="0 0 140 140" xmlns="http://www.w3.org/2000/svg">
  <g>
    <path d="M20 90 Q40 60 20 30" stroke="#7C9A6B" stroke-width="3" fill="none"/>
    <ellipse cx="14" cy="70" rx="12" ry="5" fill="#8FAE79" transform="rotate(-30 14 70)"/>
    <ellipse cx="10" cy="50" rx="12" ry="5" fill="#7C9A6B" transform="rotate(20 10 50)"/>
  </g>
  <g transform="translate(46,36)">
    <ellipse cx="0" cy="-20" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1"/>
    <ellipse cx="19" cy="-6" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1" transform="rotate(72 19 -6)"/>
    <ellipse cx="12" cy="16" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1" transform="rotate(144 12 16)"/>
    <ellipse cx="-12" cy="16" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1" transform="rotate(216 -12 16)"/>
    <ellipse cx="-19" cy="-6" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1" transform="rotate(288 -19 -6)"/>
    <circle cx="0" cy="0" r="9" fill="#E7C873"/>
  </g>
  <g transform="translate(84,58)">
    <ellipse cx="0" cy="-12" rx="8" ry="12" fill="#FDF7E9" stroke="#EADFC6" stroke-width="1"/>
    <ellipse cx="11" cy="-4" rx="8" ry="12" fill="#FDF7E9" stroke="#EADFC6" stroke-width="1" transform="rotate(72 11 -4)"/>
    <ellipse cx="7" cy="10" rx="8" ry="12" fill="#FDF7E9" stroke="#EADFC6" stroke-width="1" transform="rotate(144 7 10)"/>
    <ellipse cx="-7" cy="10" rx="8" ry="12" fill="#FDF7E9" stroke="#EADFC6" stroke-width="1" transform="rotate(216 -7 10)"/>
    <ellipse cx="-11" cy="-4" rx="8" ry="12" fill="#FDF7E9" stroke="#EADFC6" stroke-width="1" transform="rotate(288 -11 -4)"/>
    <circle cx="0" cy="0" r="6" fill="#D9A441"/>
  </g>
</svg>
''';

/// زهرة واحدة (الزاوية العلوية اليمنى)
const String _flowerSingleSvg = '''
<svg viewBox="0 0 140 140" xmlns="http://www.w3.org/2000/svg">
  <g>
    <path d="M20 90 Q40 60 20 30" stroke="#7C9A6B" stroke-width="3" fill="none"/>
    <ellipse cx="14" cy="70" rx="12" ry="5" fill="#8FAE79" transform="rotate(-30 14 70)"/>
  </g>
  <g transform="translate(46,36)">
    <ellipse cx="0" cy="-20" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1"/>
    <ellipse cx="19" cy="-6" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1" transform="rotate(72 19 -6)"/>
    <ellipse cx="12" cy="16" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1" transform="rotate(144 12 16)"/>
    <ellipse cx="-12" cy="16" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1" transform="rotate(216 -12 16)"/>
    <ellipse cx="-19" cy="-6" rx="13" ry="20" fill="#FFFFFF" stroke="#EADFC6" stroke-width="1" transform="rotate(288 -19 -6)"/>
    <circle cx="0" cy="0" r="9" fill="#E7C873"/>
  </g>
</svg>
''';

/// زهرة بيضاء كبيرة — أسفل الشريط السفلي
const String _flowerBottomSvg = '''
<svg viewBox="0 0 140 140" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(70,70)">
    <ellipse cx="0" cy="-24" rx="15" ry="24" fill="#FFFFFF"/>
    <ellipse cx="23" cy="-7" rx="15" ry="24" fill="#FFFFFF" transform="rotate(72 23 -7)"/>
    <ellipse cx="14" cy="19" rx="15" ry="24" fill="#FFFFFF" transform="rotate(144 14 19)"/>
    <ellipse cx="-14" cy="19" rx="15" ry="24" fill="#FFFFFF" transform="rotate(216 -14 19)"/>
    <ellipse cx="-23" cy="-7" rx="15" ry="24" fill="#FFFFFF" transform="rotate(288 -23 -7)"/>
    <circle cx="0" cy="0" r="10" fill="#E7C873"/>
  </g>
  <path d="M30 110 Q10 90 30 70" stroke="#7C9A6B" stroke-width="3" fill="none"/>
  <ellipse cx="18" cy="94" rx="10" ry="4" fill="#8FAE79" transform="rotate(-20 18 94)"/>
</svg>
''';

/// زهرة وردية صغيرة — أسفل الشريط السفلي
const String _flowerPinkSvg = '''
<svg viewBox="0 0 80 80" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate(40,40)">
    <ellipse cx="0" cy="-14" rx="9" ry="14" fill="#E9BFC6"/>
    <ellipse cx="13" cy="-4" rx="9" ry="14" fill="#E9BFC6" transform="rotate(72 13 -4)"/>
    <ellipse cx="8" cy="11" rx="9" ry="14" fill="#E9BFC6" transform="rotate(144 8 11)"/>
    <ellipse cx="-8" cy="11" rx="9" ry="14" fill="#E9BFC6" transform="rotate(216 -8 11)"/>
    <ellipse cx="-13" cy="-4" rx="9" ry="14" fill="#E9BFC6" transform="rotate(288 -13 -4)"/>
    <circle cx="0" cy="0" r="6" fill="#D9A441"/>
  </g>
</svg>
''';

/// أيقونة كتاب/مصحف مفتوح
const String _bookSvg = '''
<svg viewBox="0 0 80 76" xmlns="http://www.w3.org/2000/svg">
  <path d="M40,58 L14,72 M40,58 L66,72 M40,42 L14,64 M40,42 L66,64" stroke="#8A5A34" stroke-width="3" stroke-linecap="round"/>
  <path d="M40,18 L8,25 L8,48 L40,41 Z" fill="#FBF3E2" stroke="#8A5A34" stroke-width="2" stroke-linejoin="round"/>
  <path d="M40,18 L72,25 L72,48 L40,41 Z" fill="#FBF3E2" stroke="#8A5A34" stroke-width="2" stroke-linejoin="round"/>
  <rect x="37" y="16" width="6" height="26" fill="#8A5A34"/>
  <line x1="14" y1="30" x2="34" y2="26" stroke="#8FAE79" stroke-width="1.4"/>
  <line x1="14" y1="35" x2="34" y2="31" stroke="#8FAE79" stroke-width="1.4"/>
  <line x1="14" y1="40" x2="34" y2="36" stroke="#8FAE79" stroke-width="1.4"/>
  <line x1="46" y1="26" x2="66" y2="30" stroke="#8FAE79" stroke-width="1.4"/>
  <line x1="46" y1="31" x2="66" y2="35" stroke="#8FAE79" stroke-width="1.4"/>
  <line x1="46" y1="36" x2="66" y2="40" stroke="#8FAE79" stroke-width="1.4"/>
</svg>
''';
