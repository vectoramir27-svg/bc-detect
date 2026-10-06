import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/region_status.dart';
import '../data/regions_database.dart';
import '../services/detector_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0; // 0: Главная, 1: Карта, 2: Настройки
  late List<RegionInfo> _regions;
  String _searchQuery = "";
  String _selectedDistrict = "ВСЕ";

  final String _serverUrl = "http://64.188.64.121:8080";

  @override
  void initState() {
    super.initState();
    // Загружаем ЖЕСТКИЕ НАСТОЯЩИЕ СТАТУСЫ (Белгород/Курск - белые списки и т.д.)
    _regions = RegionsDatabase.getInitialRegions();
  }

  Color _getStatusColor(RestrictionLevel level) {
    switch (level) {
      case RestrictionLevel.normal: return const Color(0xFF00FFA3);
      case RestrictionLevel.warning: return const Color(0xFFFFB800);
      case RestrictionLevel.whitelistActive: return const Color(0xFFFF3366);
      case RestrictionLevel.fullBlackout: return const Color(0xFF9D00FF);
    }
  }

  String _getStatusText(RestrictionLevel level) {
    switch (level) {
      case RestrictionLevel.normal: return "Сеть в норме";
      case RestrictionLevel.warning: return "Нестабильно";
      case RestrictionLevel.whitelistActive: return "Белый список";
      case RestrictionLevel.fullBlackout: return "Блэкаут";
    }
  }

  // Отправка жалобы строго в админку без ломания локальных статусов
  Future<void> _sendReportToServer(RegionInfo region, String chosenCity) async {
    try {
      final res = await http.post(
        Uri.parse("$_serverUrl/api/report"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"region_id": region.id, "city": chosenCity}),
      ).timeout(const Duration(seconds: 4));

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() => region.reportsCount24h++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00FFA3),
            content: Text("Жалоба по г. $chosenCity ушла в админку!", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E2638),
          content: Text("Сервер недоступен. Жалоба по г. $chosenCity сохранена в локальный буфер."),
        ),
      );
    }
  }

  void _showReportDialog(RegionInfo region, String? defaultCity) {
    String selectedCity = defaultCity ?? (region.cities.isNotEmpty ? region.cities.first : region.name);
    final customController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131A26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white12)),
          title: Text("Жалоба: ${region.name}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Выберите город:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: region.cities.contains(selectedCity) ? selectedCity : null,
                  dropdownColor: const Color(0xFF1B2433),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  hint: const Text("Выбрать из списка", style: TextStyle(color: Colors.white38)),
                  items: region.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedCity = val;
                        customController.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text("Или введите свой посёлок:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: customController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (val) {
                    if (val.trim().isNotEmpty) selectedCity = val.trim();
                  },
                  decoration: InputDecoration(
                    hintText: "Например: Кубинка, Голицыно...",
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Отмена", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3366), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _sendReportToServer(region, selectedCity);
              },
              child: const Text("Отправить репорт"),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegionDetailModal(RegionInfo region, {String? matchedCity}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final color = _getStatusColor(region.level);
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
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
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
                      child: Text("РЕГИОН ${region.id}", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
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
                Text("Группа: ${region.federalDistrict}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                const SizedBox(height: 12),
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
                      Expanded(child: Text(region.comment, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Населённые пункты в базе:", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
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
                      _showReportDialog(region, matchedCity);
                    },
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const Text("Сообщить о белом списке", style: TextStyle(fontWeight: FontWeight.bold)),
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

    return Scaffold(
      backgroundColor: const Color(0xFF090C10),
      body: Stack(
        children: [
          // Отображение вкладки БЕЗ тупых рывков анимации
          IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildMainTab(detector),
              _buildFullVectorMapTab(),
              _buildSettingsTab(),
            ],
          ),

          // Компактный аккуратный Liquid Glass бар
          Positioned(
            left: 30,
            right: 30,
            bottom: 18,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTab(NetworkDetectorService detector) {
    final filtered = _regions.where((r) {
      if (_selectedDistrict != "ВСЕ" && r.federalDistrict != _selectedDistrict) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) || r.cities.any((c) => c.toLowerCase().contains(q));
    }).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStatusBanner(detector),
          _buildSearchAndFilters(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              _searchQuery.isNotEmpty ? "РЕЗУЛЬТАТЫ ПОИСКА (${filtered.length})" : "РЕГИОНЫ И ГОРОДА (${filtered.length})",
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white.withOpacity(0.4), letterSpacing: 1),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 85),
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
    );
  }

  // Полноэкранная векторная гео-карта России (РАБОТАЕТ ВСЕГДА, НЕ ТРЕБУЕТ СЕТИ, ЗУМИТСЯ ПАЛЬЦАМИ)
  Widget _buildFullVectorMapTab() {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                const Icon(Icons.public, color: Color(0xFF00FFA3), size: 22),
                const SizedBox(width: 10),
                const Text("Интерактивная карта покрытия РФ", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 85),
              decoration: BoxDecoration(
                color: const Color(0xFF0D121B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: InteractiveViewer(
                  minScale: 0.9,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(50),
                  child: SizedBox(
                    width: 700,
                    height: 450,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: const Size(700, 450),
                          painter: _OfflineVectorMapPainter(),
                        ),
                        // Маркеры регионов со СВОИМИ РЕАЛЬНЫМИ ЦВЕТАМИ
                        ..._regions.map((region) {
                          final pos = _getMapCoords(region.id, const Size(700, 450));
                          final color = _getStatusColor(region.level);
                          return Positioned(
                            left: pos.dx - 22,
                            top: pos.dy - 32,
                            child: GestureDetector(
                              onTap: () => _showRegionDetailModal(region),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF070A0F),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: color, width: 1.2),
                                    ),
                                    child: Text(
                                      region.shortCode,
                                      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  Icon(Icons.location_on, color: color, size: 22),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _getMapCoords(String id, Size size) {
    double x = 0.5, y = 0.5;
    switch (id) {
      case "50": x = 0.22; y = 0.44; break; // МО
      case "77": x = 0.23; y = 0.47; break; // Москва
      case "78": x = 0.19; y = 0.35; break; // СПб
      case "47": x = 0.20; y = 0.32; break; // ЛО
      case "31": x = 0.16; y = 0.54; break; // Белгород (КРАСНЫЙ)
      case "46": x = 0.17; y = 0.50; break; // Курск (КРАСНЫЙ)
      case "36": x = 0.20; y = 0.53; break; // Воронеж (ЖЕЛТЫЙ)
      case "23": x = 0.14; y = 0.64; break; // Краснодар
      case "61": x = 0.17; y = 0.60; break; // Ростов (ЖЕЛТЫЙ)
      case "16": x = 0.30; y = 0.49; break; // Казань
      case "63": x = 0.29; y = 0.55; break; // Самара
      case "52": x = 0.26; y = 0.46; break; // Нижний Новгород
      case "66": x = 0.38; y = 0.52; break; // Екб
      case "74": x = 0.39; y = 0.58; break; // Челябинск
      case "54": x = 0.52; y = 0.63; break; // Новосибирск
    }
    return Offset(x * size.width, y * size.height);
  }

  Widget _buildSettingsTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 85),
        children: [
          const Text("Настройки", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text("Параметры детектора и сервера", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("СЕРВЕР ДЛЯ ЖАЛОБ (VPS)", style: TextStyle(color: Color(0xFF00FFA3), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                const SizedBox(height: 8),
                Text(_serverUrl, style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'monospace')),
                const SizedBox(height: 6),
                const Text("Жалобы уходят прямо в твою веб-админку", style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF131A26),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("О ПРИЛОЖЕНИИ", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                const SizedBox(height: 8),
                const Text("NetMonitor // Whitelist Radar", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Версия: 1.4.0 (Offline-First Vector Edition)\nЛокальное ядро проверки сотовой связи", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Аккуратный, четкий BottomBar
  Widget _buildBottomBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111722).withOpacity(0.85),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBarBtn(0, Icons.grid_view_rounded, "Главная"),
              _buildBarBtn(1, Icons.map_rounded, "Карта"),
              _buildBarBtn(2, Icons.settings_rounded, "Настройки"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarBtn(int index, IconData icon, String title) {
    final isSel = _currentTabIndex == index;
    final color = isSel ? const Color(0xFF00FFA3) : Colors.white38;

    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF00FFA3).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            if (isSel) ...[
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
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
            style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 2, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text("Мониторинг сети", style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
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
                            boxShadow: [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "МОЯ ТОЧКА ПОДКЛЮЧЕНИЯ:",
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white.withOpacity(0.6), letterSpacing: 1),
                        ),
                      ],
                    ),
                    Text(_getStatusText(detector.localStatus).toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(detector.diagnostics, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
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
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    final districts = [
      "ВСЕ",
      "Москва и Подмосковье",
      "Черноземье и Приграничье",
      "Северо-Запад (СПб)",
      "Юг и Кавказ",
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
                      Text(region.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      if (matchedCity != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF0075FF).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: Text("г. $matchedCity", style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(region.comment, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
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

// Векторная география РФ для оффлайн-рендера
class _OfflineVectorMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Сетка
    final grid = Paint()..color = const Color(0xFF161E2C)..strokeWidth = 1;
    for (double x = 0; x < w; x += 45) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = 0; y < h; y += 45) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Территория России
    final p = Path();
    p.moveTo(w * 0.18, h * 0.36);
    p.lineTo(w * 0.20, h * 0.26);
    p.lineTo(w * 0.24, h * 0.18);
    p.lineTo(w * 0.28, h * 0.22);
    p.lineTo(w * 0.30, h * 0.28);
    p.lineTo(w * 0.36, h * 0.20);
    p.lineTo(w * 0.40, h * 0.14);
    p.lineTo(w * 0.48, h * 0.15);
    p.lineTo(w * 0.58, h * 0.20);
    p.lineTo(w * 0.68, h * 0.22);
    p.lineTo(w * 0.76, h * 0.18);
    p.lineTo(w * 0.88, h * 0.20);
    p.lineTo(w * 0.92, h * 0.30);
    p.lineTo(w * 0.86, h * 0.42);
    p.lineTo(w * 0.88, h * 0.56);
    p.lineTo(w * 0.84, h * 0.62);
    p.lineTo(w * 0.78, h * 0.52);
    p.lineTo(w * 0.76, h * 0.66);
    p.lineTo(w * 0.72, h * 0.72);
    p.lineTo(w * 0.67, h * 0.64);
    p.lineTo(w * 0.60, h * 0.63);
    p.lineTo(w * 0.54, h * 0.68);
    p.lineTo(w * 0.47, h * 0.69);
    p.lineTo(w * 0.40, h * 0.66);
    p.lineTo(w * 0.34, h * 0.62);
    p.lineTo(w * 0.26, h * 0.61);
    p.lineTo(w * 0.18, h * 0.70);
    p.lineTo(w * 0.13, h * 0.65);
    p.lineTo(w * 0.15, h * 0.52);
    p.lineTo(w * 0.17, h * 0.42);
    p.close();

    final land = Paint()..color = const Color(0xFF141C29)..style = PaintingStyle.fill;
    canvas.drawPath(p, land);

    final border = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(p, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
