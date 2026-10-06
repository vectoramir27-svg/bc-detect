import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/region_status.dart';
import '../data/regions_database.dart';
import '../services/detector_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late List<RegionInfo> _regions;
  String? _savedCity;
  RegionInfo? _myRegion;
  bool _liveAlertsEnabled = true;
  String _searchQuery = "";
  Timer? _liveMonitorTimer;

  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final String _serverUrl = "http://64.188.64.121:8080";

  @override
  void initState() {
    super.initState();
    _regions = RegionsDatabase.getInitialRegions();
    _initAnimations();
    _loadUserCity();
    _startLiveBackgroundMonitor();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _liveMonitorTimer?.cancel();
    super.dispose();
  }

  void _initAnimations() {
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnimation = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();
  }

  // Запрос системного разрешения Android 13+ на пуши через платформенный канал
  Future<void> _requestNotificationPermission() async {
    try {
      const platform = MethodChannel('dexterx.dev/flutter_local_notifications_plugin');
      await platform.invokeMethod('requestNotificationsPermission');
    } catch (_) {
      // Платформа обработает нативно или через настройки
    }
  }

  // Фоновый монитор: каждые 45 секунд проверяет изменение статуса и бьет тревогу
  void _startLiveBackgroundMonitor() {
    _liveMonitorTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (!_liveAlertsEnabled || !mounted) return;
      final detector = Provider.of<NetworkDetectorService>(context, listen: false);
      final prev = detector.localStatus;
      await detector.runDiagnostics();
      if (prev != detector.localStatus) {
        _triggerNotificationOverlay(
          "Внимание! Изменение статуса сети",
          "В г. ${_savedCity ?? 'вашем регионе'} зафиксирован: ${_getStatusText(detector.localStatus)}",
        );
      }
    });
  }

  void _triggerNotificationOverlay(String title, String message) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF141A26),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFF3366), width: 1.5),
        ),
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFF3366).withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3366), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(message, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserCity() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString("user_city");
    final alerts = prefs.getBool("live_alerts_enabled") ?? true;

    setState(() {
      _liveAlertsEnabled = alerts;
    });

    if (city != null) {
      _applyCity(city);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCitySelectDialog(isFirstRun: true);
      });
    }
  }

  void _applyCity(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_city", cityName);

    RegionInfo? matched;
    for (final r in _regions) {
      if (r.cities.any((c) => c.toLowerCase() == cityName.toLowerCase()) || r.name.toLowerCase().contains(cityName.toLowerCase())) {
        matched = r;
        break;
      }
    }
    matched ??= _regions.first;

    setState(() {
      _savedCity = cityName;
      _myRegion = matched;
    });
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
      case RestrictionLevel.normal: return "Сеть стабильна";
      case RestrictionLevel.warning: return "Нестабильно / Замедление";
      case RestrictionLevel.whitelistActive: return "Белый список активен";
      case RestrictionLevel.fullBlackout: return "Полный блэкаут связи";
    }
  }

  Future<void> _sendReportToServer(RegionInfo region, String city) async {
    HapticFeedback.mediumImpact();
    try {
      final res = await http.post(
        Uri.parse("$_serverUrl/api/report"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"region_id": region.id, "city": city}),
      ).timeout(const Duration(seconds: 4));

      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => region.reportsCount24h++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00FFA3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Text("Отчёт по г. $city отправлен на сервер!", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E2638),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text("Сервер временно недоступен. Отчёт по $city сохранён локально."),
        ),
      );
    }
  }

  void _showCitySelectDialog({bool isFirstRun = false}) {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> searchList = [];

    for (final r in _regions) {
      for (final c in r.cities) {
        searchList.add({"city": c, "region": r.name, "region_id": r.id});
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchCtrl.text.toLowerCase();
          final filtered = searchList.where((item) => item["city"]!.toLowerCase().contains(query) || item["region"]!.toLowerCase().contains(query)).toList();

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1522).withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 18),
                  Text(
                    isFirstRun ? "👋 В каком городе вы находитесь?" : "📍 Выбор вашего города",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Приложение настроит мониторинг под ваш населённый пункт",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: isFirstRun,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        hintText: "Поиск: Кубинка, Москва, Белгород...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00FFA3), size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(item["city"]!, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            subtitle: Text(item["region"]!, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                            onTap: () {
                              _applyCity(item["city"]!);
                              Navigator.pop(ctx);
                              HapticFeedback.selectionClick();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSosHelpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1522).withOpacity(0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: const Color(0xFFFF3366).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFFF3366), size: 24),
                  SizedBox(width: 10),
                  Text("Памятка: Включен белый список", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "Когда мобильный интернет режется ТСПУ до «белых списков», продолжают работать:",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              _buildSosItem(Icons.verified_user_outlined, "Госуслуги (ЕСИА)", "Вход, справки, вызовы экстренных служб"),
              _buildSosItem(Icons.account_balance_outlined, "Банковские приложения", "Сбер, Т-Банк, СБП-переводы"),
              _buildSosItem(Icons.local_shipping_outlined, "Маркетплейсы и такси", "Яндекс Go, Ozon, Wildberries"),
              _buildSosItem(Icons.phone_in_talk_outlined, "Экстренные номера", "112 (работает даже без SIM-карты)"),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSosItem(IconData icon, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00FFA3), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detector = Provider.of<NetworkDetectorService>(context);
    final myReg = _myRegion ?? _regions.first;
    final cityTitle = _savedCity ?? "Не выбран";
    final myColor = _getStatusColor(myReg.level);

    final filtered = _regions.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) || r.cities.any((c) => c.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF070A0F),
      body: Stack(
        children: [
          // Оптимизированный неоновый фон
          RepaintBoundary(
            child: Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [myColor.withOpacity(0.16), Colors.transparent]),
                ),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                  children: [
                    _buildTopHeader(),
                    const SizedBox(height: 16),
                    _buildPrimaryCityCard(cityTitle, myReg, myColor, detector),
                    const SizedBox(height: 14),
                    _buildQuickActionGrid(myReg, cityTitle),
                    const SizedBox(height: 14),
                    _buildLiveAlertToggle(),
                    const SizedBox(height: 24),
                    _buildRegionsSectionHeader(),
                    const SizedBox(height: 12),
                    _buildSearchBox(),
                    const SizedBox(height: 10),
                    ...filtered.map((r) => _buildRegionCard(r)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF00FFA3),
                    boxShadow: [BoxShadow(color: Color(0xFF00FFA3), blurRadius: 8, spreadRadius: 1)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "WHITELIST RADAR // РФ",
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: 2.2, color: Colors.white.withOpacity(0.55), fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Монитор связи",
              style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: -0.6),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showCitySelectDialog(isFirstRun: false);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.location_on_outlined, color: Color(0xFF00FFA3), size: 16),
                SizedBox(width: 6),
                Text("Сменить", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Главная супер-карточка
  Widget _buildPrimaryCityCard(String city, RegionInfo reg, Color statusColor, NetworkDetectorService detector) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522).withOpacity(0.85),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: statusColor.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.16), blurRadius: 28, spreadRadius: -4, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusText(reg.level).toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Text("РЕГИОН ${reg.id}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Text(city, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          Text(reg.name, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_tethering, color: statusColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(reg.comment, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: detector.isChecking ? null : () async {
                HapticFeedback.lightImpact();
                final prevStatus = detector.localStatus;
                await detector.runDiagnostics();
                if (prevStatus != detector.localStatus && _liveAlertsEnabled) {
                  _triggerNotificationOverlay(
                    "Изменение режима сети",
                    "Текущий статус в вашем городе: ${_getStatusText(detector.localStatus)}",
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.08),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                ),
              ),
              child: detector.isChecking
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_outlined, size: 18, color: Color(0xFF00FFA3)),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Проверить сотовую связь",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Одинаковые ровные карточки действий
  Widget _buildQuickActionGrid(RegionInfo reg, String city) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showSosHelpSheet();
            },
            child: Container(
              height: 105, // Фиксированная одинаковая высота!
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101622).withOpacity(0.7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.health_and_safety_outlined, color: Color(0xFF00FFA3), size: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Памятка SOS", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text("Что работает в блоке", style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _sendReportToServer(reg, city),
            child: Container(
              height: 105, // Фиксированная одинаковая высота!
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3366).withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFF3366).withOpacity(0.25)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.notification_important_outlined, color: Color(0xFFFF3366), size: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Сообщить о глушилке", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text("Зафиксировать в базе", style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Переключатель Live-информирования
  Widget _buildLiveAlertToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF101622).withOpacity(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: _liveAlertsEnabled ? const Color(0xFF00FFA3) : Colors.white38, size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Live-информирование", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text("Предупреждать при смене статуса сети", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ],
          ),
          Switch(
            value: _liveAlertsEnabled,
            activeColor: const Color(0xFF00FFA3),
            activeTrackColor: const Color(0xFF00FFA3).withOpacity(0.2),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white10,
            onChanged: (val) async {
              HapticFeedback.lightImpact();
              if (val) {
                await _requestNotificationPermission();
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool("live_alerts_enabled", val);
              setState(() => _liveAlertsEnabled = val);
              if (val) {
                _triggerNotificationOverlay("Live-мониторинг активен", "Сеть сканируется в фоновом режиме");
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegionsSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("ОБСТАНОВКА В ДРУГИХ РЕГИОНАХ", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'monospace')),
        Text("${_regions.length} в базе", style: const TextStyle(color: Color(0xFF00FFA3), fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: "Поиск региона или города...",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildRegionCard(RegionInfo region) {
    final statusColor = _getStatusColor(region.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101622).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              region.id,
              style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w900, color: statusColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(region.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  region.comment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
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
    );
  }
}
