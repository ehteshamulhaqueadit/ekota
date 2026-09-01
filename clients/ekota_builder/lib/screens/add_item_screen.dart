import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../services/listing_service.dart';
import '../widgets/media_picker.dart';
import '../widgets/production_time_selector.dart';
import '../widgets/app_bottom_nav.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _assetName = TextEditingController();
  final _category = TextEditingController();
  final _fundingTarget = TextEditingController();
  final _rentalPrice = TextEditingController();
  final _description = TextEditingController();
  final _specifications = TextEditingController();
  final _weightKg = TextEditingController();
  final _sizeCubicCm = TextEditingController();

  List<PickedMedia> _media = [];
  ProductionTimeType _prodType = ProductionTimeType.instant;
  int? _prodDays;
  bool _submitting = false;

  @override
  void dispose() {
    _assetName.dispose();
    _category.dispose();
    _fundingTarget.dispose();
    _rentalPrice.dispose();
    _description.dispose();
    _specifications.dispose();
    _weightKg.dispose();
    _sizeCubicCm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one photo or video')),
      );
      return;
    }

    if (_prodType == ProductionTimeType.scheduled &&
        _prodDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter number of production days')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      // TODO: upload each file in _media to POST /api/uploads (multipart),
      // collect returned URLs, then populate the lists below.
      final imageUrls = <String>[];
      final videoUrls = <String>[];

      final listing = await ListingService().createListing({
        'assetName': _assetName.text.trim(),
        'category': _category.text.trim(),
        'fundingTarget': double.tryParse(_fundingTarget.text) ?? 0,
        'rentalPrice': double.tryParse(_rentalPrice.text) ?? 0,
        'description': _description.text.trim(),
        'specifications': _specifications.text.trim(),
        'imageUrls': imageUrls,
        'videoUrls': videoUrls,
        'productionTimeType':
            _prodType == ProductionTimeType.instant
                ? 'instant'
                : 'scheduled',
        'productionDays': _prodDays,
        if (_weightKg.text.isNotEmpty) 'weightKg': double.tryParse(_weightKg.text),
        if (_sizeCubicCm.text.isNotEmpty) 'sizeCubicCm': double.tryParse(_sizeCubicCm.text),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(
            context, '/listings/${listing.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Item')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _label('Asset Name'),
              const SizedBox(height: 6),
              TextFormField(
                  controller: _assetName,
                  validator: _required,
                  decoration:
                      const InputDecoration(hintText: 'e.g. Cinema Camera')),
              const SizedBox(height: 16),

              _label('Category'),
              const SizedBox(height: 6),
              TextFormField(
                  controller: _category,
                  validator: _required,
                  decoration:
                      const InputDecoration(hintText: 'e.g. Film Equipment')),
              const SizedBox(height: 16),

              _label('Funding Target (৳)'),
              const SizedBox(height: 6),
              TextFormField(
                  controller: _fundingTarget,
                  keyboardType: TextInputType.number,
                  validator: _required,
                  decoration:
                      const InputDecoration(hintText: 'e.g. 50000')),
              const SizedBox(height: 16),

              _label('Rental Price / day (৳)'),
              const SizedBox(height: 6),
              TextFormField(
                  controller: _rentalPrice,
                  keyboardType: TextInputType.number,
                  validator: _required,
                  decoration:
                      const InputDecoration(hintText: 'e.g. 1500')),
              const SizedBox(height: 16),

              _label('Description'),
              const SizedBox(height: 6),
              TextFormField(
                  controller: _description,
                  maxLines: 3,
                  validator: _required,
                  decoration: const InputDecoration(
                      hintText: 'Describe your asset…')),
              const SizedBox(height: 16),

              _label('Specifications'),
              const SizedBox(height: 6),
              TextFormField(
                  controller: _specifications,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      hintText: 'Technical details (optional)')),
              const SizedBox(height: 20),

              _label('Weight (kg)'),
              const SizedBox(height: 6),
              TextFormField(
                  controller: _weightKg,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'e.g. 2.5 (for warehouse fee)')),
              const SizedBox(height: 16),

              _label('Size (cubic cm)'),
              const SizedBox(height: 6),
              TextFormField(
                  controller: _sizeCubicCm,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'e.g. 5000 (for warehouse fee)')),
              const SizedBox(height: 20),

              MediaPicker(onChanged: (m) => setState(() => _media = m)),
              const SizedBox(height: 20),

              ProductionTimeSelector(onChanged: (type, days) {
                _prodType = type;
                _prodDays = days;
              }),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text('Post Listing'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        shape: const CircleBorder(),
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold));

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'This field is required' : null;
}
