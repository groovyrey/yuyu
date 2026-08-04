import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuyu/theme/app_theme.dart';

void main() {
  testWidgets('AppColors follows MaterialApp brightness via builder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          AppColors.setThemeBrightness(Theme.of(context).brightness);
          return child!;
        },
        home: const Scaffold(body: SizedBox()),
      ),
    );
    await tester.pump();
    expect(Theme.of(tester.element(find.byType(SizedBox))).brightness,
        Brightness.dark);
    expect(AppColors.surface, DarkColors.surface);
  });
}
