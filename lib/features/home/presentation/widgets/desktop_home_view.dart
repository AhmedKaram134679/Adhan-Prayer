import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/cubit/prayer_cubit.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/widgets/next_prayer_hero_card.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/widgets/prayer_card.dart';
import 'package:adhan_and_prayer/features/settings/presentation/cubit/settings_cubit.dart';

class DesktopHomeView extends StatelessWidget {
  final PrayerLoadedState state;

  const DesktopHomeView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final langCode = loc.locale.languageCode;
    final dateStr = DateFormat.yMMMMEEEEd(langCode).format(state.todayTimes.date);

    final prayersList = state.todayTimes.toList(
      perPrayerAdhan: state.perPrayerAdhan,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pane: Hero Card & Date Overview
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Text(
                  dateStr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 12),
                NextPrayerHeroCard(
                  nextPrayer: state.nextPrayer,
                  countdown: state.countdown,
                  cityName: '${state.city.getLocalizedName(langCode)}, ${state.country.getLocalizedName(langCode)}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Right Pane: Prayer Times List
          Expanded(
            flex: 6,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        loc.translate('today_prayers'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView(
                        children: prayersList.map((prayer) {
                          final isNext = prayer.type == state.nextPrayer.type;
                          final isCurrent = prayer.type == state.currentPrayer?.type;

                          return PrayerCard(
                            prayer: prayer,
                            isNext: isNext,
                            isCurrent: isCurrent,
                            onToggleAdhan: () {
                              final current = state.perPrayerAdhan[prayer.type] ?? true;
                              context.read<SettingsCubit>().setPrayerAdhanEnabled(
                                prayer.type,
                                !current,
                              );
                              context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
