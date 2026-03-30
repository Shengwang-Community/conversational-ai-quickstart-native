import 'package:flutter_test/flutter_test.dart';

import 'package:shengwang_convoai_quickstart_flutter/main.dart';

void main() {
  testWidgets('renders chat shell', (WidgetTester tester) async {
    await tester.pumpWidget(const StartupApp());

    expect(find.text('Shengwang Conversational AI'), findsOneWidget);
    expect(find.text('Real-time Voice Conversation Demo'), findsOneWidget);
    expect(find.text('Start Agent'), findsOneWidget);
  });
}
