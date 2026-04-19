import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../student_profile_screen.dart';

/// Account profile: name, email, optional photo (e.g. Google), sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }
    final user = authUser;
    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final name = data['name'] as String? ?? user.displayName ?? '';
          final email = data['email'] as String? ?? user.email ?? '';
          final photoUrl = data['photoUrl'] as String? ?? user.photoURL;
          final role = data['role'] as String? ?? 'student';

          return ListView(
            padding: AppSpacing.pagePadding,
            children: [
              Center(
                child: _Avatar(
                  photoUrl: photoUrl,
                  name: name,
                  fallbackLetter: name.isNotEmpty ? name[0] : '?',
                ),
              ),
              const Gap(AppSpacing.md),
              Text(
                name,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(AppSpacing.xs),
              Text(
                email,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(AppSpacing.xl),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person_outline,
                          color: colorScheme.primary),
                      title: const Text('Full name'),
                      subtitle: Text(name),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.email_outlined,
                          color: colorScheme.primary),
                      title: const Text('Email'),
                      subtitle: Text(email),
                    ),
                  ],
                ),
              ),

              const Gap(AppSpacing.md),

              if (role != 'staff')
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const StudentProfileScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Edit academic profile'),
                ),

              const Gap(AppSpacing.lg),

              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoUrl,
    required this.name,
    required this.fallbackLetter,
  });

  final String? photoUrl;
  final String name;
  final String fallbackLetter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const radius = 48.0;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      backgroundImage: hasPhoto
          ? CachedNetworkImageProvider(photoUrl!)
          : null,
      onBackgroundImageError: hasPhoto ? (_, __) {} : null,
      child: hasPhoto
          ? null
          : Text(
              fallbackLetter.toUpperCase(),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
    );
  }
}
