import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

/// Resolves an avatar URL/string to an [ImageProvider].
/// Supports:
/// - Base64 Data URLs (starting with 'data:image')
/// - Network URLs (starting with 'http' or 'https')
/// - Local File system paths (absolute file paths)
ImageProvider? getAvatarProvider(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  
  final trimmedUrl = url.trim();
  
  if (trimmedUrl.startsWith('data:image')) {
    try {
      // Split the metadata from base64 content
      final commaIndex = trimmedUrl.indexOf(',');
      if (commaIndex != -1) {
        final base64Content = trimmedUrl.substring(commaIndex + 1);
        return MemoryImage(base64Decode(base64Content));
      }
    } catch (_) {
      return null;
    }
  }
  
  if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
    return NetworkImage(trimmedUrl);
  }
  
  try {
    final file = File(trimmedUrl);
    if (file.existsSync()) {
      return FileImage(file);
    }
  } catch (_) {}
  
  return null;
}
