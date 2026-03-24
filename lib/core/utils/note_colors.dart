import 'package:flutter/material.dart';

class NoteColors {
  NoteColors._();

  // Each entry: [light background, dark background]
  static const _palette = [
    [Color(0xFFFFF9C4), Color(0xFF4A4500)], // yellow
    [Color(0xFFFFCDD2), Color(0xFF4E0000)], // red
    [Color(0xFFC8E6C9), Color(0xFF003300)], // green
    [Color(0xFFBBDEFB), Color(0xFF002244)], // blue
    [Color(0xFFE1BEE7), Color(0xFF2D0040)], // purple
    [Color(0xFFFFE0B2), Color(0xFF4A1800)], // orange
    [Color(0xFFB2EBF2), Color(0xFF002830)], // cyan
    [Color(0xFFF8BBD0), Color(0xFF3E0020)], // pink
  ];

  static Color bg(int index, Brightness brightness) {
    final i = index.clamp(0, _palette.length - 1);
    return brightness == Brightness.dark ? _palette[i][1] : _palette[i][0];
  }

  static int get count => _palette.length;

  static const icons = [
    Icons.circle, Icons.circle, Icons.circle, Icons.circle,
    Icons.circle, Icons.circle, Icons.circle, Icons.circle,
  ];
}
