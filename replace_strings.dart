import 'dart:io';

void main() {
  final scanQrPath = 'lib/screens/scan_qr_screen.dart';
  var content = File(scanQrPath).readAsStringSync();
  
  if (!content.contains('easy_localization.dart')) {
    content = content.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:easy_localization/easy_localization.dart';"
    );
  }

  // Define replacements
  final replacements = {
    '"Error: Not a valid Eventzone Profile QR code."': '"scan_qr_error_invalid_code".tr()',
    '"Detecting contact alignment..."': '"scan_qr_detecting_alignment".tr()',
    '"Fetching profile from database..."': '"scan_qr_fetching_profile".tr()',
    '"You cannot connect with yourself!"': '"scan_qr_error_connect_self".tr()',
    '"You are already connected with \$existingName!"': '"scan_qr_error_already_connected".tr(args: [existingName])',
    '"Eventzone User"': '"scan_qr_eventzone_user".tr()',
    '"\$job at \$comp"': '"scan_qr_job_at_comp".tr(args: [job, comp])',
    '"Professional at \$comp"': '"scan_qr_professional_at_comp".tr(args: [comp])',
    '"Attendee"': '"scan_qr_attendee".tr()',
    '"Error: Eventzone Profile not found in database."': '"scan_qr_error_profile_not_found".tr()',
    '"Error communicating with database."': '"scan_qr_error_db".tr()',
    '"Extracting contact fields..."': '"scan_qr_extracting_fields".tr()',
    '"Structuring connection info..."': '"scan_qr_structuring_info".tr()',
    '"Verification successful!"': '"scan_qr_verification_success".tr()',
    '"Added \$name (\$title) to contacts!"': '"scan_qr_added_contact".tr(args: [name, title])',
    '"Initializing OCR Scanner..."': '"scan_qr_initializing_ocr".tr()',
    '"Processing image..."': '"scan_qr_processing_image".tr()',
    '"Finding text blocks..."': '"scan_qr_finding_text".tr()',
    '"Identifying names & titles..."': '"scan_qr_identifying_names".tr()',
    '"Parsing emails & numbers..."': '"scan_qr_parsing_emails".tr()',
    '"Extracting contact metadata..."': '"scan_qr_extracting_metadata".tr()',
    '"Scan successful!"': '"scan_qr_scan_successful".tr()',
    '"Processing..."': '"scan_qr_processing".tr()',
    '"Scan QR to Connect"': '"scan_qr_title".tr()',
    '"Position QR code within the frame"': '"scan_qr_instruction".tr()',
    '"Align business card within the frame"': '"scan_qr_align_card".tr()',
    '"Hold steady..."': '"scan_qr_hold_steady".tr()',
    '"Tap to capture"': '"scan_qr_tap_capture".tr()',
    '"QR Code"': '"scan_qr_tab_qr".tr()',
    '"Business Card"': '"scan_qr_tab_card".tr()',
    '"Event Badge"': '"scan_qr_tab_badge".tr()'
  };
  
  // Note: For state variables initialized to strings, `.tr()` requires `BuildContext` 
  // if not using the static way, but `easy_localization`'s `.tr()` extension on `String` works fine without context.
  
  // Specifically avoid replacing `"QR Code"` or `"Business Card"` when it's used as state comparison:
  // e.g. `_scanType == "QR Code"` -> we shouldn't translate the state machine value.
  // We only replace when it's used in Text() widget or assigning to _ocrStatus!
  
  // Let's do regex replacements for Text(...) and _ocrStatus = ...
  
  // 1. Replacements for _ocrStatus assignments
  content = content.replaceAll('_ocrStatus = "Detecting contact alignment...";', '_ocrStatus = "scan_qr_detecting_alignment".tr();');
  content = content.replaceAll('_ocrStatus = "Fetching profile from database...";', '_ocrStatus = "scan_qr_fetching_profile".tr();');
  content = content.replaceAll('_ocrStatus = "Extracting contact fields...";', '_ocrStatus = "scan_qr_extracting_fields".tr();');
  content = content.replaceAll('_ocrStatus = "Structuring connection info...";', '_ocrStatus = "scan_qr_structuring_info".tr();');
  content = content.replaceAll('_ocrStatus = "Verification successful!";', '_ocrStatus = "scan_qr_verification_success".tr();');
  content = content.replaceAll('_ocrStatus = "Initializing OCR Scanner...";', '_ocrStatus = "scan_qr_initializing_ocr".tr();');
  content = content.replaceAll('_ocrStatus = "Processing image...";', '_ocrStatus = "scan_qr_processing_image".tr();');
  content = content.replaceAll('_ocrStatus = "Finding text blocks...";', '_ocrStatus = "scan_qr_finding_text".tr();');
  content = content.replaceAll('_ocrStatus = "Identifying names & titles...";', '_ocrStatus = "scan_qr_identifying_names".tr();');
  content = content.replaceAll('_ocrStatus = "Parsing emails & numbers...";', '_ocrStatus = "scan_qr_parsing_emails".tr();');
  content = content.replaceAll('_ocrStatus = "Extracting contact metadata...";', '_ocrStatus = "scan_qr_extracting_metadata".tr();');
  content = content.replaceAll('_ocrStatus = "Scan successful!";', '_ocrStatus = "scan_qr_scan_successful".tr();');
  
  // 2. Replacements for Text(...)
  content = content.replaceAll('Text("Error: Not a valid Eventzone Profile QR code.")', 'Text("scan_qr_error_invalid_code".tr())');
  content = content.replaceAll('Text("You cannot connect with yourself!")', 'Text("scan_qr_error_connect_self".tr())');
  content = content.replaceAll('Text("You are already connected with \$existingName!")', 'Text("scan_qr_error_already_connected".tr(args: [existingName]))');
  content = content.replaceAll('Text("Error: Eventzone Profile not found in database.")', 'Text("scan_qr_error_profile_not_found".tr())');
  content = content.replaceAll('Text("Error communicating with database.")', 'Text("scan_qr_error_db".tr())');
  content = content.replaceAll('Text("Added \$name (\$title) to contacts!")', 'Text("scan_qr_added_contact".tr(args: [name, title]))');
  content = content.replaceAll('Text("Scan QR to Connect")', 'Text("scan_qr_title".tr())');
  content = content.replaceAll('Text("Position QR code within the frame"', 'Text("scan_qr_instruction".tr()"'); // Fix the quote properly
  content = content.replaceAll('Text("Position QR code within the frame",', 'Text("scan_qr_instruction".tr(),'); 
  content = content.replaceAll('Text("Align business card within the frame",', 'Text("scan_qr_align_card".tr(),');
  content = content.replaceAll('Text("Processing...",', 'Text("scan_qr_processing".tr(),');
  content = content.replaceAll('Text("Hold steady...",', 'Text("scan_qr_hold_steady".tr(),');
  content = content.replaceAll('Text("Tap to capture",', 'Text("scan_qr_tap_capture".tr(),');

  content = content.replaceAll('Text("QR Code"', 'Text("scan_qr_tab_qr".tr()"'); 
  content = content.replaceAll('Text("QR Code",', 'Text("scan_qr_tab_qr".tr(),'); 
  content = content.replaceAll('Text("Business Card"', 'Text("scan_qr_tab_card".tr()"'); 
  content = content.replaceAll('Text("Business Card",', 'Text("scan_qr_tab_card".tr(),'); 
  content = content.replaceAll('Text("Event Badge"', 'Text("scan_qr_tab_badge".tr()"'); 
  content = content.replaceAll('Text("Event Badge",', 'Text("scan_qr_tab_badge".tr(),'); 

  // 3. Fallback names
  content = content.replaceAll('?? "Eventzone User"', '?? "scan_qr_eventzone_user".tr()');
  content = content.replaceAll('? (comp.isNotEmpty ? "\$job at \$comp" : job)', '? (comp.isNotEmpty ? "scan_qr_job_at_comp".tr(args: [job, comp]) : job)');
  content = content.replaceAll(': (comp.isNotEmpty ? "Professional at \$comp" : "Attendee");', ': (comp.isNotEmpty ? "scan_qr_professional_at_comp".tr(args: [comp]) : "scan_qr_attendee".tr());');

  File(scanQrPath).writeAsStringSync(content);
  
  
  // review_contact_screen.dart
  final reviewPath = 'lib/screens/review_contact_screen.dart';
  var reviewContent = File(reviewPath).readAsStringSync();

  reviewContent = reviewContent.replaceAll('Text("Review Contact",', 'Text("review_contact_title".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Name",', 'Text("review_contact_name".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Job Title",', 'Text("review_contact_job_title".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Company",', 'Text("review_contact_company".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Email",', 'Text("review_contact_email".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Phone",', 'Text("review_contact_phone".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Website",', 'Text("review_contact_website".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Address",', 'Text("review_contact_address".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Save Contact",', 'Text("review_contact_save".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Cancel",', 'Text("review_contact_cancel".tr(),');
  reviewContent = reviewContent.replaceAll('Text("Edit Contact",', 'Text("review_contact_edit".tr(),');
  reviewContent = reviewContent.replaceAll('Text("No image scanned")', 'Text("review_contact_no_image".tr())');
  reviewContent = reviewContent.replaceAll('Text("Scan Result",', 'Text("review_contact_scan_result".tr(),');

  File(reviewPath).writeAsStringSync(reviewContent);
  print("Replaced strings successfully");
}
