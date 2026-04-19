// screens/staff_session_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class StaffSessionScheduleScreen extends StatefulWidget {
  final String classId;
  final String subjectName;

  const StaffSessionScheduleScreen({
    super.key,
    required this.classId,
    required this.subjectName,
  });

  @override
  State<StaffSessionScheduleScreen> createState() =>
      _StaffSessionScheduleScreenState();
}

class _StaffSessionScheduleScreenState
    extends State<StaffSessionScheduleScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String staffId = FirebaseAuth.instance.currentUser!.uid;

  DateTime _selectedDate = DateTime.now();
  int _numberOfSessions = 1;
  final Map<int, TextEditingController> _topicControllers = {};
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  @override
  void dispose() {
    for (final controller in _topicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final schedule = await _firestoreService.getSessionSchedule(
        staffId,
        widget.classId,
        _selectedDate,
      );

      if (schedule != null && mounted) {
        final numberOfSessions = schedule['numberOfSessions'] as int? ?? 1;
        final topicsData =
            schedule['sessionTopics'] as Map<dynamic, dynamic>? ?? {};

        setState(() {
          _numberOfSessions = numberOfSessions;
          _topicControllers.clear();

          for (int i = 1; i <= numberOfSessions; i++) {
            final topic = topicsData[i.toString()]?.toString() ?? '';
            _topicControllers[i] = TextEditingController(text: topic);
          }
        });
      } else {
        // No existing schedule, initialize controllers
        _initializeControllers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading schedule: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initializeControllers() {
    _topicControllers.clear();
    for (int i = 1; i <= _numberOfSessions; i++) {
      _topicControllers[i] = TextEditingController();
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadSchedule();
    }
  }

  Future<void> _saveSchedule() async {
    // Validate that all topics are filled
    for (int i = 1; i <= _numberOfSessions; i++) {
      if (_topicControllers[i]?.text.trim().isEmpty ?? true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter topic for Session $i')),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final sessionTopics = <int, String>{};
      _topicControllers.forEach((session, controller) {
        sessionTopics[session] = controller.text.trim();
      });

      await _firestoreService.saveSessionSchedule(
        staffId,
        widget.classId,
        widget.subjectName,
        _selectedDate,
        _numberOfSessions,
        sessionTopics,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving schedule: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateNumberOfSessions(int newValue) {
    setState(() {
      _numberOfSessions = newValue;

      // Add or remove controllers as needed
      if (newValue > _topicControllers.length) {
        for (int i = _topicControllers.length + 1; i <= newValue; i++) {
          _topicControllers[i] = TextEditingController();
        }
      } else if (newValue < _topicControllers.length) {
        final keysToRemove = _topicControllers.keys
            .where((key) => key > newValue)
            .toList();
        for (var key in keysToRemove) {
          _topicControllers[key]?.dispose();
          _topicControllers.remove(key);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Schedule — ${widget.subjectName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Selector
                  Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: ListTile(
                      leading: Icon(
                        Icons.calendar_today_rounded,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Select Date'),
                      subtitle: Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onTap: _selectDate,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Number of Sessions
                  Text(
                    'Sessions',
                    style: theme.textTheme.titleMedium?.copyWith(
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
                      child: DropdownButtonFormField<int>(
                        initialValue: _numberOfSessions,
                        decoration: const InputDecoration(
                          labelText: 'Number of Sessions',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                        items: List.generate(10, (index) => index + 1)
                            .map(
                              (sessionCount) => DropdownMenuItem<int>(
                                value: sessionCount,
                                child: Text(
                                  '$sessionCount session${sessionCount > 1 ? 's' : ''}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _updateNumberOfSessions(val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Topics for each session
                  Text(
                    'Session Topics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...List.generate(_numberOfSessions, (index) {
                    final sessionNum = index + 1;
                    return Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: colorScheme.primaryContainer,
                                  child: Text(
                                    '$sessionNum',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Session $sessionNum',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _topicControllers[sessionNum],
                              decoration: const InputDecoration(
                                labelText: 'Topic',
                                hintText: 'e.g., Introduction to Calculus',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.topic_rounded),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveSchedule,
                      icon: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Schedule'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
