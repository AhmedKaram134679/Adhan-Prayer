import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/cubit/prayer_cubit.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/widgets/next_prayer_hero_card.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/widgets/prayer_card.dart';
import 'package:adhan_and_prayer/features/settings/presentation/cubit/settings_cubit.dart';

class MobileHomeView extends StatelessWidget {
  final PrayerLoadedState state;

  const MobileHomeView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final langCode = loc.locale.languageCode;
    final dateStr = DateFormat.yMMMMEEEEd(langCode).format(state.todayTimes.date);

    final prayersList = state.todayTimes.toList(
      perPrayerAdhan: state.perPrayerAdhan,
    );

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Date Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              dateStr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Next Prayer Card
          NextPrayerHeroCard(
            nextPrayer: state.nextPrayer,
            countdown: state.countdown,
            cityName: '${state.city.getLocalizedName(langCode)}, ${state.country.getLocalizedName(langCode)}',
          ),

          // Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              loc.translate('today_prayers'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Daily Prayer List
          ...prayersList.map((prayer) {
            final isNext = prayer.type == state.nextPrayer.type;
            final isCurrent = prayer.type == state.currentPrayer?.type;

            return PrayerCard(
              prayer: prayer,
              isNext: isNext,
              isCurrent: isCurrent,
              onToggleAdhan: () {
                final currentSetting = state.perPrayerAdhan[prayer.type] ?? true;
                context.read<SettingsCubit>().setPrayerAdhanEnabled(
                  prayer.type,
                  !currentSetting,
                );
                context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
              },
            );
          }),
        ],
      ),
    );
  }
}
