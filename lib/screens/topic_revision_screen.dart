// screens/topic_revision_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../services/analytics_service.dart';

class TopicRevisionScreen extends StatefulWidget {
  const TopicRevisionScreen({super.key});

  @override
  State<TopicRevisionScreen> createState() => _TopicRevisionScreenState();
}

class _TopicRevisionScreenState extends State<TopicRevisionScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final String staffId = FirebaseAuth.instance.currentUser!.uid;

  List<ClassSubjectInfo> _classSubjects = [];
  String? _selectedClassId;
  String? _selectedSubjectName;
  List<TopicRevisionSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadClassSubjects();
  }

  Future<void> _loadClassSubjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(staffId)
          .collection('classes')
          .get();

      List<ClassSubjectInfo> classSubjects = [];
      for (var doc in classesSnapshot.docs) {
        final data = doc.data();
        classSubjects.add(
          ClassSubjectInfo(
            classId: doc.id,
            subjectName: data['subjectName'] ?? 'Unknown',
            className: data['className'] ?? 'Unknown',
            department: data['department'] ?? '',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _classSubjects = classSubjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading classes: $e')));
      }
    }
  }

  Future<void> _loadSuggestions() async {
    if (_selectedClassId == null || _selectedSubjectName == null) return;

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final suggestions = await _analyticsService.getTopicRevisionSuggestions(
        staffId,
        _selectedClassId!,
        _selectedSubjectName!,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading suggestions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Topic Revision Suggestions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class/Subject Selector
                  Text(
                    'Select Class',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Class & Subject',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.class_rounded),
                        ),
                        items: _classSubjects
                            .map(
                              (cs) => DropdownMenuItem<String>(
                                value: cs.classId,
                                child: Text(
                                  '${cs.subjectName} - ${cs.className}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedClassId = value;
                            _selectedSubjectName = _classSubjects
                                .firstWhere((cs) => cs.classId == value)
                                .subjectName;
                            _suggestions.clear();
                          });
                          _loadSuggestions();
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ML Suggestions
                  if (_selectedClassId != null) ...[
                    Row(
                      children: [
                        Text(
                          'Revision Suggestions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        if (_isLoadingSuggestions)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Based on attendance patterns, these topics had the most absences:',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Suggestions List
                  Expanded(
                    child: _isLoadingSuggestions
                        ? const Center(child: CircularProgressIndicator())
                        : _suggestions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedClassId == null
                                      ? Icons.touch_app_rounded
                                      : Icons.lightbulb_outline_rounded,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedClassId == null
                                      ? 'Select a class to view suggestions'
                                      : 'No suggestions available.\nEnsure attendance data exists.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _suggestions[index];
                              final rank = index + 1;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                color: colorScheme.surfaceContainerLow,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getRankColor(rank),
                                    child: Text(
                                      '$rank',
                                      style: TextStyle(
                                        color: _getRankForegroundColor(rank),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    suggestion.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        '${suggestion.absentCount} of ${suggestion.totalStudents} students absent',
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value:
                                            suggestion.absentPercentage / 100,
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                        color: colorScheme.error,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${suggestion.absentPercentage.toStringAsFixed(1)}% absent',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: colorScheme.error,
                                            ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
                                    tooltip: 'Mark as revised',
                                    onPressed: () {
                                      // Optional: Implement marking as revised
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Marked "${suggestion.displayName}" as revised',
                                          ),
                                        ),
                                      );
                                    },
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

  Color _getRankColor(int rank) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (rank) {
      case 1:
        return colorScheme.error;
      case 2:
        return colorScheme.secondary;
      case 3:
        return colorScheme.tertiary;
      default:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Color _getRankForegroundColor(int rank) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (rank) {
      case 1:
        return colorScheme.onError;
      case 2:
        return colorScheme.onSecondary;
      case 3:
        return colorScheme.onTertiary;
      default:
        return colorScheme.onSurface;
    }
  }
}

class ClassSubjectInfo {
  final String classId;
  final String subjectName;
  final String className;
  final String department;

  ClassSubjectInfo({
    required this.classId,
    required this.subjectName,
    required this.className,
    required this.department,
  });
}
