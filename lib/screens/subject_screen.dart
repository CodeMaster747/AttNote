// screens/subject_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subject_model.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';
import '../services/firestore_service.dart';
import 'subject_detail_screen.dart';
import 'student_subject_search_screen.dart'; // Added import
import 'create_personal_subject_screen.dart';

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Subject> _subjects = [];
  List<Subject> _filteredSubjects = [];
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoading = true;
  String _selectedFilter = 'All subjects';

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  // FIX: Added proper mounted checks to prevent setState after dispose
  Future<void> _loadSubjects() async {
    try {
      final subjects = await _firestoreService.getSubjects(uid);
      if (!mounted) return; // Prevent setState after dispose
      setState(() {
        _subjects = subjects;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading subjects: $e')));
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    final today = _getDayName(now.weekday);

    switch (_selectedFilter) {
      case 'Today':
        _filteredSubjects = _subjects.where((subject) {
          return subject.timetable.containsKey(today) &&
              subject.timetable[today]! > 0;
        }).toList();
        break;
      case 'Staff':
        _filteredSubjects = _subjects.where((subject) {
          return subject.staffName.isNotEmpty;
        }).toList();
        break;
      case 'Personal':
        _filteredSubjects = _subjects.where((subject) {
          return subject.staffName.isEmpty;
        }).toList();
        break;
      case 'All subjects':
      default:
        _filteredSubjects = List.from(_subjects);
        break;
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  void _addSubject() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePersonalSubjectScreen()),
    );
    // Reload subjects after returning from create screen
    _loadSubjects();
  }

  // NEW: Delete subject functionality
  Future<void> _deleteSubject(Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text(
          'Are you sure you want to delete "${subject.name}"? This will also delete all attendance records for this subject.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteSubject(uid, subject.id);
        await _loadSubjects(); // Refresh the list
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${subject.name} deleted successfully')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting subject: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filters = ['All subjects', 'Today', 'Staff', 'Personal'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Subjects"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search Global Subjects',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StudentSubjectSearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSubject,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Subject'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSubjects,
        child: Column(
          children: [
            // Filter Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxs,
              ),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, __) => const Gap(AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final filter = filters[index];
                    final isSelected = _selectedFilter == filter;
                    return FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                          _applyFilter();
                        });
                      },
                      showCheckmark: false,
                    );
                  },
                ),
              ),
            ),

            const Gap(AppSpacing.xxs),

            // Count indicator
            if (!_isLoading && _subjects.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_filteredSubjects.length} of ${_subjects.length} subjects',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            const Gap(AppSpacing.xxs),

            // Subjects List
            Expanded(
              child: _isLoading
                  ? const ShimmerCardList(itemCount: 6)
                  : _filteredSubjects.isEmpty
                  ? EmptyState(
                      title: _subjects.isEmpty
                          ? 'No subjects added yet'
                          : 'No subjects match this filter',
                      message: _subjects.isEmpty
                          ? 'Tap + to add a subject'
                          : 'Try a different filter',
                      icon: Icons.school_outlined,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xxs,
                        AppSpacing.md,
                        80,
                      ),
                      itemCount: _filteredSubjects.length,
                      itemBuilder: (context, index) {
                        final subject = _filteredSubjects[index];
                        final isStaffSubject = subject.staffName.isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Slidable(
                            key: ValueKey(subject.id),
                            endActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _deleteSubject(subject),
                                  icon: Icons.delete_outline,
                                  label: 'Delete',
                                  backgroundColor: colorScheme.errorContainer,
                                  foregroundColor: colorScheme.onErrorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ],
                            ),
                            child: AppCard(
                              padding: const EdgeInsets.all(14),
                              margin: EdgeInsets.zero,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SubjectDetailScreen(subject: subject),
                                  ),
                                );
                                _loadSubjects();
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: isStaffSubject
                                        ? colorScheme.primaryContainer
                                        : colorScheme.tertiaryContainer,
                                    child: Text(
                                      subject.name[0].toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isStaffSubject
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                  const Gap(AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const Gap(AppSpacing.xxs),
                                        Row(
                                          children: [
                                            Icon(
                                              isStaffSubject
                                                  ? Icons.person_outline
                                                  : Icons.book_outlined,
                                              size: 14,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            const Gap(AppSpacing.xxs),
                                            Text(
                                              isStaffSubject
                                                  ? subject.staffName
                                                  : 'Personal',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
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
