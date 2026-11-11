import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adhan_and_prayer/core/update/engine/update_engine.dart';
import 'package:adhan_and_prayer/core/update/models/update_info.dart';
import 'package:adhan_and_prayer/core/update/models/update_progress.dart';
import 'package:adhan_and_prayer/core/utils/logger.dart';

sealed class UpdateState {
  const UpdateState();
}

class UpdateInitialState extends UpdateState {}

class UpdateCheckingState extends UpdateState {}

class UpdateNotAvailableState extends UpdateState {
  final String? reason;
  final bool userInitiated;
  const UpdateNotAvailableState({this.reason, this.userInitiated = false});
}

class UpdateAvailableState extends UpdateState {
  final UpdateInfo info;
  const UpdateAvailableState(this.info);
}

class UpdateDownloadingState extends UpdateState {
  final UpdateInfo info;
  final UpdateProgress progress;
  const UpdateDownloadingState({required this.info, required this.progress});
}

class UpdateReadyToInstallState extends UpdateState {
  final UpdateInfo info;
  final String filePath;
  const UpdateReadyToInstallState({required this.info, required this.filePath});
}

class UpdateInstallingState extends UpdateState {
  final UpdateInfo info;
  const UpdateInstallingState(this.info);
}

class UpdateErrorState extends UpdateState {
  final String errorMessage;
  final bool isForced;
  final UpdateInfo? info;
  const UpdateErrorState(this.errorMessage, {this.isForced = false, this.info});
}

class UpdateCubit extends Cubit<UpdateState> {
  final UpdateEngine engine;

  UpdateCubit({required this.engine}) : super(UpdateInitialState());

  /// Checks for updates. [userInitiated] is true when triggered from Settings.
  Future<void> checkForUpdates({bool userInitiated = false}) async {
    emit(UpdateCheckingState());

    try {
      final info = await engine.checkForUpdate();
      if (info.hasUpdate) {
        emit(UpdateAvailableState(info));
      } else {
        emit(UpdateNotAvailableState(
          reason: info.rejectionReason,
          userInitiated: userInitiated,
        ));
      }
    } catch (e, stack) {
      AppLogger.error('Update check failed in Cubit', e, stack, 'UPDATE_CUBIT');
      emit(UpdateErrorState('Failed to check for updates: $e'));
    }
  }

  /// Downloads and verifies the update file.
  Future<void> downloadUpdate(UpdateInfo info) async {
    emit(UpdateDownloadingState(
      info: info,
      progress: UpdateProgress.idle(),
    ));

    try {
      await for (final progress in engine.downloadAndVerify(info)) {
        if (progress.step == UpdateStep.failed) {
          emit(UpdateErrorState(
            progress.message ?? 'Update download or verification failed.',
            isForced: info.isForced,
            info: info,
          ));
          return;
        } else if (progress.step == UpdateStep.readyToInstall && progress.filePath != null) {
          emit(UpdateReadyToInstallState(info: info, filePath: progress.filePath!));
          return;
        } else {
          emit(UpdateDownloadingState(info: info, progress: progress));
        }
      }
    } catch (e, stack) {
      AppLogger.error('Download stream error in UpdateCubit', e, stack, 'UPDATE_CUBIT');
      emit(UpdateErrorState(
        'Download failed: $e',
        isForced: info.isForced,
        info: info,
      ));
    }
  }

  /// Executes platform installation for the verified update.
  Future<void> installUpdate(UpdateInfo info, String filePath) async {
    emit(UpdateInstallingState(info));

    try {
      final result = await engine.install(filePath);
      if (!result.success) {
        emit(UpdateErrorState(
          result.errorMessage ?? 'Installation failed to launch.',
          isForced: info.isForced,
          info: info,
        ));
      }
    } catch (e, stack) {
      AppLogger.error('Installation trigger failed', e, stack, 'UPDATE_CUBIT');
      emit(UpdateErrorState(
        'Failed to start installation: $e',
        isForced: info.isForced,
        info: info,
      ));
    }
  }

  /// Resets back to idle state if update was optional and dismissed.
  void dismissUpdate() {
    emit(UpdateInitialState());
  }
}
