import 'package:flutter/material.dart';
import '../models/listing.dart';

class ProductionTimeBadge extends StatelessWidget {
  final ProductionTimeType type;
  final int? days;
  const ProductionTimeBadge(
      {super.key, required this.type, this.days});

  @override
  Widget build(BuildContext context) {
    final label = type == ProductionTimeType.instant
        ? '⚡ Instant'
        : '📅 Delivered in $days day${days == 1 ? '' : 's'}';
    return Chip(
      label: Text(label),
      backgroundColor: Colors.black12,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}
