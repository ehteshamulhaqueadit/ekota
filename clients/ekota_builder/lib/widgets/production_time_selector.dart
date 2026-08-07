import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';

class ProductionTimeSelector extends StatefulWidget {
  final void Function(ProductionTimeType type, int? days) onChanged;
  const ProductionTimeSelector({super.key, required this.onChanged});

  @override
  State<ProductionTimeSelector> createState() =>
      _ProductionTimeSelectorState();
}

class _ProductionTimeSelectorState extends State<ProductionTimeSelector> {
  ProductionTimeType _type = ProductionTimeType.instant;
  final _daysController = TextEditingController();

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  void _emit() {
    final days = _type == ProductionTimeType.scheduled
        ? int.tryParse(_daysController.text)
        : null;
    widget.onChanged(_type, days);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Production Time',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(children: [
          ChoiceChip(
            label: const Text('Instant'),
            selected: _type == ProductionTimeType.instant,
            selectedColor: AppColors.inputFill,
            onSelected: (_) {
              setState(() => _type = ProductionTimeType.instant);
              _emit();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('N days'),
            selected: _type == ProductionTimeType.scheduled,
            selectedColor: AppColors.inputFill,
            onSelected: (_) {
              setState(() => _type = ProductionTimeType.scheduled);
              _emit();
            },
          ),
        ]),
        if (_type == ProductionTimeType.scheduled) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(hintText: 'Number of days'),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }
}
