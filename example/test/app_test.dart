import 'package:animated_route_marker_example/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens without a Maps key and plays the courier', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const AnimatedRouteMarkerExampleApp(hasMapsKey: false));
    await tester.pump();
    expect(find.text('No Google Maps key'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Moving'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.text('Live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Start GPS'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Accepted · '), findsOneWidget);
    await tester.tap(find.text('Stop GPS'));

    // Disposing the app must leave no ticker or timer behind.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
