import 'package:flutter/material.dart';

class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);

  static const emphasized = Curves.easeOutCubic;
  static const smooth = Curves.easeInOutCubic;
}
