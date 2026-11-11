import 'dart:io';
import 'package:adhan_and_prayer/core/config/app_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/features/about/presentation/screens/about_screen.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/screens/reciter_selection_screen.dart';
import 'package:adhan_and_prayer/features/location/presentation/screens/location_selection_screen.dart';
import 'package:adhan_and_prayer/features/prayer_times/domain/entities/calculation_settings.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/cubit/prayer_cubit.dart';
import 'package:adhan_and_prayer/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:adhan_and_prayer/core/enums/time_enums.dart';
import 'package:adhan_and_prayer/core/update/presentation/cubit/update_cubit.dart';
import 'package:adhan_and_prayer/core/update/presentation/widgets/update_dialog.dart';
import 'package:adhan_and_prayer/features/qibla/presentation/screens/qibla_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isWindows = Platform.isWindows;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('settings')),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // SECTION: Location
              _buildSectionHeader(context, loc.translate('location')),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(loc.translate('location')),
                subtitle: Text(loc.translate('select_city')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LocationSelectionScreen(),
                    ),
                  );
                  if (context.mounted) {
                    context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                  }
                },
              ),
              if (!isWindows)
                ListTile(
                  leading: const Icon(Icons.explore),
                  title: Text(loc.translate('qibla_direction')),
                  subtitle: Text(loc.translate('qibla')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QiblaScreen(),
                      ),
                    );
                  },
                ),
              const Divider(),

              // SECTION: Adhan & Audio
              _buildSectionHeader(context, loc.translate('reciter')),
              ListTile(
                leading: const Icon(Icons.record_voice_over),
                title: Text(loc.translate('reciter')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const ReciterSelectionScreen(),
                    ),
                  );
                  if (changed == true && context.mounted) {
                    context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                  }
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active),
                title: Text(loc.translate('global_adhan')),
                value: state.globalAdhanEnabled,
                onChanged: (val) {
                  context.read<SettingsCubit>().setGlobalAdhanEnabled(val);
                  context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.adhanVolume == 0
                                  ? Icons.volume_off
                                  : state.adhanVolume < 0.5
                                      ? Icons.volume_down
                                      : Icons.volume_up,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              loc.translate('adhan_volume'),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        Text(
                          '${(state.adhanVolume * 100).round()}%',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    Semantics(
                      label: '${loc.translate('adhan_volume')}, ${(state.adhanVolume * 100).round()}%',
                      child: Slider(
                        value: state.adhanVolume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label: '${(state.adhanVolume * 100).round()}%',
                        onChanged: (val) {
                          context.read<SettingsCubit>().setAdhanVolume(val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // SECTION: Calculation Method & Madhab
              _buildSectionHeader(context, loc.translate('calculation_method')),

              // Mode: Automatic (Recommended) Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: state.calculationSettings.mode == CalculationMethodMode.automatic
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.read<SettingsCubit>().setCalculationMethodMode(CalculationMethodMode.automatic);
                    context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          state.calculationSettings.mode == CalculationMethodMode.automatic
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: state.calculationSettings.mode == CalculationMethodMode.automatic
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('calculation_method_automatic'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.translate('calculation_method_automatic_desc'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${loc.translate('currently_using')} ${_getMethodDisplayName(state.calculationSettings.method)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Mode: Manual Selection Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: state.calculationSettings.mode == CalculationMethodMode.manual
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.read<SettingsCubit>().setCalculationMethodMode(CalculationMethodMode.manual);
                    context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          state.calculationSettings.mode == CalculationMethodMode.manual
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: state.calculationSettings.mode == CalculationMethodMode.manual
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          loc.translate('calculation_method_manual'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (state.calculationSettings.mode == CalculationMethodMode.manual) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<CalculationMethodType>(
                    key: ValueKey('calc_method_${state.calculationSettings.method.name}'),
                    initialValue: state.calculationSettings.method,
                    decoration: InputDecoration(
                      labelText: loc.translate('calculation_method'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: CalculationMethodType.egyptian,
                        child: Text('Egyptian General Authority'),
                      ),
                      DropdownMenuItem(
                        value: CalculationMethodType.ummAlQura,
                        child: Text('Umm Al-Qura (Makkah)'),
                      ),
                      DropdownMenuItem(
                        value: CalculationMethodType.muslimWorldLeague,
                        child: Text('Muslim World League'),
                      ),
                      DropdownMenuItem(
                        value: CalculationMethodType.dubai,
                        child: Text('Dubai Islamic Affairs'),
                      ),
                      DropdownMenuItem(
                        value: CalculationMethodType.kuwait,
                        child: Text('Kuwait Ministry of Awqaf'),
                      ),
                      DropdownMenuItem(
                        value: CalculationMethodType.qatar,
                        child: Text('Qatar Ministry of Awqaf'),
                      ),
                      DropdownMenuItem(
                        value: CalculationMethodType.karachi,
                        child: Text('University of Islamic Sciences (Karachi)'),
                      ),
                      DropdownMenuItem(
                        value: CalculationMethodType.northAmerica,
                        child: Text('ISNA (North America)'),
                      ),
                      DropdownMenuItem(
                        value: CalculationMethodType.moonsightingCommittee,
                        child: Text('Moon Sighting Committee'),
                      ),
                    ],
                    onChanged: (newMethod) {
                      if (newMethod != null) {
                        context.read<SettingsCubit>().setManualCalculationMethod(newMethod);
                        context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                      }
                    },
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<MadhabType>(
                  initialValue: state.calculationSettings.madhab,
                  decoration: InputDecoration(
                    labelText: loc.translate('madhab'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: MadhabType.shafi,
                      child: Text(loc.translate('shafi')),
                    ),
                    DropdownMenuItem(
                      value: MadhabType.hanafi,
                      child: Text(loc.translate('hanafi')),
                    ),
                  ],
                  onChanged: (newMadhab) {
                    if (newMadhab != null) {
                      context.read<SettingsCubit>().setCalculationSettings(
                        state.calculationSettings.copyWith(madhab: newMadhab),
                      );
                      context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                    }
                  },
                ),
              ),
              const Divider(),

              // SECTION: Time & Clock
              _buildSectionHeader(context, loc.translate('time_and_clock')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  loc.translate('time_system'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Text(
                  loc.translate('time_system_desc'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 6),

              // Time System: Automatic Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: state.timeSystemMode == TimeSystemMode.automatic
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.read<SettingsCubit>().setTimeSystemMode(TimeSystemMode.automatic);
                    context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          state.timeSystemMode == TimeSystemMode.automatic
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: state.timeSystemMode == TimeSystemMode.automatic
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('time_system_automatic'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loc.translate('time_system_automatic_desc'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Time System: Daylight Saving Time Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: state.timeSystemMode == TimeSystemMode.daylightSaving
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.read<SettingsCubit>().setTimeSystemMode(TimeSystemMode.daylightSaving);
                    context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          state.timeSystemMode == TimeSystemMode.daylightSaving
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: state.timeSystemMode == TimeSystemMode.daylightSaving
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('time_system_dst'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loc.translate('time_system_dst_desc'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Time System: Standard Time Card
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: state.timeSystemMode == TimeSystemMode.standard
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.read<SettingsCubit>().setTimeSystemMode(TimeSystemMode.standard);
                    context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          state.timeSystemMode == TimeSystemMode.standard
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: state.timeSystemMode == TimeSystemMode.standard
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('time_system_standard'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loc.translate('time_system_standard_desc'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Clock Format Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  loc.translate('clock_format'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SegmentedButton<ClockFormat>(
                  segments: [
                    ButtonSegment(
                      value: ClockFormat.twelveHour,
                      label: Text(loc.translate('clock_12h')),
                      icon: const Icon(Icons.access_time),
                    ),
                    ButtonSegment(
                      value: ClockFormat.twentyFourHour,
                      label: Text(loc.translate('clock_24h')),
                      icon: const Icon(Icons.schedule),
                    ),
                  ],
                  selected: {state.clockFormat},
                  onSelectionChanged: (formats) {
                    context.read<SettingsCubit>().setClockFormat(formats.first);
                  },
                ),
              ),
              const Divider(),

              // SECTION: Appearance & Language
              _buildSectionHeader(context, loc.translate('theme')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(loc.translate('theme_light')),
                      icon: const Icon(Icons.light_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(loc.translate('theme_dark')),
                      icon: const Icon(Icons.dark_mode),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(loc.translate('theme_system')),
                      icon: const Icon(Icons.brightness_auto),
                    ),
                  ],
                  selected: {state.themeMode},
                  onSelectionChanged: (modes) {
                    context.read<SettingsCubit>().setThemeMode(modes.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'en',
                      label: Text(loc.translate('language_en')),
                    ),
                    ButtonSegment(
                      value: 'ar',
                      label: Text(loc.translate('language_ar')),
                    ),
                  ],
                  selected: {state.locale.languageCode},
                  onSelectionChanged: (langs) {
                    context.read<SettingsCubit>().setLocale(Locale(langs.first));
                  },
                ),
              ),
              const Divider(),

              // SECTION: Windows Desktop Options
              if (isWindows) ...[
                _buildSectionHeader(context, 'Windows Desktop'),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new),
                  title: Text(loc.translate('start_with_windows')),
                  value: state.startWithWindows,
                  onChanged: (val) {
                    context.read<SettingsCubit>().setStartWithWindows(val);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.aspect_ratio),
                  title: Text(loc.translate('minimize_to_tray')),
                  subtitle: const Text('Closing the window keeps the application active in the tray.'),
                ),
                const Divider(),
              ],

              // SECTION: Updates
              _buildSectionHeader(context, loc.translate('check_for_updates')),
              BlocConsumer<UpdateCubit, UpdateState>(
                listener: (context, updateState) {
                  if (updateState is UpdateAvailableState) {
                    UpdateDialog.show(context, updateState.info);
                  } else if (updateState is UpdateNotAvailableState) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.translate('no_update_available')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else if (updateState is UpdateErrorState) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${loc.translate('update_error')}: ${updateState.errorMessage}'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                },
                builder: (context, updateState) {
                  final isChecking = updateState is UpdateCheckingState;
                  return ListTile(
                    leading: isChecking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_rounded),
                    title: Text(loc.translate('check_for_updates')),
                    subtitle: Text(
                      isChecking
                          ? loc.translate('checking_for_updates')
                          : '${loc.translate('current_version')}: ${AppVersion.versionName}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: !isChecking,
                    onTap: () {
                      context.read<UpdateCubit>().checkForUpdates(userInitiated: true);
                    },
                  );
                },
              ),
              const Divider(),

              // SECTION: About
              _buildSectionHeader(context, loc.translate('about')),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.translate('about_app')),
                subtitle: Text('${loc.translate('app_name')} • ${loc.translate('version')} ${AppVersion.versionName}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AboutScreen(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  String _getMethodDisplayName(CalculationMethodType method) {
    switch (method) {
      case CalculationMethodType.egyptian:
        return 'Egyptian General Authority';
      case CalculationMethodType.ummAlQura:
        return 'Umm Al-Qura (Makkah)';
      case CalculationMethodType.muslimWorldLeague:
        return 'Muslim World League';
      case CalculationMethodType.dubai:
        return 'Dubai Islamic Affairs';
      case CalculationMethodType.kuwait:
        return 'Kuwait Ministry of Awqaf';
      case CalculationMethodType.qatar:
        return 'Qatar Ministry of Awqaf';
      case CalculationMethodType.karachi:
        return 'University of Islamic Sciences (Karachi)';
      case CalculationMethodType.northAmerica:
        return 'ISNA (North America)';
      case CalculationMethodType.moonsightingCommittee:
        return 'Moon Sighting Committee';
    }
  }
}
