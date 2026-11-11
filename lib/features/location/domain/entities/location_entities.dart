class Country {
  final String code;
  final String nameAr;
  final String nameEn;

  const Country({
    required this.code,
    required this.nameAr,
    required this.nameEn,
  });

  String getLocalizedName(String languageCode) {
    return languageCode == 'ar' ? nameAr : nameEn;
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'nameAr': nameAr,
    'nameEn': nameEn,
  };

  factory Country.fromJson(Map<String, dynamic> json) => Country(
    code: json['code'] as String,
    nameAr: json['nameAr'] as String,
    nameEn: json['nameEn'] as String,
  );
}

class City {
  final String id;
  final String countryCode;
  final String nameAr;
  final String nameEn;
  final double latitude;
  final double longitude;
  final String timezone;

  const City({
    required this.id,
    required this.countryCode,
    required this.nameAr,
    required this.nameEn,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  String getLocalizedName(String languageCode) {
    return languageCode == 'ar' ? nameAr : nameEn;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'countryCode': countryCode,
    'nameAr': nameAr,
    'nameEn': nameEn,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
  };

  factory City.fromJson(Map<String, dynamic> json) => City(
    id: json['id'] as String,
    countryCode: json['countryCode'] as String,
    nameAr: json['nameAr'] as String,
    nameEn: json['nameEn'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    timezone: json['timezone'] as String,
  );
}
