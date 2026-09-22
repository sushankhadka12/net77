import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net77/main.dart';

void main() {
  testWidgets('Shows mobile requirement and protection details', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.pumpWidget(const Net77App());
    expect(find.text('NET77'), findsOneWidget);
    expect(find.text('Run NET77 on an Android or iOS device.'), findsOneWidget);
    await tester.tap(find.byTooltip('Ad protection'));
    await tester.pumpAndSettle();
    expect(find.text('Ad protection is on'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
