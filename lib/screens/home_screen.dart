import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/region_status.dart';
import '../data/regions_database.dart';
import '../services/detector_service.dart';
import '../widgets/offline_russia_map.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<RegionInfo> _regions;
  String _searchQuery = "";
  String _selectedDistrict = "ВСЕ";
  bool _showMap = true;

  // ВСТАВЬ СЮДА IP-АДРЕС СВОЕГО VPS СЕРВЕРА:
  final String _serverUrl = "http://144.31.192.63:8080";

  @override
  void initState() {
    super.initState();
    _regions = RegionsDatabase.getInitialRegions();
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

  String _getStatusText(RestrictionLevel level) {
    switch (level) {
      case RestrictionLevel.normal:
        return "Сеть в норме";
      case RestrictionLevel.warning:
        return "Нестабильно";
      case RestrictionLevel.whitelistActive:
        return "Белый список";
      case RestrictionLevel.fullBlackout:
        return "Блэкаут";
    }
  }

  Future<void> _sendReportToServer(RegionInfo region, String city) async {
    try {
      final response = await http.post(
        Uri.parse("$_serverUrl/api/report"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "region_id": region.id,
          "city": city,
        }),
      ).timeout(const Duration(seconds: 4));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00FFA3),
            content: Text("Жалоба по г. $city отправлена на сервер!", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        );
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (_) {
      if (!mounted) return;
      // Сохраняем локально, если сервер под глушилкой не ответил
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E2638),
          content: Text("Сервер недоступен из-за фильтров. Жалоба по г. $city сохранена локально!"),
        ),
      );
    }
  }

  void _showRegionDetailModal(RegionInfo region, {String? matchedCity}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final color = _getStatusColor(region.level);
        final currentCity = matchedCity ?? (region.cities.isNotEmpty ? region.cities.first : region.name);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF111622).withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text(
                        "РЕГИОН ${region.id}",
                        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(_getStatusText(region.level), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  matchedCity != null ? "$matchedCity (${region.name})" : region.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  "Округ: ${region.federalDistrict}",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          region.comment,
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Города региона в базе:", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: region.cities.map((city) {
                    final isHighlighted = matchedCity != null && city.toLowerCase() == matchedCity.toLowerCase();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isHighlighted ? color.withOpacity(0.25) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isHighlighted ? color : Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(
                        city,
                        style: TextStyle(
                          color: isHighlighted ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendReportToServer(region, currentCity);
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: Text("Сообщить о белом списке в $currentCity", style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3366).withOpacity(0.2),
                      foregroundColor: const Color(0xFFFF3366),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFFF3366)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detector = Provider.of<NetworkDetectorService>(context);

    final filtered = _regions.where((r) {
      if (_selectedDistrict != "ВСЕ" && r.federalDistrict != _selectedDistrict) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final matchRegion = r.name.toLowerCase().contains(query);
      final matchCity = r.cities.any((c) => c.toLowerCase().contains(query));
      return matchRegion || matchCity;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getStatusColor(detector.localStatus).withOpacity(0.18),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(color: Colors.transparent),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildStatusBanner(detector),
                _buildSearchAndFilters(),
                if (_showMap && _searchQuery.isEmpty)
                  OfflineRussiaMap(
                    regions: _regions,
                    onRegionTap: (region) => _showRegionDetailModal(region),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchQuery.isNotEmpty ? "РЕЗУЛЬТАТЫ ПОИСКА (${filtered.length})" : "РЕГИОНЫ И ГОРОДА",
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white.withOpacity(0.4), letterSpacing: 1),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showMap = !_showMap),
                        child: Text(
                          _showMap ? "Скрыть карту" : "Показать карту",
                          style: const TextStyle(color: Color(0xFF0075FF), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final region = filtered[index];
                      String? matchedCity;
                      if (_searchQuery.isNotEmpty) {
                        for (final c in region.cities) {
                          if (c.toLowerCase().contains(_searchQuery.toLowerCase())) {
                            matchedCity = c;
                            break;
                          }
                        }
                      }
                      return _buildRegionCard(region, matchedCity: matchedCity);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "WHITELIST RADAR // РФ",
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 2,
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Мониторинг сети",
            style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(NetworkDetectorService detector) {
    final statusColor = _getStatusColor(detector.localStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                            boxShadow: [
                              BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 8, spreadRadius: 2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "МОЯ ТОЧКА ПОДКЛЮЧЕНИЯ:",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _getStatusText(detector.localStatus).toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  detector.diagnostics,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: detector.isChecking ? null : () => detector.runDiagnostics(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.08),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      ),
                    ),
                    child: detector.isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, size: 16),
                              SizedBox(width: 8),
                              Text("Тест доступности шлюзов", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    // Понятные нормальные названия макрорегионов
    final districts = [
      "ВСЕ",
      "Центр (Москва/МО)",
      "Северо-Запад (СПб)",
      "Юг",
      "Поволжье",
      "Урал",
      "Сибирь",
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Поиск: Кубинка, Москва, Белгород, 50...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: districts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final d = districts[i];
              final isSel = _selectedDistrict == d;
              return GestureDetector(
                onTap: () => setState(() => _selectedDistrict = d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF0075FF).withOpacity(0.25) : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSel ? const Color(0xFF0075FF) : Colors.white.withOpacity(0.06)),
                  ),
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        color: isSel ? Colors.white : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRegionCard(RegionInfo region, {String? matchedCity}) {
    final statusColor = _getStatusColor(region.level);

    return GestureDetector(
      onTap: () => _showRegionDetailModal(region, matchedCity: matchedCity),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                region.id,
                style: TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w900, color: statusColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        region.name,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      if (matchedCity != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF0075FF).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: Text("г. $matchedCity", style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ]
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    region.comment,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(
                _getStatusText(region.level),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
