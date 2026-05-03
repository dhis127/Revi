import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesignTokens {
  // ===== Background =====
  static const Color bgIvory     = Color(0xFFFFF7EE);
  static const Color bgIvoryDeep = Color(0xFFF6ECDC);
  static const Color bgIvoryEdge = Color(0xFFEADCC4);
  static const Color bgIvoryRow  = Color(0xFFF1E5D2);

  // ===== Ink =====
  static const Color ink      = Color(0xFF1C1612);
  static const Color inkSoft  = Color(0xFF3A2E26);
  static const Color inkMute  = Color(0xFF6E5C4E);
  static const Color inkFaint = Color(0xFFA8957F);

  // ===== Rule lines =====
  static const Color rule       = Color(0x191C1612); // ~10% ink
  static const Color ruleStrong = Color(0x381C1612); // ~22% ink

  // ===== Accent =====
  static const Color sage      = Color(0xFF4A7B5E);
  static const Color sageSoft  = Color(0xFF8FB89E);
  static const Color terracotta = Color(0xFFB85C38);
  static const Color amber     = Color(0xFF8A6523);
  static const Color walnut    = Color(0xFF5C3A21);

  // ===== Shelf =====
  static const Color shelfWood     = Color(0xFF7B5836);
  static const Color shelfWoodDark = Color(0xFF4A3320);

  // ===== Legacy aliases (used in existing code) =====
  static const Color ctaDark        = ink;
  static const Color highlightSlot1 = sageSoft;
  static const Color highlightSlot2 = terracotta;
  static const Color highlightSlot3 = amber;

  // ===== Slot helper =====
  static Color slotColor(String slot) {
    switch (slot) {
      case 'terra': return terracotta;
      case 'amber': return amber;
      default:      return sageSoft;
    }
  }

  // ===== Cover gradients =====
  static LinearGradient coverGrad(String color) {
    switch (color) {
      case 'terra': return const LinearGradient(colors: [Color(0xFFD88B68), Color(0xFFA85A38)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'amber': return const LinearGradient(colors: [Color(0xFFC9A55C), Color(0xFF8A6523)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'ink':   return const LinearGradient(colors: [Color(0xFF4A3E36), Color(0xFF1C1612)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default:      return const LinearGradient(colors: [Color(0xFFB5D2BE), Color(0xFF7CA88E)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  // ===== Spine gradients =====
  static LinearGradient spineGrad(String color) {
    switch (color) {
      case 'terra': return const LinearGradient(colors: [Color(0xFFC26A45), Color(0xFF9C4A2C), Color(0xFFC26A45)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'amber': return const LinearGradient(colors: [Color(0xFF9C7530), Color(0xFF6E4F18), Color(0xFF9C7530)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      case 'ink':   return const LinearGradient(colors: [Color(0xFF3A2E26), Color(0xFF1C1612), Color(0xFF3A2E26)], begin: Alignment.centerLeft, end: Alignment.centerRight);
      default:      return const LinearGradient(colors: [Color(0xFF5E8E73), Color(0xFF3D6A4F), Color(0xFF5E8E73)], begin: Alignment.centerLeft, end: Alignment.centerRight);
    }
  }

  // ===== Fonts =====
  static TextStyle solway(double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
      GoogleFonts.solway(fontSize: size, fontWeight: weight, color: color ?? ink);

  static TextStyle solwayBold700(double size, [Color? color]) =>
      GoogleFonts.solway(fontSize: size, fontWeight: FontWeight.w700, color: color ?? ink);

  static TextStyle ptSans(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.ptSans(fontSize: size, fontWeight: weight, color: color ?? ink);

  static TextStyle ptSansRegular(double size, [Color? color]) =>
      GoogleFonts.ptSans(fontSize: size, fontWeight: FontWeight.w400, color: color ?? ink);

  static TextStyle ptSansBold(double size, [Color? color]) =>
      GoogleFonts.ptSans(fontSize: size, fontWeight: FontWeight.w700, color: color ?? ink);

  static TextStyle lora(double size, {bool italic = true, Color? color}) =>
      GoogleFonts.lora(fontSize: size, fontStyle: italic ? FontStyle.italic : FontStyle.normal, color: color ?? ink);

  static TextStyle hahmlet(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.hahmlet(fontSize: size, fontWeight: weight, color: color ?? ink);

  static TextStyle hahmletRegular(double size, [Color? color]) =>
      GoogleFonts.hahmlet(fontSize: size, fontWeight: FontWeight.w400, color: color ?? ink);

  static TextStyle hahmletBold(double size, [Color? color]) =>
      GoogleFonts.hahmlet(fontSize: size, fontWeight: FontWeight.w700, color: color ?? ink);

  // ===== Spacing =====
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
}
