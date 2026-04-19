import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attnote/widgets/feature_card.dart';

void main() {
  testWidgets('FeatureCard renders title and description', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FeatureCard(
            title: 'Profile',
            description: 'Manage your profile',
            icon: Icons.person,
          ),
        ),
      ),
    );

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Manage your profile'), findsOneWidget);
  });
}
