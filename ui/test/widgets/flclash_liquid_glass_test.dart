import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/widgets/flclash/liquid_glass.dart';

Widget _scene({
  bool enabled = true,
  LiquidGlassQuality quality = LiquidGlassQuality.ultra,
  bool pressed = false,
  bool reducedMotion = false,
  bool twoPanes = false,
  Key? sceneKey,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: LiquidGlassScope(
      enabled: enabled,
      quality: quality,
      child: LiquidGlassHost(
        enabled: enabled,
        child: RepaintBoundary(
          key: sceneKey,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFFE9E2D0)),
              ),
              const Positioned(
                left: 30,
                top: 70,
                child: Text('Backdrop details under glass'),
              ),
              Positioned(
                left: 20,
                top: 50,
                child: RepaintBoundary(
                  child: LiquidGlassGroup(
                    child: Row(
                      children: [
                        for (var i = 0; i < (twoPanes ? 2 : 1); i++)
                          LiquidGlass(
                            style: LiquidGlassStyle.pill(
                              ColorScheme.fromSeed(seedColor: Colors.blue),
                            ),
                            pressed: pressed,
                            child: const SizedBox(width: 120, height: 48),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  tearDown(() {
    LiquidGlassHost.debugLastCapture = null;
    LiquidGlassHost.debugCarryBandsOverride = null;
  });

  testWidgets('bundled fragment program compiles and warmup is reusable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      final shader = program.fragmentShader();
      shader.dispose();
      await Future.wait([LiquidGlass.warmUp(), LiquidGlass.warmUp()]);
    });
    expect(
      LiquidGlass.debugShaderReady,
      ui.ImageFilter.isShaderFilterSupported,
      reason: 'Non-Impeller tests use the upstream frost fallback',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same-level panes share one capture atlas and reuse static bands',
    (tester) async {
      await tester.pumpWidget(_scene(twoPanes: true));
      await tester.pumpAndSettle();
      final first = LiquidGlassHost.debugLastCapture!;
      expect(first.panes, hasLength(2));
      expect(first.panes.map((pane) => pane.level).toSet(), {0});
      expect(first.panes[0].atlas, same(first.panes[1].atlas));
      expect(LiquidGlassHost.debugHeldCaptures, 2);
      final atlas = first.panes.first.atlas;
      // Press light changes only pane uniforms, not what lies beneath the pane.
      await tester.pumpWidget(_scene(twoPanes: true, pressed: true));
      await tester.pumpAndSettle();
      final glowing = LiquidGlassHost.debugLastCapture!;
      expect(glowing.panes.first.atlas, same(atlas));
      expect(glowing.snapshots, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(LiquidGlassHost.debugHeldCaptures, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quality switches preserve panes and disabling releases captures',
    (tester) async {
      await tester.pumpWidget(_scene());
      await tester.pumpAndSettle();
      final paneElement = tester.element(find.byType(LiquidGlass));
      expect(LiquidGlassHost.debugHeldCaptures, 1);
      await tester.pumpWidget(_scene(quality: LiquidGlassQuality.standard));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(LiquidGlass)), same(paneElement));
      expect(LiquidGlassHost.debugHeldCaptures, 1);
      await tester.pumpWidget(_scene(enabled: false));
      await tester.pumpAndSettle();
      expect(LiquidGlassHost.debugHeldCaptures, 0);
      await tester.pumpWidget(_scene());
      await tester.pumpAndSettle();
      expect(LiquidGlassHost.debugHeldCaptures, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(LiquidGlassHost.debugHeldCaptures, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion settles press glow without an animation clock', (
    tester,
  ) async {
    await tester.pumpWidget(_scene(reducedMotion: true));
    await tester.pumpWidget(_scene(reducedMotion: true, pressed: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(LiquidGlassHost.debugHeldCaptures, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(LiquidGlassHost.debugHeldCaptures, 0);
  });

  testWidgets(
    'source snapshots can omit panes without dropping live captures',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(_scene(sceneKey: key));
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = LiquidGlass.withoutPanes(() => boundary.toImageSync());
      await tester.runAsync(() async {
        expect(await image.toByteData(), isNotNull);
        image.dispose();
      });
      expect(LiquidGlassHost.debugHeldCaptures, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(LiquidGlassHost.debugHeldCaptures, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
