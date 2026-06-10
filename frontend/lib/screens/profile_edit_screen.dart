import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../providers/farmer_provider.dart';
import '../services/farmer_api.dart';
import '../widgets/glass_card.dart';
import '../app/l10n/translations.dart';
import '../models/plot_draft.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _initialized = false;

  late String _name;
  late String _location;
  late int _age;
  late String _gender;
  late List<PlotDraft> _plots;

  final List<String> _allCrops = [
    'Tomato', 'Wheat', 'Corn', 'Cotton', 'Sunflower', 'Lettuce', 'Pepper', 'Green Bean',
    'Barley', 'Rice', 'Soybean', 'Canola', 'Potato', 'Eggplant', 'Cucumber',
    'Grape', 'Orange', 'Lemon', 'Chickpea', 'Lentil', 'Oat', 'Carrot', 'Onion',
    'Garlic', 'Cabbage', 'Spinach', 'Zucchini', 'Watermelon', 'Melon', 'Cherry',
    'Peach', 'Pear', 'Plum', 'Olive', 'Walnut', 'Hazelnut', 'Fig', 'Pomegranate',
    'Apricot', 'Sugar Beet', 'Strawberry', 'Banana', 'Raspberry', 'Asparagus',
    'Broccoli', 'Cauliflower', 'Celery', 'Pea', 'Radish', 'Artichoke', 'Leek',
    'Kiwi', 'Mango', 'Avocado', 'Pineapple', 'Blueberry', 'Blackberry', 'Almond',
    'Pistachio', 'Peanut', 'Chestnut', 'Sesame', 'Tea', 'Coffee', 'Cocoa'
  ];

  @override
  Widget build(BuildContext context) {
    final farmerAsync = ref.watch(currentFarmerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.tr(context, 'edit_profile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: farmerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${L10n.tr(context, 'error_generic')}: $e')),
        data: (farmer) {
          if (!_initialized) {
            _name = farmer.name;
            _location = farmer.location;
            _age = farmer.age;
            _gender = farmer.gender;
            if (farmer.plots.isNotEmpty) {
              _plots = farmer.plots.map((p) => PlotDraft(
                name: p.name,
                sizeHectares: p.sizeHectares,
                irrigationLevel: p.irrigationLevel,
                crops: p.cropHistory.isNotEmpty ? [p.cropHistory.first.crop] : [],
              )).toList();
            } else {
              _plots = [PlotDraft()];
            }
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    showGradientBorder: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.tr(context, 'personal_info'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          initialValue: _name,
                          decoration: InputDecoration(
                            labelText: L10n.tr(context, 'full_name'),
                            prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          validator: (val) => val == null || val.isEmpty ? L10n.tr(context, 'enter_name_error') : null,
                          onSaved: (val) => _name = val ?? _name,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _location,
                          decoration: InputDecoration(
                            labelText: 'Location / City',
                            prefixIcon: Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          validator: (val) => val == null || val.isEmpty ? 'Please enter your location' : null,
                          onSaved: (val) => _location = val ?? _location,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _age.toString(),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: L10n.tr(context, 'age'),
                            prefixIcon: Icon(Icons.cake_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          validator: (val) {
                            if (val == null || val.isEmpty) return L10n.tr(context, 'enter_age_error');
                            final parsed = int.tryParse(val);
                            if (parsed == null || parsed < 18 || parsed > 120) return L10n.tr(context, 'valid_age_error');
                            return null;
                          },
                          onSaved: (val) => _age = int.tryParse(val ?? '') ?? _age,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: InputDecoration(
                            labelText: L10n.tr(context, 'Gender'),
                            prefixIcon: Icon(Icons.wc_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          dropdownColor: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
                          items: [
                            DropdownMenuItem(value: 'Male', child: Text(L10n.tr(context, 'male'))),
                            DropdownMenuItem(value: 'Female', child: Text(L10n.tr(context, 'female'))),
                            DropdownMenuItem(value: 'Other', child: Text(L10n.tr(context, 'other_gender'))),
                            DropdownMenuItem(value: 'Prefer not to say', child: Text(L10n.tr(context, 'prefer_not_to_say'))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _gender = val);
                            }
                          },
                          onSaved: (val) => _gender = val ?? _gender,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        L10n.tr(context, 'my_fields') ?? 'Arazilerim / Tarlalarım',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _plots.add(PlotDraft(name: '${L10n.tr(context, 'new_field') ?? 'Yeni Tarla'} ${_plots.length + 1}'));
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(L10n.tr(context, 'add_field') ?? 'Tarla Ekle'),
                        style: TextButton.styleFrom(foregroundColor: AgriAgentTheme.infoBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _plots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildPlotDraftCard(index);
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AgriAgentTheme.mossGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AgriAgentTheme.mossGreen.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                L10n.tr(context, 'save_changes'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      final farmer = ref.read(currentFarmerProvider).value!;
      final api = ref.read(farmerApiProvider);
      Set<String> allCrops = {};
      for (var plot in _plots) {
        allCrops.addAll(plot.crops);
      }

      await api.updateProfile(farmer.userId, {
        'name': _name,
        'location': _location,
        'region': _location, // Fallback for region
        'age': _age,
        'gender': _gender,
        'crops': allCrops.toList(),
        'plots': _plots.map((p) => p.toJson()).toList(),
      });

      ref.invalidate(currentFarmerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.tr(context, 'profile_updated')),
            backgroundColor: AgriAgentTheme.successGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L10n.tr(context, 'error_generic')}: $e'),
            backgroundColor: AgriAgentTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPlotDraftCard(int index) {
    final plot = _plots[index];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriAgentTheme.mossGreen.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: plot.name,
                  decoration: InputDecoration(
                    labelText: L10n.tr(context, 'field_name_hint') ?? 'Tarla Adı (Örn: Domates Serası)',
                    prefixIcon: const Icon(Icons.grass),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                  ),
                  onChanged: (val) => plot.name = val,
                ),
              ),
              if (_plots.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _plots.removeAt(index);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${L10n.tr(context, 'farm_size')}: ${L10n.formatFarmSize(context, plot.sizeHectares)}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: plot.sizeHectares,
            min: 0.1,
            max: 500.0,
            activeColor: AgriAgentTheme.mossGreen,
            inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            onChanged: (val) => setState(() => plot.sizeHectares = val),
          ),
          const SizedBox(height: 16),
          Text(
            L10n.tr(context, 'primary_crop'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allCrops.map((crop) {
              final isSelected = plot.crops.contains(crop);
              return FilterChip(
                label: Text(crop),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      plot.crops.add(crop);
                    } else {
                      plot.crops.remove(crop);
                    }
                  });
                },
                selectedColor: AgriAgentTheme.mossGreen.withOpacity(0.25),
                checkmarkColor: AgriAgentTheme.mossGreen,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
