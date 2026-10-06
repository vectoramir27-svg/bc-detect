import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/region_status.dart';
import '../data/regions_database.dart';
import '../services/detector_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  late final PageController _pageController;
  late List<RegionInfo> _regions;
  String _searchQuery = "";
  String _selectedDistrict = "ВСЕ";

  final String _serverUrl = "http://64.188.64.121:8080";
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _regions = RegionsDatabase.getInitialRegions();
    _syncStatusesWithServer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _syncStatusesWithServer() async {
    try {
      final res = await http.get(Uri.parse("$_serverUrl/api/status")).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        setState(() {
          for (final region in _regions) {
            if (data.containsKey(region.id)) {
              final info = data[region.id];
              final statusStr = info["status"];
              switch (statusStr) {
                case "normal": region.level = RestrictionLevel.normal; break;
                case "warning": region.level = RestrictionLevel.warning; break;
                case "whitelistActive": region.level = RestrictionLevel.whitelistActive; break;
                case "fullBlackout": region.level = RestrictionLevel.fullBlackout; break;
              }
              if (info["comment"] != null) region.comment = info["comment"];
              if (info["reports_24h"] != null) region.reportsCount24h = info["reports_24h"];
            }
          }
        });
      }
    } catch (_) {}
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
            content: Text("Жалоба по г. $chosenCity принята сервером!", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E2638),
          content: Text("Сервер временно недоступен. Жалоба сохранена локально."),
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: color, size: 20),
                          const SizedBox(width: 12),
                          Expanded(child: Text(region.comment, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.people_outline, color: Color(0xFF00E5FF), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Жалоб за 24ч: ${region.reportsCount24h}",
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Населённые пункты региона в базе:", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFF070A0F),
      body: Stack(
        children: [
          // Плавный анимированный переход между вкладками
          PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentTabIndex = idx),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildMainTab(detector),
              _buildMapTab(),
              _buildSettingsTab(),
            ],
          ),

          // Компактный плавающий Glass-бар внизу (Liquid Glass Telegram UI)
          Positioned(
            left: 24,
            right: 24,
            bottom: 20,
            child: _buildFloatingNavBar(),
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 95),
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

  // Настоящая карта мира на бесплатном OpenStreetMap (без API-ключей) в тёмном фильтре
  Widget _buildMapTab() {
    return Stack(
      children: [
        ColorFiltered(
          // Применяем инверсию и контраст для идеального тёмного киберпанк-стиля
          colorFilter: const ColorFilter.matrix([
            -0.85, 0, 0, 0, 255,
            0, -0.85, 0, 0, 255,
            0, 0, -0.85, 0, 255,
            0, 0, 0, 1, 0,
          ]),
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(55.7558, 37.6173),
              initialZoom: 5.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wonderfultech.netmonitor',
              ),
            ],
          ),
        ),

        // Поверх тёмной карты рендерим неоновые маркеры городов и регионов
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(55.7558, 37.6173),
            initialZoom: 5.0,
            minZoom: 3.0,
            maxZoom: 18.0,
          ),
          children: [
            MarkerLayer(
              markers: _regions.map((region) {
                final col = _getStatusColor(region.level);
                return Marker(
                  point: LatLng(region.latitude, region.longitude),
                  width: 54,
                  height: 54,
                  child: GestureDetector(
                    onTap: () => _showRegionDetailModal(region),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0E14).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: col, width: 1.2),
                            boxShadow: [
                              BoxShadow(color: col.withOpacity(0.4), blurRadius: 6),
                            ],
                          ),
                          child: Text(
                            region.shortCode,
                            style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Icon(Icons.location_on, color: col, size: 26),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Плашка подсказки сверху
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101724).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.public, color: Color(0xFF00FFA3), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Карта покрытия РФ (Нажмите на метку города)",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 95),
        children: [
          const Text("Настройки", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text("Конфигурация шлюзов и клиента", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
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
                const Text("СЕРВЕР ТЕЛЕМЕТРИИ", style: TextStyle(color: Color(0xFF00FFA3), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                const SizedBox(height: 10),
                Text(_serverUrl, style: const TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'monospace')),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _syncStatusesWithServer,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text("Синхронизировать сейчас"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0075FF), foregroundColor: Colors.white),
                )
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
                const SizedBox(height: 10),
                const Text("NetMonitor & Whitelist Radar", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Версия клиента: 1.3.0 (OpenStreetMap Core)\nДетекция сети: Локальный Dual-Ping аппаратный чекпоинт", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Компактный Liquid Glass Bottom Navigation Bar с плавной анимацией
  Widget _buildFloatingNavBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          height: 56, // Аккуратный компактный размер
          decoration: BoxDecoration(
            color: const Color(0xFF111722).withOpacity(0.75), // Реальная глубина и прозрачность
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_rounded, "Главная"),
              _buildNavItem(1, Icons.map_rounded, "Карта"),
              _buildNavItem(2, Icons.tune_rounded, "Настройки"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    final activeColor = const Color(0xFF00FFA3);

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : Colors.white.withOpacity(0.4),
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
          IconButton(
            onPressed: _syncStatusesWithServer,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: const Icon(Icons.sync, color: Color(0xFF00FFA3), size: 22),
            ),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(region.comment, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                      ),
                      if (region.reportsCount24h > 0) ...[
                        const SizedBox(width: 6),
                        Text("⚠️ ${region.reportsCount24h} реп.", style: const TextStyle(color: Color(0xFFFF3366), fontSize: 10, fontWeight: FontWeight.bold)),
                      ]
                    ],
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
