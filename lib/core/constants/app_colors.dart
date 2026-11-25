import 'package:flutter/material.dart';

/// Central color palette ("fisio") for the physiotherapy app.
/// All colors are referenced from here — never hard-coded in widgets.
abstract class AppColors {
  // ── Light Mode ─────────────────────────────────────────────────────────────
  static const Color lightBackground    = Color(0xFFF3F9FB);
  static const Color lightCard          = Color(0xFFFFFFFF);
  static const Color lightPrimary       = Color(0xFF0A7A94);
  static const Color lightOnPrimary     = Color(0xFFFFFFFF);
  static const Color lightSecondary     = Color(0xFF6DB6CB);
  static const Color lightTextPrimary   = Color(0xFF0B2733);
  static const Color lightTextSecondary = Color(0xFF4F6D7A);
  static const Color lightSurfaceAlt    = Color(0xFFE3F0F5);
  static const Color lightBorder        = Color(0xFFCFE2EA);
  static const Color lightSuccess       = Color(0xFF1E9E6F);
  static const Color lightWarning       = Color(0xFFB7791F);
  static const Color lightError         = Color(0xFFD14343);

  // ── Dark Mode ──────────────────────────────────────────────────────────────
  static const Color darkBackground     = Color(0xFF0B2733);
  static const Color darkCard           = Color(0xFF10303F);
  static const Color darkPrimary        = Color(0xFF6DB6CB);
  static const Color darkOnPrimary      = Color(0xFF08202B);
  static const Color darkSecondary      = Color(0xFF3FA3BD);
  static const Color darkTextPrimary    = Color(0xFFE6F3F7);
  static const Color darkTextSecondary  = Color(0xFF9DBCC8);
  static const Color darkSurfaceElevated = Color(0xFF173D4E);
  static const Color darkBorder         = Color(0xFF24495A);
  static const Color darkSuccess        = Color(0xFF5FD1A5);
  static const Color darkWarning        = Color(0xFFF2C15B);
  static const Color darkError          = Color(0xFFF0807F);
}
