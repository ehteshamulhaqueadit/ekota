import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class PickedFileResult {
  final String name;
  final Uint8List bytes;

  PickedFileResult({required this.name, required this.bytes});
}

Future<PickedFileResult?> pickDeviceFile() async {
  final completer = Completer<PickedFileResult?>();

  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'image/*,.pdf,.doc,.docx';

  void cleanup() {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        if (reader.result is Uint8List) {
          final bytes = reader.result as Uint8List;
          if (!completer.isCompleted) {
            completer.complete(PickedFileResult(name: file.name, bytes: bytes));
          }
        } else {
          cleanup();
        }
      });
      reader.onError.listen((_) => cleanup());
    } else {
      cleanup();
    }
  });

  uploadInput.addEventListener('cancel', (_) => cleanup());

  uploadInput.click();

  // Safety fallback timeout after 30s
  Future.delayed(const Duration(seconds: 30), cleanup);

  return completer.future;
}
