import 'package:control_leaves_web/features/map/models/lat_lng.dart';
import 'package:control_leaves_web/features/map/presentation/location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPicker(WidgetTester tester, {double? radius}) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: radius == null
                ? LocationPicker(
                    initial: const LatLng(-17.3935, -66.157),
                    onChanged: (_) {},
                  )
                : LocationPicker(
                    initial: const LatLng(-17.3935, -66.157),
                    onChanged: (_) {},
                    radiusMeters: radius,
                  ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('el texto y el círculo indican el radio que define el servidor', (
    tester,
  ) async {
    await pumpPicker(tester, radius: 80);

    expect(find.textContaining('escaneos a 80 m o menos'), findsOneWidget);
    final circle = tester.widget<CircleLayer>(find.byType(CircleLayer));
    expect(circle.circles.single.radius, 80);
    expect(circle.circles.single.useRadiusInMeter, isTrue);
  });

  testWidgets('sin radio del servidor se usa el valor por defecto (50 m)', (
    tester,
  ) async {
    await pumpPicker(tester);

    expect(find.textContaining('escaneos a 50 m o menos'), findsOneWidget);
  });
}
