enum RestrictionLevel { normal, warning, whitelistActive, fullBlackout }

class RegionInfo {
  final String id;
  final String name;
  final String shortCode;
  final String federalDistrict;
  final double latitude;
  final double longitude;
  RestrictionLevel level;
  DateTime lastChecked;
  String comment;
  int reportsCount24h;
  final List<String> cities;

  RegionInfo({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.federalDistrict,
    required this.latitude,
    required this.longitude,
    this.level = RestrictionLevel.normal,
    required this.lastChecked,
    this.comment = "Сеть работает штатно",
    this.reportsCount24h = 0,
    this.cities = const [],
  });
}
