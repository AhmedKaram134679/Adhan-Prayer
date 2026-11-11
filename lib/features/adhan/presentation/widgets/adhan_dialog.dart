import 'package:flutter/material.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/core/theme/app_theme.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';

class AdhanDialog extends StatelessWidget {
  final String prayerName;
  final AdhanPlaybackCoordinator coordinator;

  const AdhanDialog({
    super.key,
    required this.prayerName,
    required this.coordinator,
  });

  /// Displays the Adhan Dialog using the top-level Navigator.
  /// Prevents stacking duplicate dialogs.
  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    required String prayerName,
    required AdhanPlaybackCoordinator coordinator,
  }) async {
    if (_isShowing) return;
    _isShowing = true;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AdhanDialog(
          prayerName: prayerName,
          coordinator: coordinator,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final prayerAr = _getPrayerNameAr(prayerName);
    final isArabic = loc.locale.languageCode == 'ar';
    final displayName = isArabic ? prayerAr : prayerName;

    return StreamBuilder<bool>(
      stream: coordinator.onAdhanActiveChanged,
      initialData: coordinator.isAdhanActive,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? coordinator.isAdhanActive;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isPlaying
                  ? AppColors.primaryLight.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          backgroundColor:
              isDark ? AppColors.darkSurface : AppColors.lightSurface,
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.volume_up_rounded,
                  color: isPlaying ? AppColors.primaryLight : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPlaying
                          ? loc.translate('adhan_playing_now')
                          : loc.translate('time_remaining'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isPlaying
                            ? AppColors.primaryLight
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        fontWeight:
                            isPlaying ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mosque_outlined,
                      color: AppColors.accent,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        isArabic
                            ? 'حان الآن موعد صلاة $displayName'
                            : 'It is now time for $displayName prayer.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // ⚪ Close button: ONLY dismisses dialog. MUST NOT stop or pause Adhan audio!
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                loc.translate('close'),
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // 🔴 Stop Adhan button: Centralized stop operation. Stops the active Adhan immediately and closes dialog.
            ElevatedButton.icon(
              onPressed: () async {
                await coordinator.stopCurrentAdhan();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: Text(
                loc.translate('stop_adhan'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _getPrayerNameAr(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return 'الفجر';
      case 'sunrise':
        return 'الشروق';
      case 'dhuhr':
        return 'الظهر';
      case 'asr':
        return 'العصر';
      case 'maghrib':
        return 'المغرب';
      case 'isha':
        return 'العشاء';
      default:
        return name;
    }
  }
}
