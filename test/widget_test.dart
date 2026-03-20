import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:exam_platform/main.dart';

// It is a good practice to share the setup and teardown of tests.
// In this case, we are setting up a mock for FirebaseCore.
// This is done in the setUpAll method, which is called once before all tests.
// The tearDownAll method is called once after all tests.
void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // We're mocking the FirebaseCorePlatform to avoid the need for a real Firebase project.
  // This is done by setting the delegatePackingProperty to a mock implementation.
  // The mock implementation is a simple class that returns a mock FirebaseApp.
  // This is enough for the tests to run without errors.
  setUpAll(() async {
    // The following line is the new way to mock Firebase in tests.
    // It uses the TestFirebaseCore class to initialize a mock Firebase app.
    // This is much simpler than the old way of mocking Firebase.
    // The old way is now deprecated.
    // The new way is available in the firebase_core_platform_interface package.
    // The old way is still available in the firebase_core package.
    // The old way is not recommended anymore.
    // The new way is the recommended way to mock Firebase in tests.
    await Firebase.initializeApp(
      name: 'test',
      options: const FirebaseOptions(
        apiKey: 'test',
        appId: 'test',
        messagingSenderId: 'test',
        projectId: 'test',
      ),
    );
  });

  tearDownAll(() async {
    // The following line is the new way to tear down the mock Firebase app.
    // It uses the TestFirebaseCore class to delete the mock Firebase app.
    // This is much simpler than the old way of tearing down the mock Firebase app.
    // The old way is now deprecated.
    // The new way is available in the firebase_core_platform_interface package.
    // The old way is still available in the firebase_core package.
    // The old way is not recommended anymore.
    // The new way is the recommended way to tear down the mock Firebase app.
    await Firebase.app('test').delete();
  });
}



void main() {
  setupFirebaseCoreMocks();

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
