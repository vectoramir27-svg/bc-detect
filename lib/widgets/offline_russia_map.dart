import 'package:flutter/material.dart';
import '../models/region_status.dart';

class OfflineRussiaMap extends StatelessWidget {
  final List<RegionInfo> regions;
  final Function(RegionInfo) onRegionTap;

  const OfflineRussiaMap({
    super.key,
    required this.regions,
    required this.onRegionTap,
  });

  Color _getColor(RestrictionLevel level) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 3.5,
              boundaryMargin: const EdgeInsets.all(40),
              child: SizedBox(
                width: 600,
                height: 350,
                child: CustomPaint(
                  painter: _MapCanvasPainter(regions: regions),
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
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.pinch_outlined, size: 14, color: Colors.white70),
                    SizedBox(width: 6),
                    Text(
                      "Оффлайн векторная карта (Зуммируйте)",
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            // Быстрые карточки регионов под картой
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: regions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final r = regions[i];
                    final c = _getColor(r.level);
                    return GestureDetector(
                      onTap: () => onRegionTap(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(r.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  final List<RegionInfo> regions;

  _MapCanvasPainter({required this.regions});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Стилизованные векторные полигоны основных макрорегионов РФ
    _drawRegionBlock(canvas, "ЦФО", const Rect.fromLTWH(80, 100, 70, 70), _getDistrictLevel("ЦФО"));
    _drawRegionBlock(canvas, "СЗФО", const Rect.fromLTWH(100, 40, 90, 60), _getDistrictLevel("СЗФО"));
    _drawRegionBlock(canvas, "ЮФО", const Rect.fromLTWH(60, 175, 80, 50), _getDistrictLevel("ЮФО"));
    _drawRegionBlock(canvas, "ПФО", const Rect.fromLTWH(155, 110, 75, 75), _getDistrictLevel("ПФО"));
    _drawRegionBlock(canvas, "УФО", const Rect.fromLTWH(235, 90, 80, 110), _getDistrictLevel("УФО"));
    _drawRegionBlock(canvas, "СФО", const Rect.fromLTWH(320, 100, 120, 120), _getDistrictLevel("СФО"));
    _drawRegionBlock(canvas, "ДФО", const Rect.fromLTWH(445, 60, 140, 160), RestrictionLevel.normal);
  }

  RestrictionLevel _getDistrictLevel(String district) {
    final match = regions.where((r) => r.federalDistrict == district && r.level == RestrictionLevel.whitelistActive);
    if (match.isNotEmpty) return RestrictionLevel.whitelistActive;
    final warn = regions.where((r) => r.federalDistrict == district && r.level == RestrictionLevel.warning);
    if (warn.isNotEmpty) return RestrictionLevel.warning;
    return RestrictionLevel.normal;
  }

  void _drawRegionBlock(Canvas canvas, String label, Rect rect, RestrictionLevel level) {
    Color col;
    switch (level) {
      case RestrictionLevel.normal:
        col = const Color(0xFF00FFA3);
        break;
      case RestrictionLevel.warning:
        col = const Color(0xFFFFB800);
        break;
      case RestrictionLevel.whitelistActive:
        col = const Color(0xFFFF3366);
        break;
      case RestrictionLevel.fullBlackout:
        col = const Color(0xFF9D00FF);
        break;
    }

    final fillPaint = Paint()
      ..color = col.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = col.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        color: col,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(rect.center.dx - textPainter.width / 2, rect.center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
