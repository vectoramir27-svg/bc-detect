import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/region_status.dart';

class NetworkDetectorService extends ChangeNotifier {
  RestrictionLevel _localStatus = RestrictionLevel.normal;
  bool _isChecking = false;
  String _diagnostics = "Готов к мониторингу";

  RestrictionLevel get localStatus => _localStatus;
  bool get isChecking => _isChecking;
  String get diagnostics => _diagnostics;

  Future<void> runDiagnostics() async {
    _isChecking = true;
    _diagnostics = "Тестирование шлюзов...";
    notifyListeners();

    bool openNetAlive = false;
    bool whitelistAlive = false;

    // 1. Проверка открытого интернета (внешний чекпоинт)
    try {
      final response = await http
          .get(Uri.parse('https://connectivitycheck.gstatic.com/generate_204'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 204 || response.statusCode == 200) {
        openNetAlive = true;
      }
    } catch (_) {
      openNetAlive = false;
    }

    // 2. Проверка узла из официального пула белых списков РФ
    try {
      final response = await http
          .head(Uri.parse('https://esia.gosuslugi.ru'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode > 0) {
        whitelistAlive = true;
      }
    } catch (_) {
      whitelistAlive = false;
    }

    // Анализ изоляции трафика
    if (openNetAlive) {
      _localStatus = RestrictionLevel.normal;
      _diagnostics = "Полный доступ: Ограничений не обнаружено";
    } else if (!openNetAlive && whitelistAlive) {
      _localStatus = RestrictionLevel.whitelistActive;
      _diagnostics = "Внимание: Трафик изолирован! Активен режим белых списков.";
    } else {
      _localStatus = RestrictionLevel.fullBlackout;
      _diagnostics = "Полный блэкаут или отсутствие базовой сотовой связи";
    }

    _isChecking = false;
    notifyListeners();
  }
}