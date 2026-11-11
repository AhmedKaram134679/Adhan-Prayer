import 'package:adhan_and_prayer/features/location/domain/entities/location_entities.dart';

class StaticLocationData {
  static const List<Country> countries = [
    Country(code: 'EG', nameAr: 'مصر', nameEn: 'Egypt'),
    Country(code: 'SA', nameAr: 'المملكة العربية السعودية', nameEn: 'Saudi Arabia'),
    Country(code: 'AE', nameAr: 'الإمارات العربية المتحدة', nameEn: 'United Arab Emirates'),
    Country(code: 'KW', nameAr: 'الكويت', nameEn: 'Kuwait'),
    Country(code: 'QA', nameAr: 'قطر', nameEn: 'Qatar'),
    Country(code: 'BH', nameAr: 'البحرين', nameEn: 'Bahrain'),
    Country(code: 'OM', nameAr: 'عُمان', nameEn: 'Oman'),
    Country(code: 'JO', nameAr: 'الأردن', nameEn: 'Jordan'),
    Country(code: 'PS', nameAr: 'فلسطين', nameEn: 'Palestine'),
    Country(code: 'LB', nameAr: 'لبنان', nameEn: 'Lebanon'),
    Country(code: 'SY', nameAr: 'سوريا', nameEn: 'Syria'),
    Country(code: 'IQ', nameAr: 'العراق', nameEn: 'Iraq'),
    Country(code: 'YE', nameAr: 'اليمن', nameEn: 'Yemen'),
    Country(code: 'SD', nameAr: 'السودان', nameEn: 'Sudan'),
    Country(code: 'LY', nameAr: 'ليبيا', nameEn: 'Libya'),
    Country(code: 'TN', nameAr: 'تونس', nameEn: 'Tunisia'),
    Country(code: 'DZ', nameAr: 'الجزائر', nameEn: 'Algeria'),
    Country(code: 'MA', nameAr: 'المغرب', nameEn: 'Morocco'),
    Country(code: 'TR', nameAr: 'تركيا', nameEn: 'Turkey'),
    Country(code: 'GB', nameAr: 'المملكة المتحدة', nameEn: 'United Kingdom'),
    Country(code: 'US', nameAr: 'الولايات المتحدة الأمريكية', nameEn: 'United States'),
    Country(code: 'CA', nameAr: 'كندا', nameEn: 'Canada'),
    Country(code: 'DE', nameAr: 'ألمانيا', nameEn: 'Germany'),
    Country(code: 'FR', nameAr: 'فرنسا', nameEn: 'France'),
    Country(code: 'ID', nameAr: 'إندونيسيا', nameEn: 'Indonesia'),
    Country(code: 'MY', nameAr: 'ماليزيا', nameEn: 'Malaysia'),
    Country(code: 'PK', nameAr: 'باكستان', nameEn: 'Pakistan'),
    Country(code: 'BD', nameAr: 'بنغلاديش', nameEn: 'Bangladesh'),
    Country(code: 'IN', nameAr: 'الهند', nameEn: 'India'),
  ];

  static const List<City> cities = [
    // Egypt
    City(id: 'eg_cairo', countryCode: 'EG', nameAr: 'القاهرة', nameEn: 'Cairo', latitude: 30.0444, longitude: 31.2357, timezone: 'Africa/Cairo'),
    City(id: 'eg_alex', countryCode: 'EG', nameAr: 'الإسكندرية', nameEn: 'Alexandria', latitude: 31.2001, longitude: 29.9187, timezone: 'Africa/Cairo'),
    City(id: 'eg_giza', countryCode: 'EG', nameAr: 'الجيزة', nameEn: 'Giza', latitude: 30.0131, longitude: 31.2089, timezone: 'Africa/Cairo'),
    City(id: 'eg_mansoura', countryCode: 'EG', nameAr: 'المنصورة', nameEn: 'Mansoura', latitude: 31.0409, longitude: 31.3785, timezone: 'Africa/Cairo'),
    City(id: 'eg_tanta', countryCode: 'EG', nameAr: 'طنطا', nameEn: 'Tanta', latitude: 30.7865, longitude: 31.0004, timezone: 'Africa/Cairo'),
    City(id: 'eg_aswan', countryCode: 'EG', nameAr: 'أسوان', nameEn: 'Aswan', latitude: 24.0889, longitude: 32.8998, timezone: 'Africa/Cairo'),
    City(id: 'eg_luxor', countryCode: 'EG', nameAr: 'الأقصر', nameEn: 'Luxor', latitude: 25.6872, longitude: 32.6396, timezone: 'Africa/Cairo'),
    City(id: 'eg_portsaid', countryCode: 'EG', nameAr: 'بورسعيد', nameEn: 'Port Said', latitude: 31.2653, longitude: 32.3019, timezone: 'Africa/Cairo'),
    City(id: 'eg_suez', countryCode: 'EG', nameAr: 'السويس', nameEn: 'Suez', latitude: 29.9668, longitude: 32.5498, timezone: 'Africa/Cairo'),

    // Saudi Arabia
    City(id: 'sa_makkah', countryCode: 'SA', nameAr: 'مكة المكرمة', nameEn: 'Makkah', latitude: 21.3891, longitude: 39.8579, timezone: 'Asia/Riyadh'),
    City(id: 'sa_madinah', countryCode: 'SA', nameAr: 'المدينة المنورة', nameEn: 'Madinah', latitude: 24.5247, longitude: 39.5692, timezone: 'Asia/Riyadh'),
    City(id: 'sa_riyadh', countryCode: 'SA', nameAr: 'الرياض', nameEn: 'Riyadh', latitude: 24.7136, longitude: 46.6753, timezone: 'Asia/Riyadh'),
    City(id: 'sa_jeddah', countryCode: 'SA', nameAr: 'جدة', nameEn: 'Jeddah', latitude: 21.5433, longitude: 39.1728, timezone: 'Asia/Riyadh'),
    City(id: 'sa_dammam', countryCode: 'SA', nameAr: 'الدمام', nameEn: 'Dammam', latitude: 26.4207, longitude: 50.0888, timezone: 'Asia/Riyadh'),
    City(id: 'sa_taif', countryCode: 'SA', nameAr: 'الطائف', nameEn: 'Taif', latitude: 21.4373, longitude: 40.5127, timezone: 'Asia/Riyadh'),
    City(id: 'sa_khobar', countryCode: 'SA', nameAr: 'الخبر', nameEn: 'Khobar', latitude: 26.2172, longitude: 50.1971, timezone: 'Asia/Riyadh'),
    City(id: 'sa_tabuk', countryCode: 'SA', nameAr: 'تبوك', nameEn: 'Tabuk', latitude: 28.3835, longitude: 36.5662, timezone: 'Asia/Riyadh'),
    City(id: 'sa_abha', countryCode: 'SA', nameAr: 'أبها', nameEn: 'Abha', latitude: 18.2164, longitude: 42.5053, timezone: 'Asia/Riyadh'),

    // UAE
    City(id: 'ae_dubai', countryCode: 'AE', nameAr: 'دبي', nameEn: 'Dubai', latitude: 25.2048, longitude: 55.2708, timezone: 'Asia/Dubai'),
    City(id: 'ae_abudhabi', countryCode: 'AE', nameAr: 'أبو ظبي', nameEn: 'Abu Dhabi', latitude: 24.4539, longitude: 54.3773, timezone: 'Asia/Dubai'),
    City(id: 'ae_sharjah', countryCode: 'AE', nameAr: 'الشارقة', nameEn: 'Sharjah', latitude: 25.3463, longitude: 55.4209, timezone: 'Asia/Dubai'),
    City(id: 'ae_ajman', countryCode: 'AE', nameAr: 'عجمان', nameEn: 'Ajman', latitude: 25.4052, longitude: 55.5136, timezone: 'Asia/Dubai'),
    City(id: 'ae_alain', countryCode: 'AE', nameAr: 'العين', nameEn: 'Al Ain', latitude: 24.2075, longitude: 55.7447, timezone: 'Asia/Dubai'),

    // Kuwait
    City(id: 'kw_kuwait', countryCode: 'KW', nameAr: 'مدينة الكويت', nameEn: 'Kuwait City', latitude: 29.3759, longitude: 47.9774, timezone: 'Asia/Kuwait'),
    City(id: 'kw_hawalli', countryCode: 'KW', nameAr: 'حولي', nameEn: 'Hawalli', latitude: 29.3328, longitude: 48.0286, timezone: 'Asia/Kuwait'),

    // Qatar
    City(id: 'qa_doha', countryCode: 'QA', nameAr: 'الدوحة', nameEn: 'Doha', latitude: 25.2854, longitude: 51.5310, timezone: 'Asia/Qatar'),
    City(id: 'qa_rayyan', countryCode: 'QA', nameAr: 'الريان', nameEn: 'Al Rayyan', latitude: 25.2919, longitude: 51.4244, timezone: 'Asia/Qatar'),

    // Bahrain
    City(id: 'bh_manama', countryCode: 'BH', nameAr: 'المنامة', nameEn: 'Manama', latitude: 26.2285, longitude: 50.5860, timezone: 'Asia/Bahrain'),

    // Oman
    City(id: 'om_muscat', countryCode: 'OM', nameAr: 'مسقط', nameEn: 'Muscat', latitude: 23.5859, longitude: 58.4059, timezone: 'Asia/Muscat'),
    City(id: 'om_salalah', countryCode: 'OM', nameAr: 'صلالة', nameEn: 'Salalah', latitude: 17.0151, longitude: 54.0924, timezone: 'Asia/Muscat'),

    // Jordan
    City(id: 'jo_amman', countryCode: 'JO', nameAr: 'عَمّان', nameEn: 'Amman', latitude: 31.9454, longitude: 35.9284, timezone: 'Asia/Amman'),
    City(id: 'jo_zarqa', countryCode: 'JO', nameAr: 'الزرقاء', nameEn: 'Zarqa', latitude: 32.0728, longitude: 36.0880, timezone: 'Asia/Amman'),
    City(id: 'jo_irbid', countryCode: 'JO', nameAr: 'إربد', nameEn: 'Irbid', latitude: 32.5568, longitude: 35.8469, timezone: 'Asia/Amman'),

    // Palestine
    City(id: 'ps_jerusalem', countryCode: 'PS', nameAr: 'القدس الشريف', nameEn: 'Jerusalem', latitude: 31.7683, longitude: 35.2137, timezone: 'Asia/Jerusalem'),
    City(id: 'ps_gaza', countryCode: 'PS', nameAr: 'غزة', nameEn: 'Gaza', latitude: 31.5017, longitude: 34.4668, timezone: 'Asia/Gaza'),
    City(id: 'ps_ramallah', countryCode: 'PS', nameAr: 'رام الله', nameEn: 'Ramallah', latitude: 31.9038, longitude: 35.2034, timezone: 'Asia/Hebron'),
    City(id: 'ps_nablus', countryCode: 'PS', nameAr: 'نابلس', nameEn: 'Nablus', latitude: 32.2227, longitude: 35.2621, timezone: 'Asia/Hebron'),

    // Lebanon
    City(id: 'lb_beirut', countryCode: 'LB', nameAr: 'بيروت', nameEn: 'Beirut', latitude: 33.8938, longitude: 35.5018, timezone: 'Asia/Beirut'),
    City(id: 'lb_tripoli', countryCode: 'LB', nameAr: 'طرابلس', nameEn: 'Tripoli', latitude: 34.4367, longitude: 35.8497, timezone: 'Asia/Beirut'),

    // Syria
    City(id: 'sy_damascus', countryCode: 'SY', nameAr: 'دمشق', nameEn: 'Damascus', latitude: 33.5138, longitude: 36.2765, timezone: 'Asia/Damascus'),
    City(id: 'sy_aleppo', countryCode: 'SY', nameAr: 'حلب', nameEn: 'Aleppo', latitude: 36.2021, longitude: 37.1343, timezone: 'Asia/Damascus'),

    // Iraq
    City(id: 'iq_baghdad', countryCode: 'IQ', nameAr: 'بغداد', nameEn: 'Baghdad', latitude: 33.3152, longitude: 44.3661, timezone: 'Asia/Baghdad'),
    City(id: 'iq_basra', countryCode: 'IQ', nameAr: 'البصرة', nameEn: 'Basra', latitude: 30.5081, longitude: 47.7835, timezone: 'Asia/Baghdad'),
    City(id: 'iq_erbil', countryCode: 'IQ', nameAr: 'أربيل', nameEn: 'Erbil', latitude: 36.1901, longitude: 44.0091, timezone: 'Asia/Baghdad'),

    // Yemen
    City(id: 'ye_sanaa', countryCode: 'YE', nameAr: 'صنعاء', nameEn: 'Sanaa', latitude: 15.3694, longitude: 44.1910, timezone: 'Asia/Aden'),
    City(id: 'ye_aden', countryCode: 'YE', nameAr: 'عدن', nameEn: 'Aden', latitude: 12.7855, longitude: 45.0187, timezone: 'Asia/Aden'),

    // Sudan
    City(id: 'sd_khartoum', countryCode: 'SD', nameAr: 'الخرطوم', nameEn: 'Khartoum', latitude: 15.5007, longitude: 32.5599, timezone: 'Africa/Khartoum'),

    // Libya
    City(id: 'ly_tripoli', countryCode: 'LY', nameAr: 'طرابلس الغرب', nameEn: 'Tripoli', latitude: 32.8872, longitude: 13.1913, timezone: 'Africa/Tripoli'),
    City(id: 'ly_benghazi', countryCode: 'LY', nameAr: 'بنغازي', nameEn: 'Benghazi', latitude: 32.1167, longitude: 20.0667, timezone: 'Africa/Tripoli'),

    // Tunisia
    City(id: 'tn_tunis', countryCode: 'TN', nameAr: 'تونس', nameEn: 'Tunis', latitude: 36.8065, longitude: 10.1815, timezone: 'Africa/Tunis'),
    City(id: 'tn_sfax', countryCode: 'TN', nameAr: 'صفاقس', nameEn: 'Sfax', latitude: 34.7406, longitude: 10.7603, timezone: 'Africa/Tunis'),

    // Algeria
    City(id: 'dz_algiers', countryCode: 'DZ', nameAr: 'الجزائر العاصمة', nameEn: 'Algiers', latitude: 36.7538, longitude: 3.0588, timezone: 'Africa/Algiers'),
    City(id: 'dz_oran', countryCode: 'DZ', nameAr: 'وهران', nameEn: 'Oran', latitude: 35.6976, longitude: -0.6337, timezone: 'Africa/Algiers'),

    // Morocco
    City(id: 'ma_rabat', countryCode: 'MA', nameAr: 'الرباط', nameEn: 'Rabat', latitude: 34.0209, longitude: -6.8416, timezone: 'Africa/Casablanca'),
    City(id: 'ma_casablanca', countryCode: 'MA', nameAr: 'الدار البيضاء', nameEn: 'Casablanca', latitude: 33.5731, longitude: -7.5898, timezone: 'Africa/Casablanca'),
    City(id: 'ma_marrakech', countryCode: 'MA', nameAr: 'مراكش', nameEn: 'Marrakech', latitude: 31.6295, longitude: -7.9811, timezone: 'Africa/Casablanca'),
    City(id: 'ma_fes', countryCode: 'MA', nameAr: 'فاس', nameEn: 'Fes', latitude: 34.0181, longitude: -5.0078, timezone: 'Africa/Casablanca'),

    // Turkey
    City(id: 'tr_istanbul', countryCode: 'TR', nameAr: 'إسطنبول', nameEn: 'Istanbul', latitude: 41.0082, longitude: 28.9784, timezone: 'Europe/Istanbul'),
    City(id: 'tr_ankara', countryCode: 'TR', nameAr: 'أنقرة', nameEn: 'Ankara', latitude: 39.9334, longitude: 32.8597, timezone: 'Europe/Istanbul'),

    // UK
    City(id: 'gb_london', countryCode: 'GB', nameAr: 'لندن', nameEn: 'London', latitude: 51.5074, longitude: -0.1278, timezone: 'Europe/London'),
    City(id: 'gb_birmingham', countryCode: 'GB', nameAr: 'برمنغهام', nameEn: 'Birmingham', latitude: 52.4862, longitude: -1.8904, timezone: 'Europe/London'),
    City(id: 'gb_manchester', countryCode: 'GB', nameAr: 'مانشستر', nameEn: 'Manchester', latitude: 53.4808, longitude: -2.2426, timezone: 'Europe/London'),

    // USA
    City(id: 'us_nyc', countryCode: 'US', nameAr: 'نيويورك', nameEn: 'New York', latitude: 40.7128, longitude: -74.0060, timezone: 'America/New_York'),
    City(id: 'us_la', countryCode: 'US', nameAr: 'لوس أنجلوس', nameEn: 'Los Angeles', latitude: 34.0522, longitude: -118.2437, timezone: 'America/Los_Angeles'),
    City(id: 'us_chicago', countryCode: 'US', nameAr: 'شيكاغو', nameEn: 'Chicago', latitude: 41.8781, longitude: -87.6298, timezone: 'America/Chicago'),
    City(id: 'us_houston', countryCode: 'US', nameAr: 'هيوستن', nameEn: 'Houston', latitude: 29.7604, longitude: -95.3698, timezone: 'America/Chicago'),

    // Canada
    City(id: 'ca_toronto', countryCode: 'CA', nameAr: 'تورونتو', nameEn: 'Toronto', latitude: 43.6532, longitude: -79.3832, timezone: 'America/Toronto'),
    City(id: 'ca_montreal', countryCode: 'CA', nameAr: 'مونتريال', nameEn: 'Montreal', latitude: 45.5017, longitude: -73.5673, timezone: 'America/Toronto'),

    // Germany
    City(id: 'de_berlin', countryCode: 'DE', nameAr: 'برلين', nameEn: 'Berlin', latitude: 52.5200, longitude: 13.4050, timezone: 'Europe/Berlin'),
    City(id: 'de_frankfurt', countryCode: 'DE', nameAr: 'فرانكفورت', nameEn: 'Frankfurt', latitude: 50.1109, longitude: 8.6821, timezone: 'Europe/Berlin'),

    // France
    City(id: 'fr_paris', countryCode: 'FR', nameAr: 'باريس', nameEn: 'Paris', latitude: 48.8566, longitude: 2.3522, timezone: 'Europe/Paris'),

    // Indonesia
    City(id: 'id_jakarta', countryCode: 'ID', nameAr: 'جاكرتا', nameEn: 'Jakarta', latitude: -6.2088, longitude: 106.8456, timezone: 'Asia/Jakarta'),

    // Malaysia
    City(id: 'my_kl', countryCode: 'MY', nameAr: 'كوالالمبور', nameEn: 'Kuala Lumpur', latitude: 3.1390, longitude: 101.6869, timezone: 'Asia/Kuala_Lumpur'),

    // Pakistan
    City(id: 'pk_karachi', countryCode: 'PK', nameAr: 'كراتشي', nameEn: 'Karachi', latitude: 24.8607, longitude: 67.0011, timezone: 'Asia/Karachi'),
    City(id: 'pk_lahore', countryCode: 'PK', nameAr: 'لاهور', nameEn: 'Lahore', latitude: 31.5204, longitude: 74.3587, timezone: 'Asia/Karachi'),
    City(id: 'pk_islamabad', countryCode: 'PK', nameAr: 'إسلام آباد', nameEn: 'Islamabad', latitude: 33.6844, longitude: 73.0479, timezone: 'Asia/Karachi'),

    // Bangladesh
    City(id: 'bd_dhaka', countryCode: 'BD', nameAr: 'دكا', nameEn: 'Dhaka', latitude: 23.8103, longitude: 90.4125, timezone: 'Asia/Dhaka'),

    // India
    City(id: 'in_delhi', countryCode: 'IN', nameAr: 'دلهي', nameEn: 'Delhi', latitude: 28.6139, longitude: 77.2090, timezone: 'Asia/Kolkata'),
    City(id: 'in_mumbai', countryCode: 'IN', nameAr: 'مومباي', nameEn: 'Mumbai', latitude: 19.0760, longitude: 72.8777, timezone: 'Asia/Kolkata'),
    City(id: 'in_hyderabad', countryCode: 'IN', nameAr: 'حيدر آباد', nameEn: 'Hyderabad', latitude: 17.3850, longitude: 78.4867, timezone: 'Asia/Kolkata'),
  ];
}
