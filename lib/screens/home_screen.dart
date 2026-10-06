import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/region_status.dart';
import '../services/detector_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<RegionInfo> _regions = [
    RegionInfo(id: "77", name: "Москва и МО", federalDistrict: "ЦФО", level: RestrictionLevel.normal, lastChecked: DateTime.now(), comment: "Штатная работа"),
    RegionInfo(id: "78", name: "Санкт-Петербург и ЛО", federalDistrict: "СЗФО", level: RestrictionLevel.normal, lastChecked: DateTime.now(), comment: "Штатная работа"),
    RegionInfo(id: "31", name: "Белгородская область", federalDistrict: "ЦФО", level: RestrictionLevel.whitelistActive, lastChecked: DateTime.now(), comment: "Действуют локальные фильтры ТСПУ"),
    RegionInfo(id: "36", name: "Воронежская область", federalDistrict: "ЦФО", level: RestrictionLevel.warning, lastChecked: DateTime.now(), comment: "Периодические сбои внешних шлюзов"),
    RegionInfo(id: "23", name: "Краснодарский край", federalDistrict: "ЮФО", level: RestrictionLevel.normal, lastChecked: DateTime.now(), comment: "Штатная работа"),
    RegionInfo(id: "16", name: "Республика Татарстан", federalDistrict: "ПФО", level: RestrictionLevel.normal, lastChecked: DateTime.now(), comment: "Штатная работа"),
    RegionInfo(id: "54", name: "Новосибирская область", federalDistrict: "СФО", level: RestrictionLevel.normal, lastChecked: DateTime.now(), comment: "Штатная работа"),
    RegionInfo(id: "66", name: "Свердловская область", federalDistrict: "УФО", level: RestrictionLevel.normal, lastChecked: DateTime.now(), comment: "Штатная работа"),
  ];

  String _searchQuery = "";

  Color _getStatusColor(RestrictionLevel level) {
    switch (level) {
      case RestrictionLevel.normal:
        return const Color(0xFF00FFA3);
      case RestrictionLevel.warning:
        return const Color(0xFFFFB800);
      case RestrictionLevel.whitelistActive:
        return const Color(0xFFFF3366);
      case RestrictionLevel.fullBlackout:
        return const Color(0xFF7000FF);
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

  @override
  Widget build(BuildContext context) {
    final detector = Provider.of<NetworkDetectorService>(context);

    final filteredRegions = _regions
        .where((r) => r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

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
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0075FF).withOpacity(0.12),
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
                _buildSearchBar(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: filteredRegions.length,
                    itemBuilder: (context, index) {
                      return _buildRegionCard(filteredRegions[index]);
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "NETMONITOR // РФ",
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
                "Статус изоляции",
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white70, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(NetworkDetectorService detector) {
    final statusColor = _getStatusColor(detector.localStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
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
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                            boxShadow: [
                              BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 2),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "МОЙ РЕГИОН:",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _getStatusText(detector.localStatus).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  detector.diagnostics,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: detector.isChecking ? null : () => detector.runDiagnostics(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.08),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                    ),
                    child: detector.isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, size: 18),
                              SizedBox(width: 8),
                              Text("Запустить диагностику сети", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: TextField(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: "Поиск региона или города...",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildRegionCard(RegionInfo region) {
    final statusColor = _getStatusColor(region.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              region.id,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  region.comment,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getStatusText(region.level),
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}