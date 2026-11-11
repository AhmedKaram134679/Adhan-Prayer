import 'package:flutter/foundation.dart';

@immutable
class Reciter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String assetPath;
  final bool isDefault;

  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.assetPath,
    this.isDefault = false,
  });

  String getLocalizedName(String languageCode) {
    return languageCode == 'ar' ? nameAr : nameEn;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameAr': nameAr,
    'nameEn': nameEn,
    'assetPath': assetPath,
    'isDefault': isDefault,
  };

  factory Reciter.fromJson(Map<String, dynamic> json) => Reciter(
    id: json['id'] as String,
    nameAr: json['nameAr'] as String,
    nameEn: json['nameEn'] as String,
    assetPath: json['assetPath'] as String,
    isDefault: json['isDefault'] as bool? ?? false,
  );
}
