import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import '../models/subject_model.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';
import '../services/firestore_service.dart';

class StudentSubjectSearchScreen extends StatefulWidget {
  const StudentSubjectSearchScreen({super.key});

  @override
  State<StudentSubjectSearchScreen> createState() =>
      _StudentSubjectSearchScreenState();
}

class _StudentSubjectSearchScreenState
    extends State<StudentSubjectSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  List<Subject> _searchResults = [];
  bool _loading = false;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['name'] ?? 'Unknown Student';
        });
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
  }

  Future<void> _searchSubjects(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await _firestoreService.searchGlobalSubjects(
        query.trim(),
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
    }
  }

  Future<void> _requestToJoin(Subject subject) async {
    if (_userName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, loading user profile...')),
      );
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Check if already requested (Simple client side check or relying on backend?
      // Ideally we check if a pending request exists, but for now we just send.
      // FirestoreService will create a new request.
      // We could query first to avoid duplicates.)

      // Check for existing request
      final existingParams = await FirebaseFirestore.instance
          .collection('joinRequests')
          .where('studentId', isEqualTo: uid)
          .where('subjectId', isEqualTo: subject.id)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingParams.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already requested to join this subject'),
          ),
        );
        return;
      }

      // Check if already joined (locally)
      // We assume subject ID or name match.
      // If student has subject with same name...
      final localSubjectDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .doc(subject.name.trim().toLowerCase()) // Using normalized name as ID
          .get();

      if (localSubjectDoc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already joined this subject')),
        );
        return;
      }

      await _firestoreService.requestToJoinSubjectWithOwner(
        uid,
        _userName!,
        subject,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to join ${subject.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending request: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Search Subjects')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: AppTextField(
              controller: _searchController,
              hintText: 'Search by subject name...',
              prefixIcon: Icons.search,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchSubjects('');
                      },
                    )
                  : null,
              onChanged: _searchSubjects,
            ),
          ),
          Expanded(
            child: _loading
                ? const ShimmerCardList(itemCount: 6)
                : _searchResults.isEmpty
                ? EmptyState(
                    title: _searchController.text.isEmpty
                        ? 'Search for staff-created subjects'
                        : 'No subjects found',
                    message: _searchController.text.isEmpty
                        ? 'Type a subject name to search'
                        : 'Try a different search keyword',
                    icon: _searchController.text.isEmpty
                        ? Icons.search
                        : Icons.search_off,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xxs,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final subject = _searchResults[index];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  subject.name.isNotEmpty
                                      ? subject.name[0].toUpperCase()
                                      : '?',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const Gap(AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        if (subject.department.isNotEmpty) ...[
                                          Icon(
                                            Icons.business_outlined,
                                            size: 13,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          const Gap(AppSpacing.xxs),
                                          Text(
                                            subject.department,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const Gap(AppSpacing.sm),
                                        ],
                                        if (subject.section.isNotEmpty) ...[
                                          Icon(
                                            Icons.class_outlined,
                                            size: 13,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                          const Gap(AppSpacing.xxs),
                                          Text(
                                            subject.section,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(AppSpacing.xs),
                              AppPrimaryButton(
                                onPressed: () => _requestToJoin(subject),
                                label: 'Join',
                              ),
                            ],
                          ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
