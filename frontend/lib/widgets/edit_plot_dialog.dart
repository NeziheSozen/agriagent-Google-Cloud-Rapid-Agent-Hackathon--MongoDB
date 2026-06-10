import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/farmer_profile.dart';
import '../services/farmer_api.dart';
import '../providers/farmer_provider.dart';
import '../app/theme.dart';
import '../app/l10n/translations.dart';

class EditPlotDialog extends ConsumerStatefulWidget {
  final FarmPlot plot;
  final int plotIndex;
  final String userId;

  const EditPlotDialog({
    super.key,
    required this.plot,
    required this.plotIndex,
    required this.userId,
  });

  @override
  ConsumerState<EditPlotDialog> createState() => _EditPlotDialogState();
}

class _EditPlotDialogState extends ConsumerState<EditPlotDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String _name;
  late double _sizeHectares;
  late String _irrigationLevel;
  late String _tenureType;

  // New crop history fields
  bool _addCropHistory = false;
  int _cropYear = DateTime.now().year;
  String _cropName = 'Wheat';
  double _yieldTons = 0.0;
  double _profit = 0.0;

  @override
  void initState() {
    super.initState();
    _name = widget.plot.name;
    _sizeHectares = widget.plot.sizeHectares;
    _irrigationLevel = widget.plot.irrigationLevel;
    _tenureType = widget.plot.tenureType;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final api = ref.read(farmerApiProvider);
      await api.updatePlot(widget.userId, widget.plotIndex, {
        'name': _name,
        'size_hectares': _sizeHectares,
        'irrigation_level': _irrigationLevel,
        'tenure_type': _tenureType,
      });

      if (_addCropHistory) {
        await api.addCropHistory(widget.userId, widget.plotIndex, {
          'year': _cropYear,
          'crop': _cropName,
          'yield_tons_per_hectare': _yieldTons,
          'profit': _profit,
        });
      }

      // Refresh the provider
      ref.read(selectedFarmerIdProvider.notifier).set(widget.userId);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarla başarıyla güncellendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarla güncellenemedi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tarlayı Düzenle',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(
                  labelText: L10n.tr(context, 'field_name_label') ?? 'Tarla Adı',
                  prefixIcon: const Icon(Icons.grass),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.isEmpty ? (L10n.tr(context, 'field_name_error') ?? 'Lütfen tarla adını girin') : null,
                onSaved: (val) => _name = val ?? _name,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _sizeHectares.toString(),
                decoration: InputDecoration(
                  labelText: L10n.tr(context, 'farm_size'),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || double.tryParse(val) == null ? 'Geçerli bir sayı girin' : null,
                onSaved: (val) => _sizeHectares = double.tryParse(val ?? '') ?? _sizeHectares,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: ['Low', 'Medium', 'High', 'None'].contains(_irrigationLevel) ? _irrigationLevel : 'Medium',
                decoration: InputDecoration(
                  labelText: L10n.tr(context, 'irrigation'),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['None', 'Low', 'Medium', 'High']
                    .map((e) => DropdownMenuItem(value: e, child: Text(L10n.trSeverity(context, e))))
                    .toList(),
                onChanged: (val) => setState(() => _irrigationLevel = val ?? _irrigationLevel),
                onSaved: (val) => _irrigationLevel = val ?? _irrigationLevel,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: ['Owned', 'Leased', 'Rented'].contains(_tenureType) ? _tenureType : 'Owned',
                decoration: InputDecoration(
                  labelText: 'Mülkiyet Durumu',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Owned', 'Leased', 'Rented']
                    .map((e) {
                      String trText = e;
                      if (e == 'Owned') trText = 'Kendime Ait';
                      if (e == 'Leased') trText = 'Kiralık (Uzun Dönem)';
                      if (e == 'Rented') trText = 'Kiralık (Kısa Dönem)';
                      return DropdownMenuItem(value: e, child: Text(trText));
                    })
                    .toList(),
                onChanged: (val) => setState(() => _tenureType = val ?? _tenureType),
                onSaved: (val) => _tenureType = val ?? _tenureType,
              ),
              const SizedBox(height: 24),
              Divider(),
              SwitchListTile(
                title: const Text('Geçmiş Hasat Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Ekim Yılları / Son Mahsul'),
                value: _addCropHistory,
                onChanged: (val) => setState(() => _addCropHistory = val),
              ),
              if (_addCropHistory) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _cropYear.toString(),
                        decoration: const InputDecoration(labelText: 'Yıl', filled: true),
                        keyboardType: TextInputType.number,
                        onSaved: (val) => _cropYear = int.tryParse(val ?? '') ?? _cropYear,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _cropName,
                        decoration: const InputDecoration(labelText: 'Mahsul', filled: true),
                        onSaved: (val) => _cropName = val ?? _cropName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _yieldTons.toString(),
                        decoration: const InputDecoration(labelText: 'Verim (t/ha)', filled: true),
                        keyboardType: TextInputType.number,
                        onSaved: (val) => _yieldTons = double.tryParse(val ?? '') ?? _yieldTons,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _profit.toString(),
                        decoration: const InputDecoration(labelText: 'Kâr (USD)', filled: true),
                        keyboardType: TextInputType.number,
                        onSaved: (val) => _profit = double.tryParse(val ?? '') ?? _profit,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AgriAgentTheme.mossGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Değişiklikleri Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
