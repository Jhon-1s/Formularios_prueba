import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageUtils {
  // ============================================================
  // COMPRIMIR IMAGEN
  // ============================================================
  static Future<File> comprimirImagen({
    required File imagen,
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 70,
  }) async {
    try {
      // Leer imagen
      final bytes = await imagen.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return imagen;
      
      // Redimensionar si excede el tamaño máximo
      if (image.width > maxWidth || image.height > maxHeight) {
        image = img.copyResize(image, width: maxWidth, height: maxHeight);
      }
      
      // Comprimir
      final compressedBytes = img.encodeJpg(image, quality: quality);
      
      // Guardar en archivo temporal
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basenameWithoutExtension(imagen.path);
      final tempFile = File('${tempDir.path}/${fileName}_compressed.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      
      return tempFile;
    } catch (e) {
      print('Error comprimiendo imagen: $e');
      return imagen;
    }
  }
  
  // ============================================================
  // OBTENER TAMAÑO DEL ARCHIVO (EN MB)
  // ============================================================
  static double getFileSizeMB(File file) {
    final bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }
  
  // ============================================================
  // VALIDAR SI EL ARCHIVO EXCEDE EL TAMAÑO MÁXIMO
  // ============================================================
  static bool excedeTamañoMaximo(File file, {int maxMB = 10}) {
    return getFileSizeMB(file) > maxMB;
  }
}