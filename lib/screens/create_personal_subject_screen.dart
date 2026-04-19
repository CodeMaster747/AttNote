// screens/create_personal_subject_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/subject_model.dart';

class CreatePersonalSubjectScreen extends StatefulWidget {
  const CreatePersonalSubjectScreen({super.key});

  @override
  State<CreatePersonalSubjectScreen> createState() =>
      _CreatePersonalSubjectScreenState();
}

class _CreatePersonalSubjectScreenState
    extends State<CreatePersonalSubjectScreen> {
  final _subjectNameCtrl = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = false;
  final Map<String, int> _timetable = {};

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void dispose() {
    _subjectNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSubject() async {
    final subjectName = _subjectNameCtrl.text.trim();

    if (subjectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject name')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final newSubject = Subject(
        id: subjectName.toLowerCase(),
        name: subjectName,
        isGlobal: false,
        timetable: _timetable,
      );

      await _firestoreService.addSubject(uid, newSubject);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject added successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding subject: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Personal Subject')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subject Details',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _subjectNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      prefixIcon: Icon(Icons.subject_outlined),
                      hintText: 'e.g. Mathematics',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Timetable (Optional)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set days and number of classes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ..._daysOfWeek.map((day) {
                    return Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                day,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: DropdownButton<int>(
                                value: _timetable[day] ?? 0,
                                isExpanded: true,
                                items: List.generate(6, (index) {
                                  return DropdownMenuItem(
                                    value: index,
                                    child: Text(
                                      index == 0
                                          ? 'None'
                                          : '$index class${index > 1 ? 'es' : ''}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  );
                                }),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == null || value == 0) {
                                      _timetable.remove(day);
                                    } else {
                                      _timetable[day] = value;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveSubject,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Subject'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
