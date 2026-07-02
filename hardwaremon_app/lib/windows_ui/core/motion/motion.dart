import 'package:flutter/material.dart';

class Motion {
  static const instant = Duration(milliseconds: 110);
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);
  static const cinematic = Duration(milliseconds: 760);

  static const emphasized = Curves.easeOutCubic;
  static const smooth = Curves.easeInOutCubic;
  static const enter = Curves.easeOutQuart;
  static const exit = Curves.easeInCubic;

  static Duration accessible(BuildContext context, Duration duration) {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return disabled ? Duration.zero : duration;
  }
}
