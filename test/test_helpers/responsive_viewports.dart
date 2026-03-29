import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

class ResponsiveTestViewport {
  const ResponsiveTestViewport({required this.name, required this.size});

  final String name;
  final Size size;
}

const List<ResponsiveTestViewport> kResponsiveLayoutViewports =
    <ResponsiveTestViewport>[
      ResponsiveTestViewport(name: 'phone-se', size: Size(320, 568)),
      ResponsiveTestViewport(name: 'phone-compact', size: Size(360, 740)),
      ResponsiveTestViewport(name: 'phone-standard', size: Size(390, 844)),
      ResponsiveTestViewport(name: 'phone-large', size: Size(430, 932)),
      ResponsiveTestViewport(name: 'tablet-portrait', size: Size(768, 1024)),
      ResponsiveTestViewport(name: 'tablet-landscape', size: Size(1024, 768)),
      ResponsiveTestViewport(name: 'tablet-large', size: Size(1366, 1024)),
      ResponsiveTestViewport(name: 'desktop-narrow', size: Size(1280, 800)),
      ResponsiveTestViewport(name: 'desktop-standard', size: Size(1440, 900)),
      ResponsiveTestViewport(name: 'desktop-ultrawide', size: Size(2880, 900)),
      ResponsiveTestViewport(name: 'desktop-tall', size: Size(900, 1800)),
      ResponsiveTestViewport(
        name: 'desktop-extra-tall',
        size: Size(1200, 2200),
      ),
    ];

const List<ResponsiveTestViewport> kResponsiveShellViewports =
    <ResponsiveTestViewport>[
      ResponsiveTestViewport(name: 'phone-large', size: Size(430, 932)),
      ResponsiveTestViewport(name: 'tablet-portrait', size: Size(768, 1024)),
      ResponsiveTestViewport(name: 'tablet-landscape', size: Size(1024, 768)),
      ResponsiveTestViewport(name: 'tablet-large', size: Size(1366, 1024)),
      ResponsiveTestViewport(name: 'desktop-standard', size: Size(1440, 900)),
      ResponsiveTestViewport(name: 'desktop-ultrawide', size: Size(2880, 900)),
      ResponsiveTestViewport(name: 'desktop-tall', size: Size(900, 1800)),
      ResponsiveTestViewport(
        name: 'desktop-extra-tall',
        size: Size(1200, 2200),
      ),
    ];

Future<void> applyResponsiveTestViewport(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pump();
}
