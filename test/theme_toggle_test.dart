import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuyu/theme/app_theme.dart';

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.child});
  final Widget child;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool dark = true;

  void toggle() => setState(() => dark = !dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        AppColors.setThemeBrightness(Theme.of(context).brightness);
        return child!;
      },
      home: widget.child,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) {
    return Container(key: const ValueKey('card'), color: context.appSurface);
  }
}

void main() {
  testWidgets('card color follows theme toggle at runtime', (tester) async {
    final harness = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: harness, child: const _Card()));
    final card = tester.widget<Container>(find.byKey(const ValueKey('card')));
    expect(card.color, DarkColors.surface);

    harness.currentState!.toggle();
    await tester.pumpAndSettle();
    final card2 = tester.widget<Container>(find.byKey(const ValueKey('card')));
    expect(card2.color, const Color(0xFFFFFFFF));
  });
}
