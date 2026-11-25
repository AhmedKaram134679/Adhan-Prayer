import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/screens/reciter_selection_screen.dart';
import 'package:adhan_and_prayer/features/home/presentation/widgets/desktop_home_view.dart';
import 'package:adhan_and_prayer/features/home/presentation/widgets/mobile_home_view.dart';
import 'package:adhan_and_prayer/features/location/presentation/screens/location_selection_screen.dart';
import 'package:adhan_and_prayer/features/prayer_times/presentation/cubit/prayer_cubit.dart';
import 'package:adhan_and_prayer/features/settings/presentation/screens/settings_screen.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:adhan_and_prayer/core/di/injection.dart';
import 'package:adhan_and_prayer/core/platform/adhan_activation_payload.dart';
import 'package:adhan_and_prayer/core/platform/windows_tray_manager.dart';
import 'package:adhan_and_prayer/core/update/presentation/cubit/update_cubit.dart';
import 'package:adhan_and_prayer/core/update/presentation/widgets/update_dialog.dart';
import 'package:adhan_and_prayer/features/adhan/domain/services/adhan_playback_coordinator.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/widgets/adhan_dialog.dart';
import 'package:adhan_and_prayer/features/qibla/presentation/screens/qibla_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<AdhanActivationPayload>? _activationSub;
  static const MethodChannel _alarmChannel =
      MethodChannel('com.example.adhan_and_prayer/alarm');

  @override
  void initState() {
    super.initState();
    context.read<PrayerCubit>().loadPrayerTimes();

    final coordinator = getIt<AdhanPlaybackCoordinator>();

    // Listen for structured activation events (in-app or Windows single-instance)
    _activationSub = coordinator.onActivationRequested.listen((payload) {
      if (mounted) {
        _presentActivationDialog(payload, coordinator);
      }
    });

    // Check cold-start or resume launch intent on Android
    if (Platform.isAndroid) {
      _checkAndroidLaunchIntent(coordinator);
      _setupAndroidMethodChannelListener(coordinator);
    }

    // Post-frame: consume any pending activation (cold-start CLI or buffered native
    // Windows WM_COPYDATA) and run silent automatic update check.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _consumePendingActivation(coordinator);
      if (mounted) {
        context.read<UpdateCubit>().checkForUpdates(userInitiated: false);
      }
    });
  }

  Future<void> _consumePendingActivation(AdhanPlaybackCoordinator coordinator) async {
    var pending = coordinator.pendingActivation;
    if (pending == null && Platform.isWindows) {
      pending = await WindowsTrayManager().fetchPendingNativeActivation();
      if (pending != null) {
        coordinator.enqueueActivation(pending);
      }
    }
    if (pending != null && mounted) {
      _presentActivationDialog(pending, coordinator);
    }
  }

  void _presentActivationDialog(
    AdhanActivationPayload payload,
    AdhanPlaybackCoordinator coordinator,
  ) {
    if (!coordinator.acknowledgeActivation(payload.eventId)) {
      return;
    }
    AdhanDialog.show(
      context,
      prayerName: payload.prayerName,
      coordinator: coordinator,
    );
  }

  void _checkAndroidLaunchIntent(AdhanPlaybackCoordinator coordinator) async {
    try {
      final details = await _alarmChannel.invokeMapMethod<String, dynamic>('getLaunchAdhanDetails');
      if (details != null && details['openAdhanDialog'] == true) {
        final prayerName = details['prayerName'] as String? ?? 'Prayer';
        if (mounted) {
          AdhanDialog.show(
            context,
            prayerName: prayerName,
            coordinator: coordinator,
          );
        }
      }
    } catch (_) {}
  }

  void _setupAndroidMethodChannelListener(AdhanPlaybackCoordinator coordinator) {
    _alarmChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAdhanNotificationTapped') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final prayerName = args?['prayerName'] as String? ?? 'Prayer';
        if (mounted) {
          AdhanDialog.show(
            context,
            prayerName: prayerName,
            coordinator: coordinator,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _activationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDesktop = Platform.isWindows || MediaQuery.of(context).size.width >= 800;

    return BlocListener<UpdateCubit, UpdateState>(
      listener: (context, updateState) {
        if (updateState is UpdateAvailableState) {
          UpdateDialog.show(context, updateState.info);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(loc.translate('app_name')),
        ),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.explore_outlined),
              tooltip: loc.translate('qibla_direction'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QiblaScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: loc.translate('location'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LocationSelectionScreen()),
              );
              if (context.mounted) {
                context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over_outlined),
            tooltip: loc.translate('reciter'),
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ReciterSelectionScreen()),
              );
              if (changed == true && context.mounted) {
                context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: loc.translate('settings'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              if (context.mounted) {
                context.read<PrayerCubit>().loadPrayerTimes(isRefresh: true);
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<PrayerCubit, PrayerState>(
        builder: (context, state) {
          if (state is PrayerLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PrayerErrorState) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<PrayerCubit>().loadPrayerTimes();
                      },
                      child: Text(loc.translate('retry')),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is PrayerLoadedState) {
            return isDesktop
                ? DesktopHomeView(state: state)
                : MobileHomeView(state: state);
          }

          return const SizedBox.shrink();
        },
      ),
    ),
    );
  }
}
