import 'dart:convert';
import 'package:flutter/material.dart';

class BlueprintModel {
  final String url;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final double opacity;
  final double rotation;
  final double canvasWidth;
  final double canvasHeight;
  final bool isLocked;

  BlueprintModel({
    required this.url,
    this.name = 'Venue Blueprint',
    this.x = 0,
    this.y = 0,
    this.width = 800,
    this.height = 600,
    this.opacity = 0.8,
    this.rotation = 0,
    this.canvasWidth = 2400,
    this.canvasHeight = 1500,
    this.isLocked = false,
  });

  factory BlueprintModel.fromJson(Map<String, dynamic> json) {
    return BlueprintModel(
      url: (json['url'] ?? json['background_url'] ?? '').toString(),
      name: (json['name'] ?? 'Venue Blueprint').toString(),
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 800.0,
      height: (json['height'] as num?)?.toDouble() ?? 600.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.8,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      canvasWidth: (json['canvasWidth'] as num?)?.toDouble() ?? 2400.0,
      canvasHeight: (json['canvasHeight'] as num?)?.toDouble() ?? 1500.0,
      isLocked: json['isLocked'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'opacity': opacity,
        'rotation': rotation,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'isLocked': isLocked,
      };
}

class FloorElementModel {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final String label;
  final String status; // 'available', 'sold', 'confirmed', 'reserved', 'pending-payment', 'hold', 'negotiation'
  final String? color;
  final String? fillColor;
  final String? strokeColor;
  final String? textColor;
  final double? fontSize;
  final String? surfaceArea;
  final String? exhibitorId;
  final bool isLocked;

  FloorElementModel({
    required this.id,
    this.type = 'booth',
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    required this.label,
    this.status = 'available',
    this.color,
    this.fillColor,
    this.strokeColor,
    this.textColor,
    this.fontSize,
    this.surfaceArea,
    this.exhibitorId,
    this.isLocked = false,
  });

  factory FloorElementModel.fromJson(Map<String, dynamic> json) {
    String typeStr = (json['type'] ?? 'booth').toString();
    String rawLabel = (json['label'] ?? json['boothNumber'] ?? json['booth_number'] ?? json['name'] ?? '').toString();
    if (rawLabel.isEmpty) {
      if (typeStr.startsWith('booth')) {
        rawLabel = (json['id'] ?? 'Booth').toString();
      } else if (typeStr.contains('stage')) {
        rawLabel = 'Stage';
      } else if (typeStr.contains('screen')) {
        rawLabel = 'Screen';
      } else if (typeStr == 'entrance') {
        rawLabel = 'Entrance';
      } else if (typeStr == 'exit') {
        rawLabel = 'Exit';
      }
    }

    return FloorElementModel(
      id: (json['id'] ?? '').toString(),
      type: typeStr,
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 100.0,
      height: (json['height'] as num?)?.toDouble() ?? 100.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      label: rawLabel,
      status: (json['status'] ?? 'available').toString().toLowerCase().trim(),
      color: json['color'] as String?,
      fillColor: (json['fillColor'] ?? json['fill_color'] ?? json['color']) as String?,
      strokeColor: (json['strokeColor'] ?? json['stroke_color']) as String?,
      textColor: (json['textColor'] ?? json['text_color']) as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? (json['font_size'] as num?)?.toDouble(),
      surfaceArea: (json['surfaceArea'] ?? json['surface_area'])?.toString(),
      exhibitorId: json['exhibitorId'] as String? ?? json['exhibitor_id'] as String?,
      isLocked: json['isLocked'] == true,
    );
  }

  static Color? parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    String cleanHex = hexString.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    } else if (cleanHex.length != 8) {
      return null;
    }
    final val = int.tryParse(cleanHex, radix: 16);
    return val != null ? Color(val) : null;
  }

  bool get isBooth => type.startsWith('booth');
  bool get isStage => type.toLowerCase().contains('stage');
  bool get isScreen => type.toLowerCase().contains('screen');
  bool get isEntrance => type.toLowerCase() == 'entrance';
  bool get isExit => type.toLowerCase() == 'exit';
  bool get isChair => type.toLowerCase().contains('chair');
  bool get isTable => type.toLowerCase().contains('table');
  bool get isUtility => type.startsWith('utility') || type.startsWith('access') || type.startsWith('net');
  bool get isArrow => type.toLowerCase() == 'arrow';

  bool get isSold => status == 'sold' || status == 'confirmed';
  bool get isReserved => status == 'reserved' || status == 'pending-payment';
  bool get isHold => status == 'hold' || status == 'negotiation';
  bool get isAvailable => status == 'available' || (!isSold && !isReserved && !isHold);

  /// High contrast background fill color matching web platform on pure white canvas
  Color get statusFillColor {
    final customFill = parseHexColor(fillColor ?? color);
    if (customFill != null) return customFill;

    if (isStage) return const Color(0xFFFAF5FF); // light purple
    if (isScreen) return const Color(0xFF0F172A); // dark slate screen
    if (isEntrance) return const Color(0xFFECFDF5); // light emerald
    if (isExit) return const Color(0xFFFFF1F2); // light rose
    if (isChair) return const Color(0xFFF1F5F9); // subtle slate
    if (isTable) return const Color(0xFFF8FAFC);
    if (isUtility) return const Color(0xFFF0FDF4);

    if (isSold) return const Color(0xFFFEF2F2); // soft red
    if (isReserved) return const Color(0xFFFFEDD5); // warm amber
    if (isHold) return const Color(0xFFECFEFF); // soft cyan
    return const Color(0xFFF0FDF4); // clean emerald for available
  }

  /// High contrast border stroke matching web platform
  Color get statusStrokeColor {
    final customStroke = parseHexColor(strokeColor);
    if (customStroke != null) return customStroke;

    if (isStage) return const Color(0xFFA855F7);
    if (isScreen) return const Color(0xFF38BDF8);
    if (isEntrance) return const Color(0xFF059669);
    if (isExit) return const Color(0xFFE11D48);
    if (isChair) return const Color(0xFFCBD5E1);
    if (isTable) return const Color(0xFF94A3B8);
    if (isUtility) return const Color(0xFF16A34A);

    if (isSold) return const Color(0xFFEF4444);
    if (isReserved) return const Color(0xFFF97316);
    if (isHold) return const Color(0xFF0891B2);
    return const Color(0xFF16A34A);
  }

  /// High contrast text color for maximum legibility on white canvas
  Color get statusTextColor {
    final customText = parseHexColor(textColor);
    if (customText != null) return customText;

    if (isStage) return const Color(0xFF6B21A8);
    if (isScreen) return const Color(0xFF38BDF8);
    if (isEntrance) return const Color(0xFF047857);
    if (isExit) return const Color(0xFFBE123C);
    if (isChair) return const Color(0xFF64748B);
    if (isTable) return const Color(0xFF475569);

    if (isSold) return const Color(0xFFB91C1C);
    if (isReserved) return const Color(0xFFC2410C);
    if (isHold) return const Color(0xFF0E7490);
    return const Color(0xFF0F172A); // slate-900 crisp dark text for booths
  }

  String get statusDisplay {
    if (isSold) return 'Sold';
    if (isReserved) return 'Reserved';
    if (isHold) return 'Hold';
    if (isStage) return 'Stage';
    if (isEntrance) return 'Entrance';
    if (isExit) return 'Exit';
    return 'Available';
  }
}

class SubFloorModel {
  final String id;
  final String name;
  final List<FloorElementModel> elements;
  final BlueprintModel? blueprint;

  SubFloorModel({
    required this.id,
    required this.name,
    required this.elements,
    this.blueprint,
  });

  factory SubFloorModel.fromJson(Map<String, dynamic> json) {
    BlueprintModel? bp;
    dynamic rawBp = json['blueprint'];
    if (rawBp is String) {
      try {
        rawBp = jsonDecode(rawBp);
      } catch (_) {}
    }
    if (rawBp is Map) {
      bp = BlueprintModel.fromJson(Map<String, dynamic>.from(rawBp));
    }

    List<FloorElementModel> elems = [];
    dynamic rawElements = json['elements'];
    if (rawElements is String) {
      try {
        rawElements = jsonDecode(rawElements);
      } catch (_) {}
    }
    if (rawElements is List) {
      for (final item in rawElements) {
        if (item is Map) {
          elems.add(FloorElementModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return SubFloorModel(
      id: (json['id'] ?? 'default-floor').toString(),
      name: (json['name'] ?? 'Ground Floor').toString(),
      elements: elems,
      blueprint: bp,
    );
  }
}

class FloorPlanModel {
  final String id;
  final String? eventId;
  final String name;
  final double canvasWidth;
  final double canvasHeight;
  final BlueprintModel? blueprint;
  final List<FloorElementModel> elements;
  final List<SubFloorModel> floors;
  final String status;
  final String fontFamily;

  FloorPlanModel({
    required this.id,
    this.eventId,
    required this.name,
    this.canvasWidth = 2400,
    this.canvasHeight = 1500,
    this.blueprint,
    required this.elements,
    required this.floors,
    this.status = 'published',
    this.fontFamily = 'Plus Jakarta Sans',
  });

  factory FloorPlanModel.fromJson(Map<String, dynamic> json) {
    BlueprintModel? bp;
    dynamic rawBp = json['blueprint'];
    if (rawBp is String) {
      try {
        rawBp = jsonDecode(rawBp);
      } catch (_) {}
    }
    if (rawBp is Map) {
      bp = BlueprintModel.fromJson(Map<String, dynamic>.from(rawBp));
    }

    List<FloorElementModel> elems = [];
    dynamic rawElements = json['elements'];
    if (rawElements is String) {
      try {
        rawElements = jsonDecode(rawElements);
      } catch (_) {}
    }
    if (rawElements is List) {
      for (final item in rawElements) {
        if (item is Map) {
          elems.add(FloorElementModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    List<SubFloorModel> subFloors = [];
    final rawFloors = json['floors'];
    if (rawFloors != null) {
      dynamic parsed = rawFloors;
      if (rawFloors is String) {
        try {
          parsed = jsonDecode(rawFloors);
        } catch (_) {}
      }
      if (parsed is List) {
        for (final item in parsed) {
          if (item is Map) {
            subFloors.add(SubFloorModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    }

    // Determine canvas dimensions
    double cW = (json['width'] as num?)?.toDouble() ?? (bp?.canvasWidth ?? 2400.0);
    double cH = (json['height'] as num?)?.toDouble() ?? (bp?.canvasHeight ?? 1500.0);

    return FloorPlanModel(
      id: (json['id'] ?? '').toString(),
      eventId: json['event_id'] as String?,
      name: (json['name'] ?? 'Floor Plan').toString(),
      canvasWidth: cW > 0 ? cW : 2400.0,
      canvasHeight: cH > 0 ? cH : 1500.0,
      blueprint: bp,
      elements: elems,
      floors: subFloors,
      status: (json['status'] ?? 'published').toString(),
      fontFamily: (json['font_family'] ?? 'Plus Jakarta Sans').toString(),
    );
  }
}
