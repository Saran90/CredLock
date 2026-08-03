import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/health_report.dart';
import '../../core/services/health_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/password_entry.dart';
import '../create/create_password_screen.dart';

class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen>
    with SingleTickerProviderStateMixin {
  HealthReport? _report;
  bool _loading = true;

  late final AnimationController _scoreAnim;
  late final Animation<double> _scoreProgress;

  @override
  void initState() {
    super.initState();
    _scoreAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scoreProgress = CurvedAnimation(
      parent: _scoreAnim,
      curve: Curves.easeOutCubic,
    );
    _load();
  }

  @override
  void dispose() {
    _scoreAnim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _scoreAnim.reset();
    final report = await HealthService.instance.compute();
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
    _scoreAnim.forward();
  }

  Future<void> _openEdit(PasswordEntry entry) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreatePasswordScreen(entry: entry)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Health'),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _load,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final report = _report!;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          // ── Score ring ──────────────────────────────────────────────────
          Center(
            child: _ScoreRing(report: report, progress: _scoreProgress),
          ),
          const SizedBox(height: 32),

          if (report.totalEntries == 0) ...[
            Center(
              child: Text(
                'Add passwords to your vault to see your security score.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ] else if (report.issueCount == 0) ...[
            _AllClearCard(),
          ] else ...[
            Text(
              'ISSUES TO FIX',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 10),

            if (report.reusedEntries.isNotEmpty)
              _IssueCard(
                icon: Icons.copy_outlined,
                iconColor: const Color(0xFFE53935),
                title:
                    '${report.reusedEntries.length} Reused password${report.reusedEntries.length > 1 ? 's' : ''}',
                subtitle:
                    'Different accounts share the same password. A breach on one compromises all.',
                entries: report.reusedEntries,
                onEntryTap: _openEdit,
              ),

            if (report.weakEntries.isNotEmpty)
              _IssueCard(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFFFF8C00),
                title:
                    '${report.weakEntries.length} Weak or fair password${report.weakEntries.length > 1 ? 's' : ''}',
                subtitle: 'These passwords are easy to guess or brute-force.',
                entries: report.weakEntries,
                onEntryTap: _openEdit,
              ),

            if (report.overdueEntries.isNotEmpty)
              _IssueCard(
                icon: Icons.schedule_outlined,
                iconColor: const Color(0xFFFFB347),
                title:
                    '${report.overdueEntries.length} Password${report.overdueEntries.length > 1 ? 's' : ''} due for a change',
                subtitle: "These haven't been updated in a while.",
                entries: report.overdueEntries,
                onEntryTap: _openEdit,
              ),

            if (report.emptyPasswordEntries.isNotEmpty)
              _IssueCard(
                icon: Icons.lock_open_outlined,
                iconColor: AppColors.textHint,
                title:
                    '${report.emptyPasswordEntries.length} Entr${report.emptyPasswordEntries.length > 1 ? 'ies' : 'y'} with no password',
                subtitle:
                    'Add a password or remove the entry if no longer needed.',
                entries: report.emptyPasswordEntries,
                onEntryTap: _openEdit,
              ),
          ],
        ],
      ),
    );
  }
}

// ── Score ring ─────────────────────────────────────────────────────────────

class _ScoreRing extends StatelessWidget {
  final HealthReport report;
  final Animation<double> progress;

  const _ScoreRing({required this.report, required this.progress});

  Color _scoreColor(int score) {
    if (score >= 90) return const Color(0xFF4CAF50);
    if (score >= 75) return const Color(0xFF8BC34A);
    if (score >= 50) return const Color(0xFFFFB347);
    if (score >= 25) return const Color(0xFFFF8C00);
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final score = report.score;
    final color = _scoreColor(score);

    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(180, 180),
                painter: _RingPainter(
                  progress: progress.value * (score / 100),
                  color: color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(progress.value * score).round()}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  Text(
                    report.scoreLabel.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: color,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.issueCount == 0
                        ? 'No issues'
                        : '${report.issueCount} issue${report.issueCount > 1 ? 's' : ''}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 12.0;
    const startAngle = -pi / 2;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── All-clear card ──────────────────────────────────────────────────────────

class _AllClearCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_outlined,
            color: Color(0xFF4CAF50),
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All clear!', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'No issues detected. Keep it up.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Issue card ───────────────────────────────────────────────────────────────

class _IssueCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<PasswordEntry> entries;
  final ValueChanged<PasswordEntry> onEntryTap;

  const _IssueCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.onEntryTap,
  });

  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.iconColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header row
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded entry list
            if (_expanded) ...[
              Divider(color: AppColors.divider, height: 1, thickness: 1),
              ...widget.entries.map(
                (entry) => InkWell(
                  onTap: () => widget.onEntryTap(entry),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 15,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Fix →',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: widget.iconColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
