enum RestrictionLevel { normal, warning, whitelistActive, fullBlackout }

class RegionInfo {
  final String id;
  final String name;
  final String federalDistrict;
  RestrictionLevel level;
  DateTime lastChecked;
  String comment;

  RegionInfo({
    required this.id,
    required this.name,
    required this.federalDistrict,
    this.level = RestrictionLevel.normal,
    required this.lastChecked,
    this.comment = "Сеть стабильна",
  });
}