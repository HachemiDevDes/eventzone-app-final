import 'dart:io';

void main() {
  final scanQrPath = 'lib/screens/scan_qr_screen.dart';
  var content = File(scanQrPath).readAsStringSync();
  
  content = content.replaceAll('const SnackBar(content: Text("scan_qr_error_invalid_code".tr()),', 'SnackBar(content: Text("scan_qr_error_invalid_code".tr()),');
  content = content.replaceAll('const SnackBar(content: Text("scan_qr_error_connect_self".tr()),', 'SnackBar(content: Text("scan_qr_error_connect_self".tr()),');
  content = content.replaceAll('const SnackBar(content: Text("scan_qr_error_already_connected".tr(args: [existingName])),', 'SnackBar(content: Text("scan_qr_error_already_connected".tr(args: [existingName])),');
  content = content.replaceAll('const SnackBar(content: Text("scan_qr_error_profile_not_found".tr()),', 'SnackBar(content: Text("scan_qr_error_profile_not_found".tr()),');
  content = content.replaceAll('const SnackBar(content: Text("scan_qr_error_db".tr()),', 'SnackBar(content: Text("scan_qr_error_db".tr()),');
  
  content = content.replaceAll('const SnackBar(\n              content: Text("scan_qr_error_invalid_code".tr()),', 'SnackBar(\n              content: Text("scan_qr_error_invalid_code".tr()),');
  content = content.replaceAll('const SnackBar(\n                content: Text("scan_qr_error_connect_self".tr()),', 'SnackBar(\n                content: Text("scan_qr_error_connect_self".tr()),');
  content = content.replaceAll('const SnackBar(\n                  content: Text("scan_qr_error_already_connected".tr(args: [existingName])),', 'SnackBar(\n                  content: Text("scan_qr_error_already_connected".tr(args: [existingName])),');
  content = content.replaceAll('const SnackBar(\n              content: Text("scan_qr_error_profile_not_found".tr()),', 'SnackBar(\n              content: Text("scan_qr_error_profile_not_found".tr()),');
  content = content.replaceAll('const SnackBar(\n            content: Text("scan_qr_error_db".tr()),', 'SnackBar(\n            content: Text("scan_qr_error_db".tr()),');

  File(scanQrPath).writeAsStringSync(content);
  print("Removed const properly!");
}
