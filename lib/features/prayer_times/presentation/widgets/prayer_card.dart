import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/core/theme/app_theme.dart';
import 'package:adhan_and_prayer/core/utils/time_formatter.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/prayer_entities.dart';
import 'package:adhan_and_prayer/features/settings/presentation/cubit/settings_cubit.dart';

class PrayerCard extends StatelessWidget {
  final PrayerItem prayer;
  final bool isNext;
  final bool isCurrent;
  final VoidCallback? onToggleAdhan;

  const PrayerCard({
    super.key,
    required this.prayer,
    this.isNext = false,
    this.isCurrent = false,
    this.onToggleAdhan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final clockFormat = context.select<SettingsCubit, dynamic>(
      (c) => c.state.clockFormat,
    );
    final timeStr = AppTimeFormatter.formatPrayerTime(
      prayer.time,
      clockFormat,
      locale: loc.locale.languageCode,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isNext
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? theme.colorScheme.primary
              : isCurrent
                  ? theme.colorScheme.secondary
                  : theme.dividerTheme.color ?? Colors.grey.shade300,
          width: isNext || isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // Prayer Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isNext
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getPrayerIcon(prayer.type),
                color: isNext ? Colors.white : theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),

            // Prayer Name & Status Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prayer.getLocalizedName(loc.locale.languageCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isNext
                          ? theme.colorScheme.primary
                          : theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  if (isNext) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        loc.translate('next_prayer'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Time & Adhan Bell
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                if (prayer.isObligatory) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      prayer.isAdhanEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                      color: prayer.isAdhanEnabled
                          ? theme.colorScheme.primary
                          : Colors.grey,
                      size: 20,
                    ),
                    onPressed: onToggleAdhan,
                    tooltip: loc.translate('adhan_enabled'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPrayerIcon(PrayerType type) {
    switch (type) {
      case PrayerType.fajr:
        return Icons.wb_twilight;
      case PrayerType.sunrise:
        return Icons.wb_sunny_outlined;
      case PrayerType.dhuhr:
        return Icons.wb_sunny;
      case PrayerType.asr:
        return Icons.wb_cloudy_outlined;
      case PrayerType.maghrib:
        return Icons.nights_stay_outlined;
      case PrayerType.isha:
        return Icons.bedtime;
    }
  }
}
