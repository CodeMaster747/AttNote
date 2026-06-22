// screens/create_subject_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/widgets.dart';
import '../models/course_model.dart';
import '../models/subject_model.dart';
import '../services/file_service.dart';
import '../services/firestore_service.dart';
import '../widgets/test_editor_sheet.dart';

const List<String> kWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Staff-side subject creation. Replaces the old "create class" flow.
class CreateSubjectScreen extends StatefulWidget {
  const CreateSubjectScreen({super.key});

  @override
  State<CreateSubjectScreen> createState() => _CreateSubjectScreenState();
}

class _CreateSubjectScreenState extends State<CreateSubjectScreen> {
  final _nameCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  final FirestoreService _service = FirestoreService();
  final FileService _fileService = FileService();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  final Set<String> _taughtDays = {};
  final List<_RosterEntry> _roster = [];
  final List<CourseTest> _tests = [];

  Map<String, String>? _syllabus;
  Map<String, String>? _holiday;
  bool _courseGuideEnabled = false;

  bool _resolvingEmail = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _deptCtrl.dispose();
    _semesterCtrl.dispose();
    _sectionCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _addStudentEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    if (_roster.any((r) => r.email.toLowerCase() == email.toLowerCase())) {
      _snack('Already added');
      return;
    }
    setState(() => _resolvingEmail = true);
    final user = await _service.findUserByEmail(email);
    if (!mounted) return;
    setState(() => _resolvingEmail = false);

    if (user == null) {
      _snack('No account found for "$email"');
      return;
    }
    if ((user['role'] ?? 'student') != 'student') {
      _snack('"$email" is not a student account');
      return;
    }
    setState(() {
      _roster.add(_RosterEntry(
        email: email,
        name: (user['name'] ?? email).toString(),
      ));
      _emailCtrl.clear();
    });
  }

  Future<void> _pickSyllabus() async {
    final res = await _fileService.uploadDocument(folder: 'syllabi');
    if (res != null && mounted) setState(() => _syllabus = res);
  }

  Future<void> _pickHoliday() async {
    final res = await _fileService.uploadDocument(folder: 'holidays');
    if (res != null && mounted) setState(() => _holiday = res);
  }

  Future<void> _addTest() async {
    final test = await TestEditorSheet.show(context);
    if (test != null) setState(() => _tests.add(test));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Enter a subject name');
      return;
    }
    setState(() => _saving = true);
    try {
      final section = '${_semesterCtrl.text.trim()}${_sectionCtrl.text.trim()}';
      final timetable = {for (final d in _taughtDays) d: 1};

      final subject = Subject(
        id: '',
        name: name,
        createdBy: uid,
        ownerRole: 'staff',
        department: _deptCtrl.text.trim(),
        section: section,
        taughtDays: _taughtDays.toList(),
        timetable: timetable,
        courseGuideEnabled: _courseGuideEnabled,
        syllabusUrl: _syllabus?['url'],
        syllabusFileName: _syllabus?['fileName'],
        holidayUrl: _holiday?['url'],
        holidayFileName: _holiday?['fileName'],
      );

      final id = await _service.createStaffSubject(uid, subject);
      final created = await _service.getSubject(uid, id);

      // Add roster students.
      if (created != null) {
        for (final entry in _roster) {
          await _service.addStudentToStaffSubjectByEmail(created, entry.email);
        }
      }

      // Persist tests.
      for (final t in _tests) {
        await _service.upsertTest(uid, id, t);
      }

      if (!mounted) return;
      _snack('Subject created');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack('Error creating subject: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Create subject')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            SectionHeader(title: 'Details'),
            const Gap(AppSpacing.sm),
            AppTextField(
              controller: _nameCtrl,
              labelText: 'Subject name',
              hintText: 'e.g. Operating Systems',
            ),
            const Gap(AppSpacing.sm),
            AppTextField(
              controller: _deptCtrl,
              labelText: 'Department',
              hintText: 'e.g. CSE',
            ),
            const Gap(AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _semesterCtrl,
                    labelText: 'Semester',
                    hintText: 'e.g. V',
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _sectionCtrl,
                    labelText: 'Section',
                    hintText: 'e.g. B',
                  ),
                ),
              ],
            ),

            const Gap(AppSpacing.lg),
            SectionHeader(
              title: 'Taught on',
              subtitle: 'Days this subject is scheduled',
            ),
            const Gap(AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: kWeekdays.map((day) {
                final selected = _taughtDays.contains(day);
                return FilterChip(
                  label: Text(day.substring(0, 3)),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _taughtDays.remove(day);
                    } else {
                      _taughtDays.add(day);
                    }
                  }),
                );
              }).toList(),
            ),

            const Gap(AppSpacing.lg),
            SectionHeader(
              title: 'Students',
              subtitle: 'Add students by their account email',
            ),
            const Gap(AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _emailCtrl,
                    hintText: 'student@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline,
                    onFieldSubmitted: (_) => _addStudentEmail(),
                  ),
                ),
                const Gap(AppSpacing.xs),
                FilledButton(
                  onPressed: _resolvingEmail ? null : _addStudentEmail,
                  child: _resolvingEmail
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
            if (_roster.isNotEmpty) ...[
              const Gap(AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: _roster
                    .map((r) => Chip(
                          label: Text(r.name),
                          onDeleted: () => setState(() => _roster.remove(r)),
                        ))
                    .toList(),
              ),
            ],

            const Gap(AppSpacing.lg),
            SectionHeader(
              title: 'Resources',
              subtitle: 'Optional syllabus and holiday list',
            ),
            const Gap(AppSpacing.sm),
            _FilePickRow(
              icon: Icons.menu_book_outlined,
              label: 'Syllabus',
              fileName: _syllabus?['fileName'],
              onPick: _pickSyllabus,
              onClear: () => setState(() => _syllabus = null),
            ),
            const Gap(AppSpacing.xs),
            _FilePickRow(
              icon: Icons.event_busy_outlined,
              label: 'Holiday list',
              fileName: _holiday?['fileName'],
              onPick: _pickHoliday,
              onClear: () => setState(() => _holiday = null),
            ),

            const Gap(AppSpacing.lg),
            SectionHeader(
              title: 'Tests',
              subtitle: 'Set assessment dates and portions',
              trailing: TextButton.icon(
                onPressed: _addTest,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ),
            const Gap(AppSpacing.sm),
            if (_tests.isEmpty)
              Text(
                'No tests added yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
              )
            else
              ..._tests.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        )),
                                Text(
                                  '${DateFormat('d MMM yyyy').format(t.date)} · ${t.portion}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _tests.remove(t)),
                          ),
                        ],
                      ),
                    ),
                  )),

            const Gap(AppSpacing.lg),
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 18, color: colors.textSecondary),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Course Guide',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                )),
                        Text(
                          'AI-built teaching plan from syllabus & tests',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _courseGuideEnabled,
                    onChanged: (v) => setState(() => _courseGuideEnabled = v),
                  ),
                ],
              ),
            ),

            const Gap(AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Creating…' : 'Create subject'),
              ),
            ),
            const Gap(AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _RosterEntry {
  final String email;
  final String name;
  _RosterEntry({required this.email, required this.name});
}

class _FilePickRow extends StatelessWidget {
  const _FilePickRow({
    required this.icon,
    required this.label,
    required this.fileName,
    required this.onPick,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final has = fileName != null;
    return AppCard(
      onTap: has ? null : onPick,
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const Gap(AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    )),
                Text(
                  has ? fileName! : 'Tap to upload (PDF or Word)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
          if (has)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onClear,
            )
          else
            Icon(Icons.upload_outlined, size: 16, color: colors.textTertiary),
        ],
      ),
    );
  }
}
