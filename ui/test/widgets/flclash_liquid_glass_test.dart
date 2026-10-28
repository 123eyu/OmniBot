import 'dart:ui' as ui;
import 'dart:typed_data';

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

  testWidgets('frost rim follows square bottom corners of a sheet', (
    tester,
  ) async {
    final key = GlobalKey();
    Future<ByteData> pixels(double shine) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: LiquidGlass(
                style: const LiquidGlassStyle(
                  tint: Colors.black,
                  blur: 0,
                  rim: 0,
                  rimWidth: 0,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(40),
                ),
                rim: LiquidGlassRim(side: 0, corner: 0, flat: 0, shine: shine),
                child: const SizedBox(width: 160, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // No host: this exercises the pane's frost fallback, including on an
      // engine where the capture shader happens to be supported.
      final image = boundary.toImageSync();
      final data = await tester.runAsync(() => image.toByteData());
      image.dispose();
      return data!;
    }

    final withoutRim = await pixels(0);
    final withRim = await pixels(1);
    var topHighlightPixels = 0;
    for (var y = 5; y < 95; y++) {
      for (var x = 5; x < 155; x++) {
        final offset = (y * 160 + x) * 4;
        final change = withRim.getUint8(offset) - withoutRim.getUint8(offset);
        if (y < 40 && change > 0) topHighlightPixels++;
        if (y >= 60) {
          expect(change, 0, reason: 'No rounded bottom arc at ($x, $y)');
        }
      }
    }
    expect(topHighlightPixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
