import 'dart:io';

void main() {
  final scanQrPath = 'lib/screens/scan_qr_screen.dart';
  var content = File(scanQrPath).readAsStringSync();
  
  // Just remove 'const SnackBar' completely and replace with 'SnackBar'
  content = content.replaceAll('const SnackBar', 'SnackBar');
  
  File(scanQrPath).writeAsStringSync(content);
  print("Removed all const from SnackBars");
}
