// screens/ai_insights_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../services/attendance_prediction_service.dart';

/// Student-facing AI insights: predicts when each subject's attendance will
/// dip below 75% and recommends action. Math is deterministic; Groq adds a
/// plain-language explanation when a key is configured.
class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final AttendancePredictionService _service = AttendancePredictionService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  List<AttendanceRisk> _risks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final risks = await _service.computeAll(uid);
    if (!mounted) return;
    setState(() {
      _risks = risks.where((r) => r.hasData).toList();
      _loading = false;
    });
    // Lazily fetch AI insights for at-risk / below subjects.
    if (_service.aiAvailable) {
      for (final r in _risks) {
        if (r.level != RiskLevel.safe) {
          _service.generateInsight(r).then((text) {
            if (!mounted || text == null) return;
            setState(() => r.aiInsight = text);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('AI insights')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: AppSpacing.pagePadding,
                children: [
                  if (!_service.aiAvailable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _InfoBanner(
                        icon: Icons.info_outline,
                        text:
                            'AI explanations are off (no Groq key). Predictions '
                            'below still work — they\'re calculated locally.',
                      ),
                    ),
                  Text(
                    'Predictions of when each subject may fall below 75%.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textTertiary),
                  ),
                  const Gap(AppSpacing.md),
                  if (_risks.isEmpty)
                    const EmptyState(
                      title: 'No attendance data',
                      message:
                          'Mark some attendance and predictions will appear here.',
                      icon: Icons.query_stats_outlined,
                    )
                  else
                    ..._risks.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _RiskCard(risk: r),
                        )),
                  const Gap(AppSpacing.lg),
                ],
              ),
            ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.risk});
  final AttendanceRisk risk;

  Color _color(AppColors colors) {
    switch (risk.level) {
      case RiskLevel.below:
        return colors.danger;
      case RiskLevel.atRisk:
        return colors.warning;
      case RiskLevel.safe:
        return colors.success;
    }
  }

  String _label() {
    switch (risk.level) {
      case RiskLevel.below:
        return 'Below 75%';
      case RiskLevel.atRisk:
        return 'At risk';
      case RiskLevel.safe:
        return 'On track';
    }
  }

  String _headline() {
    if (risk.level == RiskLevel.below) {
      return risk.classesToRecover > 0
          ? 'Attend the next ${risk.classesToRecover} class'
              '${risk.classesToRecover == 1 ? '' : 'es'} to reach 75%.'
          : 'Just below 75% — attend the next class to recover.';
    }
    if (risk.projectedBelowDate != null) {
      return 'May fall below 75% around '
          '${DateFormat('d MMM yyyy').format(risk.projectedBelowDate!)} '
          'at your current pace.';
    }
    return 'You can miss ${risk.missableClasses} more class'
        '${risk.missableClasses == 1 ? '' : 'es'} and stay above 75%.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final c = _color(colors);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(risk.subjectName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    )),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: c.withValues(alpha: 0.4)),
                ),
                child: Text(_label(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: c,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          Row(
            children: [
              Text('${risk.currentPct.toStringAsFixed(0)}%',
                  style: theme.textTheme.headlineSmall?.copyWith(color: c)),
              const Gap(AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: (risk.currentPct / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: colors.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(c),
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(_headline(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.textSecondary)),
          if (risk.aiInsight != null) ...[
            const Gap(AppSpacing.sm),
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 16, color: colors.textTertiary),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Text(risk.aiInsight!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.textSecondary)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
