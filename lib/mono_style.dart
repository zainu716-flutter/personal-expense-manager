import 'package:flutter/material.dart';

// ── Monospace TextStyle helper ─────────────────
TextStyle monoStyle({
  double fontSize = 14,
  Color color = Colors.white,
  FontWeight fontWeight = FontWeight.normal,
}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
  );
}