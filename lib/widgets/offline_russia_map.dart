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

class _OfflineRussiaMapState extends State<OfflineRussiaMap> {
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

  // Географические координаты для расстановки маркеров на оффлайн-карте
  Offset _getCoords(String id, Size size) {
    double x = 0.5;
    double y = 0.5;
    switch (id) {
      case "50": // МО
        x = 0.19; y = 0.44; break;
      case "77": // Москва
        x = 0.20; y = 0.46; break;
      case "78": // Санкт-Петербург
        x = 0.17; y = 0.35; break;
      case "47": // ЛО
        x = 0.18; y = 0.32; break;
      case "31": // Белгород
        x = 0.15; y = 0.53; break;
      case "36": // Воронеж
        x = 0.18; y = 0.51; break;
      case "23": // Краснодар / Сочи
        x = 0.13; y = 0.62; break;
      case "61": // Ростов
        x = 0.15; y = 0.58; break;
      case "16": // Татарстан / Казань
        x = 0.27; y = 0.49; break;
      case "63": // Самара
        x = 0.26; y = 0.54; break;
      case "52": // Нижний Новгород
        x = 0.23; y = 0.45; break;
      case "66": // Екатеринбург (Урал)
        x = 0.35; y = 0.52; break;
      case "74": // Челябинск
        x = 0.36; y = 0.57; break;
      case "54": // Новосибирск (Сибирь)
        x = 0.48; y = 0.63; break;
      default:
        x = 0.50; y = 0.50;
    }
    return Offset(x * size.width, y * size.height);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      height: 290,
      decoration: BoxDecoration(
        color: const Color(0xFF0F131C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(30),
              child: SizedBox(
                width: 580,
                height: 290,
                child: CustomPaint(
                  painter: _RealRussiaMapPainter(),
                  foregroundPainter: _MarkersPainter(
                    regions: widget.regions,
                    getCoords: (id) => _getCoords(id, const Size(580, 290)),
                    getColor: _getStatusColor,
                  ),
                ),
              ),
            ),
            // Оверлей подсказки
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.radar, size: 14, color: Color(0xFF00FFA3)),
                    SizedBox(width: 6),
                    Text(
                      "Карта покрытия РФ (Радар активности)",
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            // Нижняя плашка быстрого перехода
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
                          color: const Color(0xFF161B24).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.withOpacity(0.4)),
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

class _RealRussiaMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Координатная гео-сетка (параллели и меридианы)
    final gridPaint = Paint()
      ..color = const Color(0xFF1A2333).withOpacity(0.7)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 45) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 45) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Реалистичный сглаженный векторный контур территории Российской Федерации
    final w = size.width;
    final h = size.height;

    final path = Path();
    // Балтика / Северо-Запад
    path.moveTo(w * 0.16, h * 0.36);
    path.lineTo(w * 0.18, h * 0.28); // Карелия
    path.lineTo(w * 0.21, h * 0.20); // Кольский полуостров
    path.lineTo(w * 0.25, h * 0.23); // Белое море
    path.lineTo(w * 0.27, h * 0.28); // Архангельск
    path.lineTo(w * 0.33, h * 0.22); // Побережье НАО
    path.lineTo(w * 0.36, h * 0.16); // Карское море / Ямал
    path.lineTo(w * 0.39, h * 0.25); // Обская губа
    path.lineTo(w * 0.44, h * 0.16); // Таймыр (Северный мыс)
    path.lineTo(w * 0.54, h * 0.22); // Море Лаптевых
    path.lineTo(w * 0.63, h * 0.24); // Дельта Лены
    path.lineTo(w * 0.72, h * 0.20); // Колыма
    path.lineTo(w * 0.83, h * 0.22); // Чукотка (Берингов пролив)
    path.lineTo(w * 0.86, h * 0.32); // Мыс Дежнёва
    path.lineTo(w * 0.81, h * 0.44); // Анадырь / Камчатка верх
    path.lineTo(w * 0.83, h * 0.58); // Камчатский полуостров
    path.lineTo(w * 0.80, h * 0.60); // Курильская гряда
    path.lineTo(w * 0.74, h * 0.50); // Охотское море / Магадан
    path.lineTo(w * 0.72, h * 0.64); // Сахалин
    path.lineTo(w * 0.68, h * 0.70); // Приморье / Владивосток
    path.lineTo(w * 0.64, h * 0.63); // Хабаровский край
    path.lineTo(w * 0.58, h * 0.62); // Амурская граница
    path.lineTo(w * 0.52, h * 0.67); // Забайкалье
    path.lineTo(w * 0.45, h * 0.68); // Байкал / Алтай
    path.lineTo(w * 0.39, h * 0.66); // Южная Сибирь
    path.lineTo(w * 0.32, h * 0.62); // Южный Урал
    path.lineTo(w * 0.25, h * 0.60); // Поволжье низ
    path.lineTo(w * 0.17, h * 0.68); // Кавказ / Каспий
    path.lineTo(w * 0.12, h * 0.64); // Черное море / Крым
    path.lineTo(w * 0.14, h * 0.52); // Западная граница
    path.lineTo(w * 0.15, h * 0.42); // Псков / Новгород
    path.close();

    // Заливка суши
    final landPaint = Paint()
      ..color = const Color(0xFF131B2A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, landPaint);

    // Внешнее неоновое свечение границы
    final glowPaint = Paint()
      ..color = const Color(0xFF0075FF).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    // Основная линия государственной границы
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(path, borderPaint);

    // Отдельный анклав: Калининград
    final kldRect = Rect.fromLTWH(w * 0.08, h * 0.37, 10, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(kldRect, const Radius.circular(2)), landPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(kldRect, const Radius.circular(2)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MarkersPainter extends CustomPainter {
  final List<RegionInfo> regions;
  final Offset Function(String) getCoords;
  final Color Function(RestrictionLevel) getColor;

  _MarkersPainter({
    required this.regions,
    required this.getCoords,
    required this.getColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in regions) {
      final pos = getCoords(r.id);
      final color = getColor(r.level);

      // Радарный импульс вокруг города
      final pulsePaint = Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 8, pulsePaint);

      // Центральная яркая точка
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 3.5, dotPaint);

      // Код региона над точкой
      final span = TextSpan(
        text: r.shortCode,
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 8,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - 13));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
