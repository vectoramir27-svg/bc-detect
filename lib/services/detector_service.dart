import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/region_status.dart';

class ServiceProbeResult {
  final String name;
  final String url;
  final bool isWhitelistExpected;
  bool isReachable;
  int? latencyMs;

  ServiceProbeResult({
    required this.name,
    required this.url,
    required this.isWhitelistExpected,
    this.isReachable = false,
    this.latencyMs,
  });
}

class NetworkDetectorService extends ChangeNotifier {
  RestrictionLevel _localStatus = RestrictionLevel.normal;
  bool _isChecking = false;
  String _diagnostics = "Готов к мониторингу";

  final List<ServiceProbeResult> _probes = [
    ServiceProbeResult(name: "Госуслуги (ЕСИА)", url: "https://esia.gosuslugi.ru", isWhitelistExpected: true),
    ServiceProbeResult(name: "ВКонтакте (VK API)", url: "https://vk.com", isWhitelistExpected: true),
    ServiceProbeResult(name: "Яндекс Шлюз", url: "https://ya.ru", isWhitelistExpected: true),
    ServiceProbeResult(name: "Внешний DNS (Google)", url: "https://connectivitycheck.gstatic.com/generate_204", isWhitelistExpected: false),
    ServiceProbeResult(name: "Cloudflare Edge", url: "https://1.1.1.1", isWhitelistExpected: false),
    ServiceProbeResult(name: "Telegram Core API", url: "https://api.telegram.org", isWhitelistExpected: false),
  ];

  RestrictionLevel get localStatus => _localStatus;
  bool get isChecking => _isChecking;
  String get diagnostics => _diagnostics;
  List<ServiceProbeResult> get probes => _probes;

  Future<void> runDiagnostics() async {
    _isChecking = true;
    _diagnostics = "Опрос контрольных узлов связи...";
    notifyListeners();

    int whitelistedAlive = 0;
    int externalAlive = 0;

    for (final probe in _probes) {
      final sw = Stopwatch()..start();
      try {
        final res = await http.head(Uri.parse(probe.url)).timeout(const Duration(seconds: 3));
        sw.stop();
        probe.isReachable = res.statusCode > 0;
        probe.latencyMs = sw.elapsedMilliseconds;
      } catch (_) {
        sw.stop();
        probe.isReachable = false;
        probe.latencyMs = null;
      }

      if (probe.isReachable) {
        if (probe.isWhitelistExpected) {
          whitelistedAlive++;
        } else {
          externalAlive++;
        }
      }
    }

    if (externalAlive >= 2) {
      _localStatus = RestrictionLevel.normal;
      _diagnostics = "Полный доступ: Все внешние шлюзы открыты";
    } else if (externalAlive == 0 && whitelistedAlive >= 1) {
      _localStatus = RestrictionLevel.whitelistActive;
      _diagnostics = "Внимание: Зафиксирован режим белых списков! Внешняя сеть заблокирована.";
    } else if (externalAlive == 1) {
      _localStatus = RestrictionLevel.warning;
      _diagnostics = "Частичная деградация сети: сбои внешних маршрутов";
    } else {
      _localStatus = RestrictionLevel.fullBlackout;
      _diagnostics = "Полная изоляция / потеря несущей сотовой сети";
    }

    _isChecking = false;
    notifyListeners();
  }
}
