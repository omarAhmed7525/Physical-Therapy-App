import 'package:flutter/material.dart';

/// Central color palette for the physiotherapy app.
/// All colors are referenced from here — never hard-coded in widgets.
abstract class AppColors {
  // ── Light Mode ─────────────────────────────────────────────────────────────
  static const Color lightBackground  = Color(0xFFF8FAFC);
  static const Color lightCard        = Color(0xFFFFFFFF);
  static const Color lightPrimary     = Color(0xFF2563EB);
  static const Color lightSecondary   = Color(0xFF14B8A6);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightSuccess     = Color(0xFF16A34A);
  static const Color lightWarning     = Color(0xFFF59E0B);
  static const Color lightError       = Color(0xFFDC2626);

  // ── Dark Mode ──────────────────────────────────────────────────────────────
  static const Color darkBackground   = Color(0xFF0F172A);
  static const Color darkCard         = Color(0xFF1E293B);
  static const Color darkPrimary      = Color(0xFF60A5FA);
  static const Color darkSecondary    = Color(0xFF2DD4BF);
  static const Color darkTextPrimary  = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkSuccess      = Color(0xFF4ADE80);
  static const Color darkWarning      = Color(0xFFFBBF24);
  static const Color darkError        = Color(0xFFF87171);
}
