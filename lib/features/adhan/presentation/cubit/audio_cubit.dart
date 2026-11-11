import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/audio/audio_player_service.dart';
import 'package:adhan_and_prayer/core/errors/failures.dart';
import 'package:adhan_and_prayer/features/adhan/data/repositories/audio_repository_impl.dart';
import 'package:adhan_and_prayer/features/adhan/domain/entities/reciter.dart';

sealed class AudioState {
  const AudioState();
}

class AudioInitialState extends AudioState {}

class AudioLoadingState extends AudioState {}

class AudioLoadedState extends AudioState {
  final List<Reciter> reciters;
  final Reciter selectedReciter;
  final String? currentlyPlayingId;
  final bool isPlaying;

  const AudioLoadedState({
    required this.reciters,
    required this.selectedReciter,
    this.currentlyPlayingId,
    this.isPlaying = false,
  });

  AudioLoadedState copyWith({
    List<Reciter>? reciters,
    Reciter? selectedReciter,
    String? currentlyPlayingId,
    bool? isPlaying,
  }) {
    return AudioLoadedState(
      reciters: reciters ?? this.reciters,
      selectedReciter: selectedReciter ?? this.selectedReciter,
      currentlyPlayingId: currentlyPlayingId,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class AudioErrorState extends AudioState {
  final String message;
  const AudioErrorState(this.message);
}

class AudioCubit extends Cubit<AudioState> {
  final AudioRepository audioRepo;
  final AudioPlayerService audioPlayer;

  AudioCubit({
    required this.audioRepo,
    required this.audioPlayer,
  }) : super(AudioInitialState());

  Future<void> initialize() async {
    emit(AudioLoadingState());
    try {
      final reciters = await audioRepo.getReciters();
      final selected = await audioRepo.getSelectedReciter();
      emit(AudioLoadedState(reciters: reciters, selectedReciter: selected));
    } catch (e) {
      emit(AudioErrorState(e.toString()));
    }
  }

  Future<void> selectReciter(Reciter reciter) async {
    final currentState = state;
    if (currentState is! AudioLoadedState) return;

    // Stop active preview immediately when reciter selection changes
    if (currentState.isPlaying) {
      await stopPreview();
    }

    final result = await audioRepo.saveSelectedReciter(reciter);
    if (result is Success) {
      final updatedState = state;
      if (updatedState is AudioLoadedState) {
        emit(updatedState.copyWith(selectedReciter: reciter));
      }
    } else {
      emit(AudioErrorState((result as Failure).message));
    }
  }

  Future<void> togglePreview(Reciter reciter) async {
    final currentState = state;
    if (currentState is! AudioLoadedState) return;

    if (currentState.isPlaying && currentState.currentlyPlayingId == reciter.id) {
      await stopPreview();
    } else {
      // Sync with user's saved volume before starting preview
      final volume = await audioRepo.getAdhanVolume();
      await audioPlayer.setVolume(volume);

      final result = await audioPlayer.playAsset(
        reciter.assetPath,
        context: AudioPlaybackContext.preview,
      );
      if (result is Success) {
        emit(currentState.copyWith(currentlyPlayingId: reciter.id, isPlaying: true));
      } else {
        emit(AudioErrorState((result as Failure).message));
      }
    }
  }

  Future<void> stopPreview() async {
    await audioPlayer.stopPreview();
    final currentState = state;
    if (currentState is AudioLoadedState) {
      emit(currentState.copyWith(currentlyPlayingId: null, isPlaying: false));
    }
  }

  @override
  Future<void> close() {
    // Only stop preview session if active, never stop background Adhans
    audioPlayer.stopPreview();
    return super.close();
  }
}
