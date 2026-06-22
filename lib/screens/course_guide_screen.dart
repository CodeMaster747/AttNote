// screens/course_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../models/course_model.dart';
import '../models/subject_model.dart';
import '../services/course_guide_service.dart';
import '../services/firestore_service.dart';

/// Course Guide: AI-built teaching plan with prerequisites, resources and
/// attendance-aware revision days. Staff can generate/regenerate; students see
/// it read-only.
class CourseGuideScreen extends StatefulWidget {
  final Subject subject;
  final bool readOnly;

  const CourseGuideScreen({
    super.key,
    required this.subject,
    this.readOnly = false,
  });

  @override
  State<CourseGuideScreen> createState() => _CourseGuideScreenState();
}

class _CourseGuideScreenState extends State<CourseGuideScreen> {
  final CourseGuideService _guideService = CourseGuideService();
  final FirestoreService _firestore = FirestoreService();

  // Content lives under the staff owner's subject document.
  String get _ownerId => widget.readOnly
      ? widget.subject.linkedStaffId
      : widget.subject.createdBy;
  String get _subjectId => widget.readOnly
      ? widget.subject.linkedStaffSubjectId
      : widget.subject.id;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Course Guide')),
      body: StreamBuilder<CourseGuide?>(
        stream: _firestore.streamGuide(_ownerId, _subjectId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final guide = snapshot.data;
          if (guide == null) {
            return widget.readOnly
                ? const EmptyState(
                    title: 'No guide yet',
                    message: 'Your staff hasn\'t generated a course guide.',
                    icon: Icons.auto_awesome_outlined,
                  )
                : _GenerateView(
                    subject: widget.subject,
                    service: _guideService,
                  );
          }
          return _GuideView(
            guide: guide,
            readOnly: widget.readOnly,
            onRegenerate: widget.readOnly
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Regenerate guide')),
                          body: _GenerateView(
                            subject: widget.subject,
                            service: _guideService,
                            popOnDone: true,
                          ),
                        ),
                      ),
                    ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generate view (staff)
// ---------------------------------------------------------------------------

class _GenerateView extends StatefulWidget {
  const _GenerateView({
    required this.subject,
    required this.service,
    this.popOnDone = false,
  });

  final Subject subject;
  final CourseGuideService service;
  final bool popOnDone;

  @override
  State<_GenerateView> createState() => _GenerateViewState();
}

class _GenerateViewState extends State<_GenerateView> {
  final FirestoreService _firestore = FirestoreService();
  final _syllabusCtrl = TextEditingController();

  List<CourseTest> _tests = [];
  CourseTest? _selectedTest;
  bool _loadingTests = true;
  bool _extracting = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  @override
  void dispose() {
    _syllabusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTests() async {
    final tests =
        await _firestore.getTests(widget.subject.createdBy, widget.subject.id);
    if (!mounted) return;
    setState(() {
      _tests = tests;
      _selectedTest = tests.isNotEmpty ? tests.first : null;
      _loadingTests = false;
    });
  }

  Future<void> _extract() async {
    setState(() => _extracting = true);
    final text = await widget.service.extractSyllabusText(widget.subject);
    if (!mounted) return;
    setState(() => _extracting = false);
    if (text == null || text.trim().isEmpty) {
      _snack('Could not read the uploaded file — paste the syllabus manually.');
      return;
    }
    setState(() => _syllabusCtrl.text = text);
    _snack('Syllabus text extracted — review and edit if needed.');
  }

  Future<void> _generate() async {
    if (!widget.service.aiAvailable) {
      _snack('Add a Groq API key in .env to generate the guide.');
      return;
    }
    if (_selectedTest == null) {
      _snack('Add a test first (date + portion).');
      return;
    }
    if (_syllabusCtrl.text.trim().isEmpty) {
      _snack('Provide the syllabus text.');
      return;
    }
    setState(() => _generating = true);
    try {
      final holidays =
          await widget.service.extractHolidayDates(widget.subject);
      final guide = await widget.service.generateGuide(
        subject: widget.subject,
        test: _selectedTest!,
        syllabusText: _syllabusCtrl.text.trim(),
        holidays: holidays,
      );
      if (!mounted) return;
      if (guide == null) {
        _snack('Generation failed. Check your key/connection and retry.');
      } else {
        _snack('Course guide generated.');
        if (widget.popOnDone) Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final hasSyllabusFile = widget.subject.syllabusUrl != null;

    if (_loadingTests) {
      return const Center(child: CircularProgressIndicator());
    }

    return AbsorbPointer(
      absorbing: _generating,
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          if (!widget.service.aiAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'No Groq API key configured. Add GROQ_API_KEY to .env to '
                  'enable generation.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
          SectionHeader(
            title: 'Generate guide',
            subtitle: 'AI orders topics and schedules them onto your teaching days',
          ),
          const Gap(AppSpacing.md),
          Text('Test', style: theme.textTheme.labelMedium
              ?.copyWith(color: colors.textSecondary)),
          const Gap(AppSpacing.xs),
          AppCard(
            child: _tests.isEmpty
                ? Text('No tests yet. Add one in the subject\'s Tests tab.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textTertiary))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<CourseTest>(
                      isExpanded: true,
                      value: _selectedTest,
                      items: _tests
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  '${t.name} · ${DateFormat('d MMM').format(t.date)}',
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTest = v),
                    ),
                  ),
          ),
          const Gap(AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text('Syllabus text',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.textSecondary)),
              ),
              if (hasSyllabusFile)
                TextButton.icon(
                  onPressed: _extracting ? null : _extract,
                  icon: _extracting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Extract from file'),
                ),
            ],
          ),
          const Gap(AppSpacing.xs),
          AppTextField(
            controller: _syllabusCtrl,
            hintText: 'Paste or extract the syllabus (unit-wise topics)…',
            maxLines: 10,
          ),
          const Gap(AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating ? 'Generating…' : 'Generate guide'),
            ),
          ),
          const Gap(AppSpacing.lg),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Guide view
// ---------------------------------------------------------------------------

class _GuideView extends StatelessWidget {
  const _GuideView({
    required this.guide,
    required this.readOnly,
    this.onRegenerate,
  });

  final CourseGuide guide;
  final bool readOnly;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(guide.testName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        )),
                  ),
                  if (!readOnly && onRegenerate != null)
                    TextButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Regenerate'),
                    ),
                ],
              ),
              const Gap(2),
              Text(
                'Exam ${DateFormat('d MMM yyyy').format(guide.examDate)} · '
                '${guide.topics.where((t) => !t.isRevision).length} topics · '
                '${guide.topics.where((t) => t.isRevision).length} revision slots',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
        const Gap(AppSpacing.md),
        ...guide.topics.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _TopicTile(topic: t),
            )),
        const Gap(AppSpacing.lg),
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});
  final GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final dateStr = topic.date != null
        ? DateFormat('EEE, d MMM').format(topic.date!)
        : 'Unscheduled';

    return AppCard(
      onTap: () => _showTopicSheet(context, topic),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: topic.isRevision ? colors.warning : colors.success,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(topic.topic,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          )),
                    ),
                    if (topic.isRevision) ...[
                      const Gap(AppSpacing.xs),
                      _Tag(text: 'Revision', color: colors.warning),
                    ],
                  ],
                ),
                const Gap(2),
                Text(
                  '$dateStr${topic.unit.isNotEmpty ? ' · ${topic.unit}' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

Future<void> _showTopicSheet(BuildContext context, GuideTopic topic) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final colors = AppColors.of(context);
      final theme = Theme.of(context);
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, controller) => Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: colors.border),
          ),
          child: ListView(
            controller: controller,
            padding: AppSpacing.cardPadding,
            children: [
              Text(topic.topic,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  )),
              if (topic.unit.isNotEmpty) ...[
                const Gap(2),
                Text(topic.unit,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textTertiary)),
              ],
              const Gap(AppSpacing.lg),
              Text('Prerequisites',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  )),
              const Gap(AppSpacing.xs),
              if (topic.prerequisites.isEmpty)
                Text('None listed.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textTertiary))
              else
                ...topic.prerequisites.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 16, color: colors.textTertiary),
                          const Gap(AppSpacing.xs),
                          Expanded(
                            child: Text(p,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: colors.textSecondary)),
                          ),
                        ],
                      ),
                    )),
              const Gap(AppSpacing.lg),
              Text('Resources',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  )),
              const Gap(AppSpacing.xs),
              if (topic.resources.isEmpty)
                Text('None listed.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textTertiary))
              else
                ...topic.resources.map((r) => _ResourceRow(resource: r)),
              const Gap(AppSpacing.lg),
            ],
          ),
        ),
      );
    },
  );
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.resource});
  final GuideResource resource;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(resource.url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        onTap: () => _open(context),
        child: Row(
          children: [
            Icon(
              resource.isYouTube
                  ? Icons.play_circle_outline
                  : Icons.link_rounded,
              size: 18,
              color: colors.textSecondary,
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: Text(
                resource.title.isEmpty ? resource.url : resource.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.textPrimary),
              ),
            ),
            Icon(Icons.open_in_new, size: 14, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
