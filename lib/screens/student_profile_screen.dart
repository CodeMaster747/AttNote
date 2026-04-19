import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/widgets.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});
  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _rollNoCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();

  String _email = '';
  bool _loading = false;
  bool _initialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final data = doc.data() ?? {};

    _nameCtrl.text = data['name'] ?? '';
    _rollNoCtrl.text = data['rollNumber'] ?? '';
    String className = data['studentClass'] ?? '';
    if (className.length >= 2) {
      _semesterCtrl.text = className[0];
      _sectionCtrl.text = className[1];
    }
    _departmentCtrl.text = data['department'] ?? '';
    _email = user.email ?? '';

    setState(() {
      _initialLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final rollNo = _rollNoCtrl.text.trim();
    final semester = _semesterCtrl.text.trim();
    final section = _sectionCtrl.text.trim();
    final department = _departmentCtrl.text.trim();

    setState(() => _loading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': name,
        'rollNumber': rollNo,
        'studentClass': semester + section,
        'department': department,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollNoCtrl.dispose();
    _semesterCtrl.dispose();
    _sectionCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_initialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const ShimmerCardList(itemCount: 4),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _saveProfile,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar Section
              CircleAvatar(
                radius: 44,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  _nameCtrl.text.isNotEmpty
                      ? _nameCtrl.text[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Gap(AppSpacing.xs),
              Text(
                _email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const Gap(AppSpacing.lg),

              // Personal Information Section
              const SectionHeader(
                title: 'Personal Information',
                padding: EdgeInsets.zero,
              ),
              const Gap(AppSpacing.sm),

              AppTextField(
                controller: _nameCtrl,
                labelText: 'Full Name',
                prefixIcon: Icons.person_outline,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
                onChanged: (_) => setState(() {}), // update avatar
              ),
              const Gap(AppSpacing.sm),

              AppTextField(
                controller: _rollNoCtrl,
                labelText: 'Roll Number (optional)',
                prefixIcon: Icons.badge_outlined,
              ),

              const Gap(AppSpacing.lg),

              // Academic Details Section
              const SectionHeader(
                title: 'Academic Details',
                padding: EdgeInsets.zero,
              ),
              const Gap(AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _semesterCtrl,
                      labelText: 'Semester',
                      hintText: 'e.g. V',
                      prefixIcon: Icons.school_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      controller: _sectionCtrl,
                      labelText: 'Section',
                      hintText: 'e.g. B',
                      prefixIcon: Icons.group_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.sm),

              AppTextField(
                controller: _departmentCtrl,
                labelText: 'Department',
                prefixIcon: Icons.business_outlined,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Department is required'
                    : null,
              ),

              const Gap(AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  onPressed: _loading ? null : _saveProfile,
                  icon: Icons.save_outlined,
                  label: 'Save Profile',
                  isLoading: _loading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
