import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PickedFileResult {
  final String name;
  final Uint8List bytes;

  PickedFileResult({required this.name, required this.bytes});
}

Future<PickedFileResult?> pickDeviceFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
    allowMultiple: false,
  );

  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return PickedFileResult(name: file.name, bytes: file.bytes!);
    }
  }
  return null;
}
