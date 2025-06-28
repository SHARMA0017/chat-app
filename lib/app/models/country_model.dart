class CountryModel {
  final String name;
  final String code;
  final String flag;
  final String dialCode;

  CountryModel({
    required this.name,
    required this.code,
    required this.flag,
    required this.dialCode,
  });

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    // Extract country name
    String name = '';
    if (json['name'] != null) {
      if (json['name']['common'] != null) {
        name = json['name']['common'];
      } else if (json['name']['official'] != null) {
        name = json['name']['official'];
      }
    }

    // Extract country code
    String code = json['cca2'] ?? '';

    // Extract flag emoji
    String flag = json['flag'] ?? '';

    // Extract dial code
    String dialCode = '';
    if (json['idd'] != null) {
      String root = json['idd']['root'] ?? '';
      List<dynamic> suffixes = json['idd']['suffixes'] ?? [];
      if (root.isNotEmpty && suffixes.isNotEmpty) {
        dialCode = root + suffixes[0].toString();
      }
    }

    return CountryModel(
      name: name,
      code: code,
      flag: flag,
      dialCode: dialCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'flag': flag,
      'dialCode': dialCode,
    };
  }

  @override
  String toString() {
    return '$flag $name ($dialCode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CountryModel && other.code == code;
  }

  @override
  int get hashCode => code.hashCode;
}
