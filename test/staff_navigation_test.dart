import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_asg/screens/staff_shell.dart';
import 'package:mobile_asg/widgets/profile_actions.dart';

void main() {
  testWidgets('staff navigation switches between main and profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaffShell(
          mainPage: Scaffold(body: Text('Dashboard content')),
          profilePage: Scaffold(body: Text('Profile content')),
        ),
      ),
    );
    expect(find.text('Dashboard content'), findsOneWidget);
    expect(find.text('Profile content'), findsNothing);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile content'), findsOneWidget);
    expect(find.text('Dashboard content'), findsNothing);
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard content'), findsOneWidget);
  });

  testWidgets('centre QR action opens the configured scanner page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StaffShell(
          mainPage: Scaffold(body: Text('Dashboard content')),
          profilePage: Scaffold(body: Text('Profile content')),
          scannerPage: Scaffold(body: Text('Scanner content')),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('QR attendance scanner'));
    await tester.pumpAndSettle();

    expect(find.text('Scanner content'), findsOneWidget);
  });

  testWidgets('system admin profile omits inbox and confirms logout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [ProfileLogoutButton()]),
          body: const ProfileActions(isSystemAdmin: true),
        ),
      ),
    );
    expect(find.text('Feedback inbox'), findsNothing);
    expect(find.text('Send feedback'), findsNothing);
    expect(find.text('About Us'), findsOneWidget);
    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsNothing);
    expect(find.text('Feedback inbox'), findsNothing);
  });
}
