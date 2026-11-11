import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/features/adhan/presentation/cubit/audio_cubit.dart';

class ReciterSelectionScreen extends StatefulWidget {
  final bool isOnboarding;

  const ReciterSelectionScreen({super.key, this.isOnboarding = false});

  @override
  State<ReciterSelectionScreen> createState() => _ReciterSelectionScreenState();
}

class _ReciterSelectionScreenState extends State<ReciterSelectionScreen> {
  String? _initialReciterId;
  String? _currentReciterId;

  @override
  void initState() {
    super.initState();
    context.read<AudioCubit>().initialize();
  }

  @override
  void dispose() {
    // Stop user preview immediately when leaving reciter selection screen.
    // AudioCubit.stopPreview() only targets Preview sessions and will NEVER
    // terminate a real background/scheduled Adhan.
    context.read<AudioCubit>().stopPreview();
    super.dispose();
  }

  bool get _hasSelectionChanged =>
      _initialReciterId != null &&
      _currentReciterId != null &&
      _initialReciterId != _currentReciterId;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = loc.locale.languageCode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.read<AudioCubit>().stopPreview();
        Navigator.of(context).pop(_hasSelectionChanged);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.translate('reciter')),
          leading: BackButton(
            onPressed: () {
              context.read<AudioCubit>().stopPreview();
              Navigator.of(context).pop(_hasSelectionChanged);
            },
          ),
        ),
      body: BlocConsumer<AudioCubit, AudioState>(
        listener: (context, state) {
          if (state is AudioErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is AudioLoadedState) {
            _initialReciterId ??= state.selectedReciter.id;
            _currentReciterId = state.selectedReciter.id;
          }
        },
        builder: (context, state) {
          if (state is AudioLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AudioLoadedState) {
            _initialReciterId ??= state.selectedReciter.id;
            _currentReciterId = state.selectedReciter.id;
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: state.reciters.length,
              separatorBuilder: (_, unused) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final reciter = state.reciters[index];
                final isSelected = state.selectedReciter.id == reciter.id;
                final isThisPlaying = state.isPlaying && state.currentlyPlayingId == reciter.id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: isSelected ? Colors.white : theme.colorScheme.primary,
                    child: const Icon(Icons.person),
                  ),
                  title: Text(
                    reciter.getLocalizedName(lang),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    isSelected ? 'Selected • محدد' : '',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview Button
                      IconButton(
                        icon: Icon(
                          isThisPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                          color: isThisPlaying ? Colors.red : theme.colorScheme.primary,
                          size: 32,
                        ),
                        tooltip: isThisPlaying
                            ? loc.translate('stop')
                            : loc.translate('preview'),
                        onPressed: () {
                          context.read<AudioCubit>().togglePreview(reciter);
                        },
                      ),
                      const SizedBox(width: 8),
                      // Selection Indicator
                      IconButton(
                        icon: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? theme.colorScheme.primary : Colors.grey,
                        ),
                        onPressed: () {
                          _currentReciterId = reciter.id;
                          context.read<AudioCubit>().selectReciter(reciter);
                          if (!widget.isOnboarding) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ' selected',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    _currentReciterId = reciter.id;
                    context.read<AudioCubit>().selectReciter(reciter);
                  },
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    ),
    );
  }
}
