import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageUtils {
  static Future<File> resizeImage(File originalImage, int width, int height,
      {required String outputPath}) async {
    // Read the original image
    final image = img.decodeImage(originalImage.readAsBytesSync());

    // Resize the image
    final resizedImage = img.copyResize(image!, width: width, height: height);

    // Create a new file with the resized image
    // Using a unique outputPath ensures that the UI correctly detects the file change.
    final resizedFile = File(outputPath);
    resizedFile.writeAsBytesSync(img.encodeJpg(resizedImage));

    return resizedFile;
  }
}
