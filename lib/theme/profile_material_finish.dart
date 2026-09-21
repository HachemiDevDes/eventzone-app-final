import 'package:flutter/material.dart';

enum ProfileMaterialFinishType {
  titaniumCobalt,
  obsidianMatte,
  emeraldCyber,
  cyberViolet,
}

class ProfileMaterialFinish {
  final String id;
  final String name;
  final ProfileMaterialFinishType type;
  final Color dotColor;
  final Color primaryColor;
  final Color accentColor;
  final Color glowColor;
  final Color cardBorderColor;
  final Color cardSurfaceColor;
  final List<Color> gradientColors;
  final Color buttonColor;
  final Color buttonTextColor;

  const ProfileMaterialFinish({
    required this.id,
    required this.name,
    required this.type,
    required this.dotColor,
    required this.primaryColor,
    required this.accentColor,
    required this.glowColor,
    required this.cardBorderColor,
    required this.cardSurfaceColor,
    required this.gradientColors,
    required this.buttonColor,
    this.buttonTextColor = Colors.white,
  });

  // 1. Titanium Cobalt
  static const ProfileMaterialFinish titaniumCobalt = ProfileMaterialFinish(
    id: 'titanium_cobalt',
    name: 'Titanium Cobalt',
    type: ProfileMaterialFinishType.titaniumCobalt,
    dotColor: Color(0xFF2563EB), // Vibrant Cobalt Blue
    primaryColor: Color(0xFF3B82F6),
    accentColor: Color(0xFF60A5FA),
    glowColor: Color(0x662563EB),
    cardBorderColor: Color(0x403B82F6),
    cardSurfaceColor: Color(0xFF0F1E38),
    gradientColors: [
      Color(0xFF1D4ED8),
      Color(0xFF1E3A8A),
      Color(0xFF0B1120),
    ],
    buttonColor: Color(0xFF2563EB),
  );

  // 2. Obsidian Matte
  static const ProfileMaterialFinish obsidianMatte = ProfileMaterialFinish(
    id: 'obsidian_matte',
    name: 'Obsidian Matte',
    type: ProfileMaterialFinishType.obsidianMatte,
    dotColor: Color(0xFF1E293B), // Obsidian Slate / Deep Dark
    primaryColor: Color(0xFF94A3B8), // Sleek Silver / Slate accent
    accentColor: Color(0xFFE2E8F0),
    glowColor: Color(0x4094A3B8),
    cardBorderColor: Color(0x33CBD5E1),
    cardSurfaceColor: Color(0xFF141824),
    gradientColors: [
      Color(0xFF334155),
      Color(0xFF1E293B),
      Color(0xFF0A0D14),
    ],
    buttonColor: Color(0xFF334155),
  );

  // 3. Emerald Cyber
  static const ProfileMaterialFinish emeraldCyber = ProfileMaterialFinish(
    id: 'emerald_cyber',
    name: 'Emerald Cyber',
    type: ProfileMaterialFinishType.emeraldCyber,
    dotColor: Color(0xFF10B981), // Cyber Emerald Green
    primaryColor: Color(0xFF10B981),
    accentColor: Color(0xFF34D399),
    glowColor: Color(0x6610B981),
    cardBorderColor: Color(0x4010B981),
    cardSurfaceColor: Color(0xFF0C241C),
    gradientColors: [
      Color(0xFF059669),
      Color(0xFF064E3B),
      Color(0xFF051611),
    ],
    buttonColor: Color(0xFF059669),
  );

  // 4. Cyber Violet (Default / Brand)
  static const ProfileMaterialFinish cyberViolet = ProfileMaterialFinish(
    id: 'cyber_violet',
    name: 'Cyber Violet',
    type: ProfileMaterialFinishType.cyberViolet,
    dotColor: Color(0xFF8B5CF6), // Electric Cyber Violet
    primaryColor: Color(0xFF8B5CF6),
    accentColor: Color(0xFFA78BFA),
    glowColor: Color(0x668B5CF6),
    cardBorderColor: Color(0x408B5CF6),
    cardSurfaceColor: Color(0xFF1A1230),
    gradientColors: [
      Color(0xFF7C3AED),
      Color(0xFF4C1D95),
      Color(0xFF0F0B1E),
    ],
    buttonColor: Color(0xFF7C3AED),
  );

  static List<ProfileMaterialFinish> get all => [
    titaniumCobalt,
    obsidianMatte,
    emeraldCyber,
    cyberViolet,
  ];

  static ProfileMaterialFinish fromId(String? id) {
    if (id == null || id.isEmpty) return cyberViolet;
    for (final finish in all) {
      if (finish.id == id || finish.name.toLowerCase() == id.toLowerCase()) {
        return finish;
      }
    }
    return cyberViolet;
  }

  static ProfileMaterialFinish fromProfile(Map<String, dynamic>? profileData) {
    if (profileData == null) return cyberViolet;
    final metadata = profileData['metadata'];
    if (metadata is Map<String, dynamic> || metadata is Map) {
      final finishId = metadata['material_finish'] ?? metadata['profile_finish'] ?? metadata['ui_color'];
      if (finishId != null) return fromId(finishId.toString());
    }
    final directFinish = profileData['material_finish'] ?? profileData['profile_theme'];
    if (directFinish != null) return fromId(directFinish.toString());
    return cyberViolet;
  }
}
