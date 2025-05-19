import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Custom scroll behavior that enables mouse wheel scrolling on desktop platforms
class DesktopScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}
