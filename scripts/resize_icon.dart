import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/icon/app_icon.png');
  if (!file.existsSync()) {
    print('Error: assets/icon/app_icon.png not found');
    return;
  }
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: Could not decode image');
    return;
  }
  print('Original icon size: ${image.width}x${image.height}');
  
  final resized = img.copyResize(image, width: 512, height: 512, interpolation: img.Interpolation.cubic);
  final pngBytes = img.encodePng(resized, level: 6);
  final outputFile = File('assets/icon/play_store_icon_512.png');
  outputFile.writeAsBytesSync(pngBytes);
  print('Successfully created Play Store Icon (512x512)!');
  print('Output path: ${outputFile.absolute.path}');
  print('File size: ${pngBytes.length} bytes (${(pngBytes.length / 1024).toStringAsFixed(1)} KB)');
}
