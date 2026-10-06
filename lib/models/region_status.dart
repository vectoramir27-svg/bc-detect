enum RestrictionLevel { normal, warning, whitelistActive, fullBlackout }

class CityItem {
  final String name;
  final String regionId;
  final String regionName;

  const CityItem({
    required this.name,
    required this.regionId,
    required this.regionName,
  });
}

class RegionInfo {
  final String id;
  final String name;
  final String shortCode;
  final String federalDistrict;
  RestrictionLevel level;
  DateTime lastChecked;
  String comment;
  final List<String> cities;

  RegionInfo({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.federalDistrict,
    this.level = RestrictionLevel.normal,
    required this.lastChecked,
    this.comment = "Сеть работает штатно",
    this.cities = const [],
  });
}
