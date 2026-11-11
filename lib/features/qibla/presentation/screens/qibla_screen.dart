import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../cubit/qibla_cubit.dart';
import '../cubit/qibla_state.dart';
import '../widgets/qibla_compass_dial.dart';

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<QiblaCubit>()..initQibla(),
      child: const _QiblaScreenView(),
    );
  }
}

class _QiblaScreenView extends StatelessWidget {
  const _QiblaScreenView();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('qibla_direction')),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: loc.translate('refresh_location'),
            onPressed: () {
              context.read<QiblaCubit>().refreshLocation();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<QiblaCubit, QiblaState>(
          listener: (context, state) {
            // Listen for any critical notifications if needed
          },
          builder: (context, state) {
            if (state is QiblaLoadingLocation) {
              return _buildCenteredLoading(
                context,
                loc.translate('calculating_qibla'),
              );
            } else if (state is QiblaLocationServiceDisabled) {
              return _buildLocationServiceDisabled(context, loc);
            } else if (state is QiblaPermissionDenied) {
              return _buildPermissionDenied(context, loc, state.isPermanent);
            } else if (state is QiblaCalculating) {
              return _buildCenteredLoading(
                context,
                loc.translate('calculating_qibla'),
              );
            } else if (state is QiblaLoaded) {
              return _buildCompassView(context, loc, theme, isDark, state);
            } else if (state is QiblaError) {
              return _buildErrorView(context, loc, state.messageKey);
            }

            return _buildCenteredLoading(
              context,
              loc.translate('calculating_qibla'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCenteredLoading(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text(
            message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationServiceDisabled(
    BuildContext context,
    AppLocalizations loc,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 64, color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              loc.translate('location_services_disabled'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await Geolocator.openLocationSettings();
              },
              icon: const Icon(Icons.settings),
              label: Text(loc.translate('open_settings')),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                context.read<QiblaCubit>().initQibla();
              },
              child: Text(loc.translate('refresh_location')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied(
    BuildContext context,
    AppLocalizations loc,
    bool isPermanent,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.near_me_disabled_rounded, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              isPermanent
                  ? loc.translate('permission_permanently_denied')
                  : loc.translate('permission_denied'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              loc.translate('location_required_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                if (isPermanent) {
                  await Geolocator.openAppSettings();
                } else {
                  context.read<QiblaCubit>().initQibla();
                }
              },
              icon: Icon(isPermanent ? Icons.settings : Icons.location_on),
              label: Text(
                isPermanent
                    ? loc.translate('open_settings')
                    : loc.translate('enable_location'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    AppLocalizations loc,
    String messageKey,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              loc.translate(messageKey),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<QiblaCubit>().initQibla();
              },
              icon: const Icon(Icons.refresh),
              label: Text(loc.translate('refresh_location')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassView(
    BuildContext context,
    AppLocalizations loc,
    ThemeData theme,
    bool isDark,
    QiblaLoaded state,
  ) {
    final direction = state.direction;
    final hasSensor = state.isCompassAvailable && direction.deviceHeading != null;
    final relativeDiff = direction.relativeAngle ?? 0.0;

    // Aligned if relative angle is within +/- 3 degrees of 0 (or 360)
    final isAligned = hasSensor && (relativeDiff <= 3.0 || relativeDiff >= 357.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Alignment status banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isAligned
                  ? AppColors.primaryLight.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF1E222A) : const Color(0xFFF1F3F5)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isAligned
                    ? AppColors.primaryLight
                    : (isDark ? const Color(0xFF323846) : const Color(0xFFE4E6EB)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAligned ? Icons.check_circle : Icons.explore,
                  color: isAligned ? AppColors.primaryLight : AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isAligned
                      ? loc.translate('facing_qibla')
                      : (hasSensor
                          ? loc.translate('align_phone_with_arrow')
                          : loc.translate('compass_unavailable')),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isAligned ? FontWeight.bold : FontWeight.w500,
                    color: isAligned
                        ? AppColors.primaryLight
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Central Compass Dial
          QiblaCompassDial(
            qiblaBearing: direction.qiblaBearing,
            deviceHeading: direction.deviceHeading,
            isAlignedWithQibla: isAligned,
          ),

          const SizedBox(height: 28),

          // Numeric Bearing & Status Cards
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  context,
                  title: loc.translate('qibla_bearing'),
                  value: '${direction.qiblaBearing.toStringAsFixed(1)}°',
                  subtitle: _cardinalSubtitle(direction.qiblaBearing),
                  icon: Icons.explore_rounded,
                  accentColor: AppColors.accent,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  context,
                  title: loc.translate('qibla'),
                  value: direction.isOfflineFallback
                      ? loc.translate('using_offline_calculation')
                      : 'AlAdhan API',
                  subtitle: direction.isOfflineFallback
                      ? 'Local Math Fallback'
                      : 'Online Source',
                  icon: direction.isOfflineFallback ? Icons.offline_bolt : Icons.cloud_done,
                  accentColor: direction.isOfflineFallback ? AppColors.accent : AppColors.primaryLight,
                  isDark: isDark,
                  isSmallValue: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Device GPS Coordinates Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E222A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF2D323F) : const Color(0xFFE4E6EB),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 20, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('current_location'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${direction.latitude.toStringAsFixed(4)}°, ${direction.longitude.toStringAsFixed(4)}°',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    context.read<QiblaCubit>().refreshLocation();
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: Text(loc.translate('refresh_location'), style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          // Calibration prompt if high sensor jitter detected
          if (state.isCalibrating) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync_problem, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.translate('compass_calibration'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    bool isSmallValue = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2D323F) : const Color(0xFFE4E6EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallValue ? 13 : 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _cardinalSubtitle(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'North (N)';
    if (bearing >= 22.5 && bearing < 67.5) return 'North-East (NE)';
    if (bearing >= 67.5 && bearing < 112.5) return 'East (E)';
    if (bearing >= 112.5 && bearing < 157.5) return 'South-East (SE)';
    if (bearing >= 157.5 && bearing < 202.5) return 'South (S)';
    if (bearing >= 202.5 && bearing < 247.5) return 'South-West (SW)';
    if (bearing >= 247.5 && bearing < 292.5) return 'West (W)';
    return 'North-West (NW)';
  }
}
