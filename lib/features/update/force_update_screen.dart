import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Full-screen, non-dismissible update wall shown when the running version
/// is below [UpdateInfo.minRequiredVersion].
/// The user cannot proceed until they update the app.
class ForceUpdateScreen extends StatelessWidget {
  final UpdateInfo info;

  const ForceUpdateScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    // PopScope with canPop: false ensures back button cannot bypass the wall.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Ambient blobs (matches splash screen style) ───────────────
            _AmbientBlob(
              alignment: const Alignment(0.7, -0.8),
              color: AppColors.primaryDark.withValues(alpha: 0.15),
              size: MediaQuery.of(context).size.width * 0.65,
            ),
            _AmbientBlob(
              alignment: const Alignment(-0.8, 0.9),
              color: AppColors.primary.withValues(alpha: 0.10),
              size: MediaQuery.of(context).size.width * 0.55,
            ),

            // ── Main content ──────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.black,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      'Update Required',
                      style: AppTextStyles.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      'Version ${info.currentVersion} is no longer supported. '
                      'Please update to version ${info.latestVersion} to continue using CredLock.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Release notes (if any)
                    if (info.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "WHAT'S NEW",
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              info.releaseNotes,
                              style: AppTextStyles.bodySmall.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Update button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openStore(info.updateUrl),
                            child: Center(
                              child: Text(
                                'UPDATE NOW',
                                style: AppTextStyles.buttonText.copyWith(
                                  color: Colors.black,
                                  fontSize: 15,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Version info
                    Text(
                      'Current: v${info.currentVersion}  ·  Latest: v${info.latestVersion}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Ambient blob (mirrors splash_screen.dart) ─────────────────────────────

class _AmbientBlob extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double size;

  const _AmbientBlob({
    required this.alignment,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}
