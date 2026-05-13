class LevelModel {
  final String key;
  final String label;
  final int minCredits;
  final String color;
  final String? icon;

  LevelModel({
    required this.key,
    required this.label,
    required this.minCredits,
    required this.color,
    this.icon,
  });

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      key: json['key'],
      label: json['label'],
      minCredits: json['min_credits'] ?? json['minCredits'] ?? 0,
      color: json['color'] ?? '#808080',
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'min_credits': minCredits,
      'color': color,
      'icon': icon,
    };
  }
}
