import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import 'login_screen.dart';

/// Pre-auth landing experience. Refined to a SaaS-grade marketing surface:
/// flat colors, tight rhythm, restrained accents.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  static const _breakpoint = 880.0;
  static const _maxContentWidth = 1120.0;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _scrollToFeatures() {
    final ctx = _featuresKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _TopBar(onGetStarted: _goToAuth)),
                SliverToBoxAdapter(
                  child: _Hero(
                    onGetStarted: _goToAuth,
                    onLearnMore: _scrollToFeatures,
                  ),
                ),
                const SliverToBoxAdapter(child: _StatsStrip()),
                SliverToBoxAdapter(
                  key: _featuresKey,
                  child: const _FeatureSection(
                    eyebrow: 'Attendance',
                    title: 'Track every class with confidence.',
                    description:
                        'Mark presence in seconds, monitor cumulative percentages, '
                        'and never lose sight of attendance thresholds across the '
                        'semester.',
                    bullets: [
                      'One-tap session marking for staff and students',
                      'Cumulative percentage tracking per subject',
                      'Past attendance correction with audit trail',
                    ],
                    icon: Icons.fact_check_outlined,
                    imageLeft: false,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: _FeatureSection(
                    eyebrow: 'Course content',
                    title: 'Share notes where they belong.',
                    description:
                        'Staff plan each teaching day with a topic and notes, and '
                        'add students by email — no join requests. Students open '
                        'the subject and find everything in clean, collapsible rows.',
                    bullets: [
                      'Per-day topics and notes attached to each subject',
                      'Collapsible day-wise, notes, and custom content rows',
                      'Add students by email — staff stay in control',
                    ],
                    icon: Icons.menu_book_outlined,
                    imageLeft: true,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: _FeatureSection(
                    eyebrow: 'Insights',
                    title: 'See the patterns behind the numbers.',
                    description:
                        'Visualize attendance trends, identify subjects that need '
                        'attention, and make informed decisions backed by clean '
                        'analytics.',
                    bullets: [
                      'Trend charts across weeks and months',
                      'Per-subject and per-student breakdowns',
                      'Designed for clarity, not noise',
                    ],
                    icon: Icons.insights_outlined,
                    imageLeft: false,
                  ),
                ),
                SliverToBoxAdapter(child: _CtaBand(onGetStarted: _goToAuth)),
                const SliverToBoxAdapter(child: _Footer()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Top bar
// ----------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const AppLogo(size: 36),
              const Gap(AppSpacing.sm),
              Text(
                'AttNote',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              AppTextButton(label: 'Sign in', onPressed: onGetStarted),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Hero
// ----------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.onGetStarted, required this.onLearnMore});

  final VoidCallback onGetStarted;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= LandingScreen._breakpoint;

    final textBlock = Column(
      crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        _Pill(
          label: 'Attendance + Notes, finally together',
          icon: Icons.auto_awesome_outlined,
        ),
        const Gap(AppSpacing.lg),
        Text(
          'A calmer way to run\nyour academic day.',
          textAlign: isWide ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const Gap(AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'AttNote brings attendance tracking and lecture notes into one '
            'focused workspace, so students and staff stop juggling tools and '
            'start trusting the record.',
            textAlign: isWide ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
          ),
        ),
        const Gap(AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            AppPrimaryButton(
              label: 'Get started',
              icon: Icons.arrow_forward_rounded,
              onPressed: onGetStarted,
            ),
            AppSecondaryButton(
              label: 'Learn more',
              icon: Icons.south_rounded,
              onPressed: onLearnMore,
            ),
          ],
        ),
        const Gap(AppSpacing.sm),
        Text(
          'Free for students · No credit card required',
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
      ],
    );

    const visual = _HeroVisual();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: isWide ? AppSpacing.xxl : AppSpacing.lg,
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: textBlock),
                    const Gap(AppSpacing.xl),
                    const Expanded(flex: 5, child: visual),
                  ],
                )
              : Column(
                  children: [
                    textBlock,
                    const Gap(AppSpacing.xl),
                    visual,
                  ],
                ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.textSecondary),
          const Gap(6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Hero visual — calm mock of the product surface.
// ----------------------------------------------------------------------------

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: colors.border),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 28),
                      const Gap(AppSpacing.xs),
                      Text(
                        'Today',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const _MiniChip(label: '92%'),
                    ],
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Column(
                      children: const [
                        _MockRow(
                          subject: 'Operating Systems',
                          meta: '10:00 · Lab 4',
                          status: _RowStatus.present,
                        ),
                        Gap(AppSpacing.xs),
                        _MockRow(
                          subject: 'Linear Algebra',
                          meta: '11:30 · Room 207',
                          status: _RowStatus.present,
                        ),
                        Gap(AppSpacing.xs),
                        _MockRow(
                          subject: 'Discrete Math',
                          meta: '14:00 · Room 301',
                          status: _RowStatus.upcoming,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -8,
            bottom: -16,
            child: Container(
              width: 200,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 12,
                        color: colors.textTertiary,
                      ),
                      const Gap(6),
                      Text(
                        'Lecture notes',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Gap(10),
                  const _Bar(width: 140, opacity: 0.9),
                  const Gap(6),
                  const _Bar(width: 110, opacity: 0.6),
                  const Gap(6),
                  const _Bar(width: 84, opacity: 0.4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _RowStatus { present, upcoming }

class _MockRow extends StatelessWidget {
  const _MockRow({
    required this.subject,
    required this.meta,
    required this.status,
  });

  final String subject;
  final String meta;
  final _RowStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final isPresent = status == _RowStatus.present;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.border),
            ),
            child: Icon(
              isPresent ? Icons.check_rounded : Icons.schedule_rounded,
              size: 14,
              color: isPresent ? colors.success : colors.textTertiary,
            ),
          ),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  meta,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, this.opacity = 0.5});

  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 6,
      width: width,
      decoration: BoxDecoration(
        color: colors.textTertiary.withValues(alpha: opacity * 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Stats strip
// ----------------------------------------------------------------------------

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    const items = [
      _Stat(value: '3 sec', label: 'to mark a session'),
      _Stat(value: '1 home', label: 'for notes + attendance'),
      _Stat(value: 'Live', label: 'syncing across devices'),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                if (isNarrow) {
                  return Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        items[i],
                        if (i != items.length - 1) const Gap(AppSpacing.sm),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      Expanded(child: Center(child: items[i])),
                      if (i != items.length - 1)
                        Container(
                          width: 1,
                          height: 24,
                          color: colors.border,
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Feature section — alternating left / right.
// ----------------------------------------------------------------------------

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.bullets,
    required this.icon,
    required this.imageLeft,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<String> bullets;
  final IconData icon;
  final bool imageLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= LandingScreen._breakpoint;

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const Gap(AppSpacing.sm),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const Gap(AppSpacing.sm),
        Text(
          description,
          style: theme.textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
        ),
        const Gap(AppSpacing.md),
        for (final bullet in bullets) ...[
          _BulletLine(text: bullet),
          const Gap(AppSpacing.xs),
        ],
      ],
    );

    final visual = _FeatureVisual(icon: icon);

    final row = isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: imageLeft
                ? [
                    Expanded(flex: 5, child: visual),
                    const Gap(AppSpacing.xxl),
                    Expanded(flex: 6, child: textColumn),
                  ]
                : [
                    Expanded(flex: 6, child: textColumn),
                    const Gap(AppSpacing.xxl),
                    Expanded(flex: 5, child: visual),
                  ],
          )
        : Column(
            children: [
              visual,
              const Gap(AppSpacing.xl),
              textColumn,
            ],
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: isWide ? AppSpacing.xxl : AppSpacing.xl,
          ),
          child: row,
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: colors.textSecondary,
          ),
        ),
        const Gap(AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureVisual extends StatelessWidget {
  const _FeatureVisual({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: colors.border),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < 2) const Gap(6),
                  ],
                ],
              ),
            ),
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(icon, size: 36, color: colors.textSecondary),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _Bar(width: 120, opacity: 0.9),
                  Gap(6),
                  _Bar(width: 80, opacity: 0.55),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// CTA band
// ----------------------------------------------------------------------------

class _CtaBand extends StatelessWidget {
  const _CtaBand({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              color: colors.surface,
              border: Border.all(color: colors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 560;
                final headline = Text(
                  'Ready to bring order to attendance and notes?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.textPrimary,
                  ),
                );
                final sub = Text(
                  'Set up your account in under a minute.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                );
                final cta = AppPrimaryButton(
                  label: 'Get started',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onGetStarted,
                );
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headline,
                      const Gap(AppSpacing.xs),
                      sub,
                      const Gap(AppSpacing.lg),
                      cta,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headline,
                          const Gap(AppSpacing.xs),
                          sub,
                        ],
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    cta,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Footer
// ----------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer();

  static const _support = <String>[
    'Help Center',
    'FAQs',
    'Report a bug',
    'Service status',
  ];
  static const _learn = <String>[
    'Getting started',
    'Video tutorials',
    'Best practices',
    'Release notes',
  ];
  static const _contact = <String>[
    'Email us',
    'Twitter / X',
    'GitHub',
    'Privacy policy',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= LandingScreen._breakpoint;

    final columns = <Widget>[
      _FooterColumn(title: 'Get Support', items: _support),
      _FooterColumn(title: 'Learn to Use', items: _learn),
      _FooterColumn(title: 'Contact Us', items: _contact),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 32),
                    const Gap(AppSpacing.sm),
                    Text(
                      'AttNote',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const Gap(AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Text(
                    'Attendance tracking and notes sharing for students and '
                    'staff, in one focused workspace.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
                const Gap(AppSpacing.xl),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < columns.length; i++) ...[
                        Expanded(child: columns[i]),
                        if (i != columns.length - 1) const Gap(AppSpacing.lg),
                      ],
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < columns.length; i++) ...[
                        columns[i],
                        if (i != columns.length - 1) const Gap(AppSpacing.xl),
                      ],
                    ],
                  ),
                const Gap(AppSpacing.xl),
                Divider(color: colors.border, height: 1),
                const Gap(AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      '© ${DateTime.now().year} AttNote. All rights reserved.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    Text(
                      'Made for students and staff.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const Gap(AppSpacing.sm),
        for (final item in items)
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                item,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
