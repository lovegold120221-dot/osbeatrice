import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared visual tokens mirrored from the Beatrice Voice Next.js interface.
abstract final class BeatriceTheme {
  static const black = Color(0xFF000000);
  static const panel = Color(0xFF1A1A1A);
  static const raisedPanel = Color(0xFF212121);
  static const userBubble = Color(0xFF2F2F2F);
  static const border = Color(0xFF2A2A2A);
  static const text = Color(0xFFF5F5F5);
  static const mutedText = Color(0xFFA3A3A3);
  static const blue = Color(0xFF60A5FA);
  static const emerald = Color(0xFF34D399);
  static const purple = Color(0xFFC084FC);
  static const danger = Color(0xFFF87171);

  static TextTheme textTheme(TextTheme base) => GoogleFonts.interTextTheme(
    base,
  ).apply(bodyColor: text, displayColor: text);
}
