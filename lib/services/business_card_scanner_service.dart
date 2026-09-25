import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScannedBusinessCard {
  final String name;
  final String title;
  final String company;
  final String department;
  final String email;
  final String phone;
  final String website;
  final String address;
  final String notes;
  final bool isBusinessCard;

  const ScannedBusinessCard({
    required this.name,
    required this.title,
    required this.company,
    required this.department,
    required this.email,
    required this.phone,
    required this.website,
    required this.address,
    required this.notes,
    this.isBusinessCard = true,
  });

  factory ScannedBusinessCard.fromJson(Map<String, dynamic> json) {
    return ScannedBusinessCard(
      name: (json['name'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      company: (json['company'] as String? ?? '').trim(),
      department: (json['department'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      phone: (json['phone'] as String? ?? '').trim(),
      website: (json['website'] as String? ?? '').trim(),
      address: (json['address'] as String? ?? '').trim(),
      notes: (json['notes'] as String? ?? '').trim(),
      isBusinessCard: json['is_business_card'] == true,
    );
  }

  bool get isEmpty =>
      name.isEmpty &&
      company.isEmpty &&
      email.isEmpty &&
      phone.isEmpty &&
      title.isEmpty;
}

class BusinessCardScannerResult {
  final bool isSuccess;
  final bool isNotBusinessCard;
  final String? errorMessage;
  final ScannedBusinessCard? card;

  const BusinessCardScannerResult({
    required this.isSuccess,
    this.isNotBusinessCard = false,
    this.errorMessage,
    this.card,
  });

  factory BusinessCardScannerResult.success(ScannedBusinessCard card) {
    return BusinessCardScannerResult(
      isSuccess: true,
      card: card,
    );
  }

  factory BusinessCardScannerResult.notBusinessCard([String? message]) {
    return BusinessCardScannerResult(
      isSuccess: false,
      isNotBusinessCard: true,
      errorMessage: message ?? 'No business card or credential badge detected in the image.',
    );
  }

  factory BusinessCardScannerResult.failure(String error) {
    return BusinessCardScannerResult(
      isSuccess: false,
      errorMessage: error,
    );
  }
}

class BusinessCardScannerService {
  static final BusinessCardScannerService _instance =
      BusinessCardScannerService._internal();

  factory BusinessCardScannerService() => _instance;

  BusinessCardScannerService._internal();

  /// Scans a business card or badge image using GPT-4o-mini via the Eventzone Supabase Edge Function.
  Future<BusinessCardScannerResult> scanCardImage(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        return BusinessCardScannerResult.failure('Image file does not exist');
      }

      // Optimize image for ultra-fast upload and OpenAI token efficiency (<60KB)
      Uint8List? compressedBytes;
      try {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.path,
          minWidth: 800,
          minHeight: 800,
          quality: 75,
          format: CompressFormat.jpeg,
        );
      } catch (e) {
        debugPrint('Image compression error (using raw bytes fallback): $e');
      }

      final Uint8List finalBytes = compressedBytes ?? await imageFile.readAsBytes();
      final String base64Image = base64Encode(finalBytes);

      // Invoke Supabase Edge Function with gpt-4o-mini
      final response = await Supabase.instance.client.functions.invoke(
        'scan-business-card',
        body: {
          'image_base64': base64Image,
          'mime_type': 'image/jpeg',
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Edge Function error')
            : 'Edge Function status ${response.status}';
        return BusinessCardScannerResult.failure(errorMsg.toString());
      }

      final dynamic data = response.data;
      if (data is! Map<String, dynamic>) {
        return BusinessCardScannerResult.failure('Invalid response format from server');
      }

      if (data['is_business_card'] == false || data['error'] == 'not_a_business_card') {
        final msg = data['message'] as String? ??
            'The scanned image does not appear to be a business card or credential badge.';
        return BusinessCardScannerResult.notBusinessCard(msg);
      }

      if (data['success'] == true && data['data'] is Map<String, dynamic>) {
        final cardData = data['data'] as Map<String, dynamic>;
        final card = ScannedBusinessCard.fromJson(cardData);
        return BusinessCardScannerResult.success(card);
      }

      return BusinessCardScannerResult.failure(
        data['error']?.toString() ?? 'Unexpected server response',
      );
    } catch (e) {
      debugPrint('BusinessCardScannerService error: $e');
      String errorMsg = e.toString();
      if (e is FunctionException) {
        final details = e.details;
        if (details is Map && details['error'] != null) {
          errorMsg = details['error'].toString();
        } else if (details != null) {
          errorMsg = details.toString();
        }
      }
      return BusinessCardScannerResult.failure(errorMsg);
    }
  }
}
