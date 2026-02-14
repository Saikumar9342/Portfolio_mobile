class Language {
  final String code;
  final String name;
  final String? flag;
  final bool isDefault;

  Language({
    required this.code,
    required this.name,
    this.flag,
    this.isDefault = false,
  });

  factory Language.fromMap(Map<String, dynamic> map, String id) {
    return Language(
      code: id,
      name: map['name'] ?? '',
      flag: map['flag'],
      isDefault: map['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'flag': flag,
      'isDefault': isDefault,
    };
  }
}
