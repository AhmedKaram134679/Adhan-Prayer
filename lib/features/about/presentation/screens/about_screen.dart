import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adhan_and_prayer/core/config/app_branding.dart';
import 'package:adhan_and_prayer/core/localization/app_localizations.dart';
import 'package:adhan_and_prayer/core/platform/external_launcher.dart';
import 'package:adhan_and_prayer/core/theme/app_theme.dart';

/// Standalone, professional About the App screen.
/// Responsibility: Present the identity of the Developer, Academy attribution,
/// social connectivity, and comprehensive application information.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _hasCustomPhoto = false;

  @override
  void initState() {
    super.initState();
    _checkDeveloperPhoto();
  }

  Future<void> _checkDeveloperPhoto() async {
    try {
      await rootBundle.load(AppBranding.developerPhotoAsset);
      if (mounted) {
        setState(() => _hasCustomPhoto = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasCustomPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = loc.locale.languageCode == 'ar';
    final academyName = isArabic ? AppBranding.academyNameAr : AppBranding.academyNameEn;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('about_app')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // SECTION 1: Application Identity Card
              _buildAppIdentityCard(theme, loc, isDark),
              const SizedBox(height: 20),

              // SECTION 2: Developer & Academy Profile Card
              _buildDeveloperProfileCard(theme, loc, isDark, academyName),
              const SizedBox(height: 20),

              // SECTION 3: Application Capabilities Card
              _buildCapabilitiesCard(theme, loc, isDark),
              const SizedBox(height: 24),

              // Footer Version & Attribution
              Text(
                '${loc.translate('app_name')} • ${loc.translate('version')} ${AppBranding.appVersion}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIdentityCard(ThemeData theme, AppLocalizations loc, bool isDark) {
    return Card(
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            // App Logo
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: isDark ? AppColors.primaryLight : AppColors.accentLight,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  AppBranding.appLogoAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.mosque,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // App Name
            Text(
              loc.translate('app_name'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Version Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primary : AppColors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${loc.translate('version')} ${AppBranding.appVersion}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.accentLight : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Description
            Text(
              loc.translate('app_description'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperProfileCard(
    ThemeData theme,
    AppLocalizations loc,
    bool isDark,
    String academyName,
  ) {
    return Card(
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Column(
          children: [
            // Developer Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    isDark ? AppColors.primaryLight : AppColors.primary,
                    isDark ? AppColors.accentLight : AppColors.accent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.primaryLight : AppColors.primary)
                        .withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                ),
                child: ClipOval(
                  child: _hasCustomPhoto
                      ? Image.asset(
                          AppBranding.developerPhotoAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(isDark),
                        )
                      : _buildAvatarFallback(isDark),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Developed by label
            Text(
              loc.translate('developed_by'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? AppColors.accentLight : AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),

            // Developer Name
            Text(
              AppBranding.developerName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Academy Attribution
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 18,
                    color: isDark ? AppColors.accentLight : AppColors.accentDark,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      academyName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Social Media / Contact Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await ExternalLauncher.openUrl(AppBranding.socialMediaUrl);
                },
                borderRadius: BorderRadius.circular(14),
                splashColor: AppColors.accent.withValues(alpha: 0.2),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.accentLight.withValues(alpha: 0.4)
                          : AppColors.accentDark.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 18,
                        color: isDark ? AppColors.accentLight : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${loc.translate('connect')} • ${AppBranding.socialMediaDisplay}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.accentLight : AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: isDark ? AppColors.accentLight : AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilitiesCard(ThemeData theme, AppLocalizations loc, bool isDark) {
    final features = [
      {'icon': Icons.offline_pin_outlined, 'key': 'feature_offline'},
      {'icon': Icons.notifications_active_outlined, 'key': 'feature_adhan'},
      {'icon': Icons.tune_outlined, 'key': 'feature_methods'},
      {'icon': Icons.devices_outlined, 'key': 'feature_cross_platform'},
    ];

    return Card(
      elevation: isDark ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  color: isDark ? AppColors.accentLight : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  loc.translate('features_highlight'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...features.map((f) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 18,
                      color: isDark ? AppColors.accentLight : AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        loc.translate(f['key'] as String),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.primary.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 50,
          color: isDark ? AppColors.accentLight : AppColors.primary,
        ),
      ),
    );
  }
}
