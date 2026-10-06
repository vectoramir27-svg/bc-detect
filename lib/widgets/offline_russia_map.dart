import 'dart:math';
import 'package:flutter/material.dart';
import '../models/region_status.dart';

class OfflineRussiaMap extends StatefulWidget {
  final List<RegionInfo> regions;
  final Function(RegionInfo) onRegionTap;

  const OfflineRussiaMap({
    super.key,
    required this.regions,
    required this.onRegionTap,
  });

  @override
  State<OfflineRussiaMap> createState() => _OfflineRussiaMapState();
}

class _OfflineRussiaMapState extends State<OfflineRussiaMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor(RestrictionLevel level) {
    switch (level) {
      case RestrictionLevel.normal:
        return const Color(0xFF00FFA3);
      case RestrictionLevel.warning:
        return const Color(0xFFFFB800);
      case RestrictionLevel.whitelistActive:
        return const Color(0xFFFF3366);
      case RestrictionLevel.fullBlackout:
        return const Color(0xFF9D00FF);
    }
  }

  Offset _getCoords(String id, Size size) {
    double x = 0.5;
    double y = 0.5;
    switch (id) {
      case "50": x = 0.20; y = 0.44; break; // МО
      case "77": x = 0.21; y = 0.46; break; // МСК
      case "78": x = 0.17; y = 0.35; break; // СПб
      case "47": x = 0.18; y = 0.32; break; // ЛО
      case "31": x = 0.15; y = 0.54; break; // Белгород
      case "46": x = 0.16; y = 0.50; break; // Курск
      case "36": x = 0.19; y = 0.53; break; // Воронеж
      case "23": x = 0.13; y = 0.64; break; // Краснодар
      case "61": x = 0.16; y = 0.60; break; // Ростов
      case "16": x = 0.28; y = 0.49; break; // Казань
      case "63": x = 0.27; y = 0.55; break; // Самара
      case "52": x = 0.24; y = 0.46; break; // Нижний Новгород
      case "66": x = 0.36; y = 0.52; break; // Екб
      case "74": x = 0.37; y = 0.58; break; // Челябинск
      case "54": x = 0.49; y = 0.63; break; // Новосибирск
      default: x = 0.50; y = 0.50;
    }
    return Offset(x * size.width, y * size.height);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.5,
              boundaryMargin: const EdgeInsets.all(40),
              child: SizedBox(
                width: 620,
                height: 310,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _TrueRussiaMapPainter(),
                      foregroundPainter: _RadarMarkersPainter(
                        regions: widget.regions,
                        getCoords: (id) => _getCoords(id, const Size(620, 310)),
                        getColor: _getStatusColor,
                        pulseValue: _pulseController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.radar, size: 14, color: Color(0xFF00FFA3)),
                    SizedBox(width: 6),
                    Text(
                      "Гео-радар покрытия РФ (Зуммируйте)",
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.regions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final r = widget.regions[i];
                    final c = _getStatusColor(r.level);
                    return GestureDetector(
                      onTap: () => widget.onRegionTap(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrueRussiaMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Сетка широты и долготы
    final grid = Paint()
      ..color = const Color(0xFF182232).withOpacity(0.6)
      ..strokeWidth = 1;

    for (double x = 0; x < w; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = 0; y < h; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Детальный сглаженный контур границ РФ
    final p = Path();
    p.moveTo(w * 0.16, h * 0.36); // Финский залив
    p.lineTo(w * 0.18, h * 0.28); // Карелия
    p.lineTo(w * 0.21, h * 0.19); // Мурманск / Кольский
    p.lineTo(w * 0.25, h * 0.22); // Белое море
    p.lineTo(w * 0.27, h * 0.27); // Архангельск
    p.lineTo(w * 0.33, h * 0.21); // НАО
    p.lineTo(w * 0.36, h * 0.15); // Ямал
    p.lineTo(w * 0.39, h * 0.23); // Обская губа
    p.lineTo(w * 0.44, h * 0.15); // Таймыр
    p.lineTo(w * 0.54, h * 0.21); // Море Лаптевых
    p.lineTo(w * 0.63, h * 0.23); // Дельта Лены
    p.lineTo(w * 0.72, h * 0.19); // Колыма
    p.lineTo(w * 0.83, h * 0.21); // Чукотка
    p.lineTo(w * 0.87, h * 0.30); // Мыс Дежнева
    p.lineTo(w * 0.82, h * 0.42); // Анадырский залив
    p.lineTo(w * 0.84, h * 0.56); // Камчатка
    p.lineTo(w * 0.81, h * 0.62); // Курилы
    p.lineTo(w * 0.75, h * 0.52); // Магадан
    p.lineTo(w * 0.73, h * 0.65); // Сахалин
    p.lineTo(w * 0.69, h * 0.71); // Приморский край
    p.lineTo(w * 0.65, h * 0.64); // Хабаровск
    p.lineTo(w * 0.59, h * 0.63); // Амур
    p.lineTo(w * 0.53, h * 0.68); // Забайкалье
    p.lineTo(w * 0.46, h * 0.69); // Байкал
    p.lineTo(w * 0.40, h * 0.67); // Алтай
    p.lineTo(w * 0.33, h * 0.63); // Южный Урал
    p.lineTo(w * 0.26, h * 0.61); // Каспий
    p.lineTo(w * 0.17, h * 0.69); // Кавказ
    p.lineTo(w * 0.12, h * 0.64); // Крым / Черное море
    p.lineTo(w * 0.14, h * 0.53); // Белгородская/Курская граница
    p.lineTo(w * 0.15, h * 0.43); // Псков
    p.close();

    final land = Paint()..color = const Color(0xFF131A26)..style = PaintingStyle.fill;
    canvas.drawPath(p, land);

    // Неоновое свечение границы
    final glow = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(p, glow);

    final border = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(p, border);

    // Калининградский эксклав
    final kld = Rect.fromLTWH(w * 0.08, h * 0.37, 10, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(kld, const Radius.circular(2)), land);
    canvas.drawRRect(RRect.fromRectAndRadius(kld, const Radius.circular(2)), border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RadarMarkersPainter extends CustomPainter {
  final List<RegionInfo> regions;
  final Offset Function(String) getCoords;
  final Color Function(RestrictionLevel) getColor;
  final double pulseValue;

  _RadarMarkersPainter({
    required this.regions,
    required this.getCoords,
    required this.getColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in regions) {
      final pos = getCoords(r.id);
      final col = getColor(r.level);

      // Анимированное радарное кольцо
      final pulseRadius = 5.0 + (pulseValue * 10.0);
      final pulseAlpha = (1.0 - pulseValue).clamp(0.0, 1.0);
      final ringPaint = Paint()
        ..color = col.withOpacity(pulseAlpha * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, pulseRadius, ringPaint);

      // Центральная точка
      final dot = Paint()..color = col..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 3.5, dot);

      // Код региона
      final text = TextSpan(
        text: r.shortCode,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 8,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(text: text, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - 13));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
