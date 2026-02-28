import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atom_admin/screens/onboarding_screen.dart';
import 'package:atom_admin/theme/app_theme.dart';

void main() {
  testWidgets('Onboarding screen smoke test', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const OnboardingScreen(),
      ),
    );

    expect(find.text('ATOM'), findsOneWidget);
    expect(find.text('CRAFT YOUR IDENTITY'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
