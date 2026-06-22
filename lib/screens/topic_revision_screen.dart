// screens/topic_revision_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import '../models/attendance_model.dart';
import '../models/subject_model.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../services/analytics_service.dart';
import '../services/firestore_service.dart';

class TopicRevisionScreen extends StatefulWidget {
  const TopicRevisionScreen({super.key});

  @override
  State<TopicRevisionScreen> createState() => _TopicRevisionScreenState();
}

class _TopicRevisionScreenState extends State<TopicRevisionScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final FirestoreService _firestoreService = FirestoreService();
  final String staffId = FirebaseAuth.instance.currentUser!.uid;

  List<Subject> _subjects = [];
  Subject? _selected;
  List<TopicRevisionSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    try {
      final all = await _firestoreService.getSubjects(staffId);
      final staffSubjects = all.where((s) => s.isStaffOwned).toList();
      if (!mounted) return;
      setState(() {
        _subjects = staffSubjects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading subjects: $e')));
    }
  }

  Future<void> _loadSuggestions() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() => _isLoadingSuggestions = true);
    try {
      final suggestions = await _analyticsService.getTopicRevisionSuggestions(
        selected.studentIds,
        selected.id,
        selected.name,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading suggestions: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Topic revision')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    title: 'Select a subject',
                    subtitle: 'Suggestions are ranked by absences across the roster',
                  ),
                  const Gap(AppSpacing.sm),
                  AppCard(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Subject>(
                        isExpanded: true,
                        value: _selected,
                        hint: const Text('Choose a subject'),
                        items: _subjects
                            .map(
                              (s) => DropdownMenuItem<Subject>(
                                value: s,
                                child: Text(
                                  s.section.isNotEmpty
                                      ? '${s.name} · ${s.section}'
                                      : s.name,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selected = value;
                            _suggestions = [];
                          });
                          _loadSuggestions();
                        },
                      ),
                    ),
                  ),
                  const Gap(AppSpacing.lg),
                  Expanded(
                    child: _selected == null
                        ? const EmptyState(
                            title: 'No subject selected',
                            message: 'Pick a subject to see revision suggestions.',
                            icon: Icons.touch_app_outlined,
                          )
                        : _isLoadingSuggestions
                            ? const Center(child: CircularProgressIndicator())
                            : _suggestions.isEmpty
                                ? const EmptyState(
                                    title: 'No suggestions yet',
                                    message:
                                        'Add students and record attendance to generate suggestions.',
                                    icon: Icons.lightbulb_outline,
                                  )
                                : ListView.separated(
                                    itemCount: _suggestions.length,
                                    separatorBuilder: (_, __) =>
                                        const Gap(AppSpacing.sm),
                                    itemBuilder: (context, index) {
                                      final s = _suggestions[index];
                                      return AppCard(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                _RankBadge(rank: index + 1),
                                                const Gap(AppSpacing.sm),
                                                Expanded(
                                                  child: Text(
                                                    s.displayName,
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: colors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Gap(AppSpacing.sm),
                                            Text(
                                              '${s.absentCount} of ${s.totalStudents} students absent',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                            const Gap(AppSpacing.xs),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.sm),
                                              child: LinearProgressIndicator(
                                                value: s.absentPercentage / 100,
                                                minHeight: 6,
                                                backgroundColor:
                                                    colors.surfaceMuted,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        colors.danger),
                                              ),
                                            ),
                                            const Gap(AppSpacing.xs),
                                            Text(
                                              '${s.absentPercentage.toStringAsFixed(0)}% absent',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: colors.danger,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final color = rank == 1
        ? colors.danger
        : rank == 2
            ? colors.warning
            : colors.textSecondary;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
