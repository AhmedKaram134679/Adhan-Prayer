import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/update_info.dart';
import '../../models/update_progress.dart';
import '../cubit/update_cubit.dart';
import '../../../../core/localization/app_localizations.dart';

/// Modal dialog shown when a new update is available or during download/install progress.
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  static Future<void> show(BuildContext context, UpdateInfo updateInfo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isForced,
      builder: (ctx) => PopScope(
        canPop: !updateInfo.isForced,
        child: BlocProvider.value(
          value: context.read<UpdateCubit>(),
          child: UpdateDialog(updateInfo: updateInfo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isForced = updateInfo.isForced;

    return BlocConsumer<UpdateCubit, UpdateState>(
      listener: (context, state) {
        if (state is UpdateErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context).translate('update_error')}: ${state.errorMessage}',
              ),
              backgroundColor: colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isDownloading = state is UpdateDownloadingState;
        final isVerifying = state is UpdateDownloadingState && state.progress.step == UpdateStep.verifyingSha256;
        final isReady = state is UpdateReadyToInstallState;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isForced ? Icons.warning_amber_rounded : Icons.system_update_rounded,
                color: isForced ? colorScheme.error : colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate(
                    isForced ? 'update_required' : 'update_available',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Version comparison badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).translate('current_version'),
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            updateInfo.currentVersion,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward_rounded, color: colorScheme.primary, size: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppLocalizations.of(context).translate('latest_version'),
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            updateInfo.targetVersion,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // File size info
                if ((updateInfo.platformRelease?.size ?? 0) > 0) ...[
                  Text(
                    '${AppLocalizations.of(context).translate('file_size')}: '
                    '${((updateInfo.platformRelease!.size!) / (1024 * 1024)).toStringAsFixed(2)} MB',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                  const SizedBox(height: 8),
                ],

                // Release notes
                if (updateInfo.releaseNotes.isNotEmpty) ...[
                  Text(
                    AppLocalizations.of(context).translate('whats_new'),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 140),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: updateInfo.releaseNotes
                            .map(
                              (note) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• ', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(
                                        note,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Progress indicator during download / verification
                if (state is UpdateDownloadingState && state.progress.step != UpdateStep.verifyingSha256) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: state.progress.percentage,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('downloading_update'),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '${(state.progress.percentage * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ] else if (isVerifying) ...[
                  const SizedBox(height: 6),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context).translate('verifying_integrity'),
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ] else if (isReady) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context).translate('update_success'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!isForced && !isDownloading && !isReady)
              TextButton(
                onPressed: () {
                  context.read<UpdateCubit>().dismissUpdate();
                  Navigator.of(context).pop();
                },
                child: Text(AppLocalizations.of(context).translate('later')),
              ),
            if (!isDownloading && !isReady)
              FilledButton.icon(
                onPressed: () {
                  context.read<UpdateCubit>().downloadUpdate(updateInfo);
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(AppLocalizations.of(context).translate('download_and_install')),
              ),
            if (state is UpdateReadyToInstallState)
              FilledButton.icon(
                onPressed: () {
                  context.read<UpdateCubit>().installUpdate(updateInfo, state.filePath);
                },
                icon: const Icon(Icons.install_mobile_rounded, size: 18),
                label: Text(AppLocalizations.of(context).translate('install_now')),
              ),
          ],
        );
      },
    );
  }
}
