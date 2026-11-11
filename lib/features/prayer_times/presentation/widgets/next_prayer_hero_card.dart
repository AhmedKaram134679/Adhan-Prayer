import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/core/theme/app_theme.dart';
import 'package:adhan_and_prayer/core/utils/time_formatter.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/countdown_time.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:adhan_and_prayer/features/settings/presentation/cubit/settings_cubit.dart';

class NextPrayerHeroCard extends StatelessWidget {
  final PrayerItem nextPrayer;
  final CountdownTime countdown;
  final String cityName;

  const NextPrayerHeroCard({
    super.key,
    required this.nextPrayer,
    required this.countdown,
    required this.cityName,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final clockFormat = context.select<SettingsCubit, dynamic>(
      (c) => c.state.clockFormat,
    );
    final timeFormatted = AppTimeFormatter.formatPrayerTime(
      nextPrayer.time,
      clockFormat,
      locale: loc.locale.languageCode,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // City Name Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: AppColors.accentLight, size: 16),
                const SizedBox(width: 6),
                Text(
                  cityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Next Prayer Label & Name
          Text(
            loc.translate('next_prayer'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextPrayer.getLocalizedName(loc.locale.languageCode),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeFormatted,
            style: const TextStyle(
              color: AppColors.accentLight,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // Countdown Units
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTimeUnit(
                  value: countdown.hours.toString().padLeft(2, '0'),
                  label: loc.locale.languageCode == 'ar' ? 'ساعة' : 'HRS',
                ),
                _buildSeparator(),
                _buildTimeUnit(
                  value: countdown.minutes.toString().padLeft(2, '0'),
                  label: loc.locale.languageCode == 'ar' ? 'دقيقة' : 'MIN',
                ),
                _buildSeparator(),
                _buildTimeUnit(
                  value: countdown.seconds.toString().padLeft(2, '0'),
                  label: loc.locale.languageCode == 'ar' ? 'ثانية' : 'SEC',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit({required String value, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        ':',
        style: TextStyle(
          color: AppColors.accent,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
