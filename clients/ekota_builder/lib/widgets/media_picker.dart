import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';

class PickedMedia {
  final File file;
  final bool isVideo;
  PickedMedia(this.file, this.isVideo);
}

class MediaPicker extends StatefulWidget {
  final ValueChanged<List<PickedMedia>> onChanged;
  const MediaPicker({super.key, required this.onChanged});

  @override
  State<MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  final List<PickedMedia> _items = [];
  final _picker = ImagePicker();

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage();
    setState(() =>
        _items.addAll(files.map((f) => PickedMedia(File(f.path), false))));
    widget.onChanged(_items);
  }

  Future<void> _pickVideo() async {
    final file =
        await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _items.add(PickedMedia(File(file.path), true)));
      widget.onChanged(_items);
    }
  }

  void _remove(int i) {
    setState(() => _items.removeAt(i));
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Photos / Videos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < _items.length; i++) _thumb(i),
              _addButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumb(int i) {
    final item = _items[i];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black12,
              image: item.isVideo
                  ? null
                  : DecorationImage(
                      image: FileImage(item.file), fit: BoxFit.cover),
            ),
            child:
                item.isVideo ? const Icon(Icons.videocam, size: 32) : null,
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => _remove(i),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black87,
                child:
                    Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton() {
    return Row(children: [
      _actionTile(Icons.add_a_photo, _pickImages),
      const SizedBox(width: 8),
      _actionTile(Icons.video_call, _pickVideo),
    ]);
  }

  Widget _actionTile(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
