import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../app/theme.dart';
import '../widgets/glass_card.dart';
import '../providers/farmer_provider.dart';
import '../providers/cooperative_provider.dart';
import '../services/farmer_api.dart';
import '../app/l10n/translations.dart';
import '../models/plot_draft.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  bool _isLoading = false;
  bool _isDetectingLocation = false;
  int _currentPage = 0; // 0 = profile, 1 = cooperative
  
  // Form values
  String _name = '';
  String _email = '';
  int _age = 45;
  String _gender = 'Prefer not to say';
  String _country = 'Turkey';
  String _location = 'Antalya';
  String _region = 'Mediterranean';
  
  // List of plots
  final List<PlotDraft> _plots = [PlotDraft()];

  // Cooperative form values
  int _coopChoice = -1; // -1 = not chosen, 0 = create, 1 = join, 2 = skip
  String _coopName = '';
  String _coopDescription = '';
  String _coopType = 'collective'; // official, collective
  String _joinCode = '';

  // Irrigation auto-detect
  bool _isDetectingIrrigation = false;
  String? _irrigationRecommendation;
  Map<String, dynamic>? _irrigationDetails;

  final List<String> _countries = [
    'Turkey', 'USA', 'Germany', 'France', 'Italy', 'Spain', 
    'UK', 'Canada', 'Australia', 'Brazil', 'India', 'China', 'Japan', 'Netherlands', 'Russia'
  ];
  
  final Map<String, List<String>> _countryCities = {
    'Turkey': [
      'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin', 'Aydın', 'Balıkesir',
      'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli',
      'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari',
      'Hatay', 'Isparta', 'Mersin', 'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir',
      'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
      'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat',
      'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman',
      'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan', 'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce'
    ],
    'USA': ['California', 'Texas', 'Florida', 'New York', 'Illinois', 'Washington', 'Ohio', 'Georgia'],
    'Germany': ['Berlin', 'Munich', 'Hamburg', 'Frankfurt', 'Cologne', 'Stuttgart', 'Düsseldorf'],
    'France': ['Paris', 'Marseille', 'Lyon', 'Toulouse', 'Nice', 'Nantes', 'Strasbourg'],
    'Italy': ['Rome', 'Milan', 'Naples', 'Turin', 'Palermo', 'Florence', 'Venice'],
    'Spain': ['Madrid', 'Barcelona', 'Valencia', 'Seville', 'Zaragoza', 'Malaga'],
    'UK': ['London', 'Birmingham', 'Manchester', 'Glasgow', 'Liverpool', 'Edinburgh'],
    'Canada': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa'],
    'Australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide'],
    'Brazil': ['São Paulo', 'Rio de Janeiro', 'Brasília', 'Salvador', 'Fortaleza'],
    'India': ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai'],
    'China': ['Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen', 'Chengdu'],
    'Japan': ['Tokyo', 'Osaka', 'Kyoto', 'Yokohama', 'Nagoya'],
    'Netherlands': ['Amsterdam', 'Rotterdam', 'The Hague', 'Utrecht', 'Eindhoven'],
    'Russia': ['Moscow', 'Saint Petersburg', 'Novosibirsk', 'Yekaterinburg', 'Kazan']
  };

  List<String> get _locations => _countryCities[_country] ?? ['Unknown'];

  final Map<String, List<String>> _countryRegions = {
    'Turkey': ['Mediterranean', 'Thrace', 'Central Anatolia', 'Çukurova', 'Aegean', 'Other'],
    'USA': ['West Coast', 'Midwest', 'South', 'Northeast', 'Other'],
    'Germany': ['North', 'South', 'East', 'West', 'Other'],
    'France': ['North', 'South', 'East', 'West', 'Other'],
    'Italy': ['North', 'South', 'Central', 'Other'],
    'Spain': ['North', 'South', 'East', 'West', 'Other'],
    'UK': ['England', 'Scotland', 'Wales', 'Northern Ireland', 'Other'],
  };

  List<String> get _regions => _countryRegions[_country] ?? ['North', 'South', 'East', 'West', 'Central', 'Other'];
  final List<String> _crops = [
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

  bool _didTranslateDefaultPlot = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didTranslateDefaultPlot && _plots.isNotEmpty && _plots[0].name == 'Ana Tarla') {
      _plots[0].name = L10n.tr(context, 'main_field') ?? 'Ana Tarla';
      _didTranslateDefaultPlot = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final detectedCountry = place.country ?? 'Turkey';
        final detectedCity = place.administrativeArea ?? place.locality ?? 'Antalya';
        
        setState(() {
          if (_countries.contains(detectedCountry)) {
            _country = detectedCountry;
          } else {
            _countries.add(detectedCountry);
            _countryCities[detectedCountry] = [detectedCity];
            _country = detectedCountry;
          }
          
          if (!_locations.contains(detectedCity)) {
            _countryCities[_country]!.add(detectedCity);
          }
          _location = detectedCity;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.tr(context, 'location_detected')), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${L10n.tr(context, 'location_failed')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  void _goToCoopStep() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _goBack() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _submitForm({String? cooperativeId, String? cooperativeName}) async {
    setState(() => _isLoading = true);

    try {
      final api = ref.read(farmerApiProvider);
      
      // Calculate total size and all crops for the initial quick create
      double totalSize = _plots.fold(0.0, (sum, plot) => sum + plot.sizeHectares);
      Set<String> allCrops = {};
      for (var plot in _plots) {
        allCrops.addAll(plot.crops);
      }
      if (allCrops.isEmpty) allCrops.add('Tomato');

      final profileData = <String, dynamic>{
        'name': _name,
        'email': _email,
        'age': _age,
        'gender': _gender,
        'location': '$_location, $_country',
        'region': _location,
        'size_hectares': totalSize,
        'irrigation_level': _plots.first.irrigationLevel, // Use first plot's irrigation for summary
        'crops': allCrops.toList(),
      };

      if (cooperativeId != null) {
        profileData['cooperative_id'] = cooperativeId;
      }
      if (cooperativeName != null) {
        profileData['cooperative_name'] = cooperativeName;
      }

      final profile = await api.createProfile(profileData);

      // Now update the profile with the specific detailed plots if user added multiple
      try {
        await api.updateProfile(profile.userId, {
          'plots': _plots.map((p) => p.toJson()).toList(),
        });
      } catch (e) {
        // Just log or ignore since profile is created
        debugPrint('Warning: Could not sync detailed plots array: $e');
      }

      if (mounted) {
        ref.read(selectedFarmerIdProvider.notifier).set(profile.userId);
        context.go('/offline-setup');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${L10n.tr(context, 'profile_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCoopSubmit() async {
    if (_coopChoice == 2) {
      // Skip → submit without cooperative
      _submitForm();
      return;
    }

    if (_coopChoice == 0) {
      // Create new cooperative
      if (_coopName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.tr(context, 'enter_coop_name')),
          backgroundColor: AgriAgentTheme.warningOrange,
        ),
      );
        return;
      }

      setState(() => _isLoading = true);
      try {
        final coop = await createCooperative(
          ref,
          name: _coopName.trim(),
          region: _location,
          description: _coopDescription.trim(),
          coopType: _coopType,
          adminId: '', // Will be set by backend after profile creation
          adminName: _name,
        );
        _submitForm(
          cooperativeId: coop.coopId,
          cooperativeName: coop.name,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${L10n.tr(context, 'coop_create_failed')}: $e')),
          );
        }
      }
      return;
    }

    if (_coopChoice == 1) {
      // Join existing cooperative
      if (_joinCode.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.tr(context, 'enter_join_code')),
          backgroundColor: AgriAgentTheme.warningOrange,
        ),
      );
        return;
      }

      setState(() => _isLoading = true);
      try {
        final coop = await joinCooperative(
          ref,
          joinCode: _joinCode.trim(),
          userId: '', // Will be set by backend
        );
        _submitForm(
          cooperativeId: coop.coopId,
          cooperativeName: coop.name,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${L10n.tr(context, 'coop_join_failed')}: $e')),
          );
        }
      }
      return;
    }

    // No choice made
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10n.tr(context, 'select_option')),
        backgroundColor: AgriAgentTheme.warningOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildProfilePage(),
                _buildCooperativePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page 0: Profile ──────────────────────────────────────────────────────

  Widget _buildProfilePage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              L10n.tr(context, 'welcome_title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.tr(context, 'welcome_subtitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            GlassCard(
              padding: const EdgeInsets.all(24),
              showGradientBorder: true,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      label: L10n.tr(context, 'full_name'),
                      icon: Icons.person_outline,
                      onSaved: (val) => _name = val ?? '',
                      validator: (val) => val!.isEmpty ? L10n.tr(context, 'enter_name_error') : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: L10n.tr(context, 'enter_email'),
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      onSaved: (val) => _email = val ?? '',
                      validator: (val) {
                        if (val == null || val.isEmpty) return L10n.tr(context, 'enter_email_error');
                        final isEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val);
                        if (!isEmail) return L10n.tr(context, 'invalid_email_error');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: L10n.tr(context, 'age'),
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      onSaved: (val) => _age = int.tryParse(val ?? '') ?? 45,
                      validator: (val) {
                        if (val == null || val.isEmpty) return L10n.tr(context, 'enter_age_error');
                        final parsed = int.tryParse(val);
                        if (parsed == null || parsed < 18 || parsed > 120) return L10n.tr(context, 'valid_age_error');
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: L10n.tr(context, 'Gender'),
                      icon: Icons.wc_rounded,
                      value: _gender,
                      items: const ['Male', 'Female', 'Other', 'Prefer not to say'],
                      onChanged: (val) {
                        setState(() {
                          _gender = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: L10n.tr(context, 'country'),
                            icon: Icons.public,
                            value: _country,
                            items: _countries,
                            onChanged: (val) {
                              setState(() {
                                _country = val!;
                                _location = _locations.first;
                                _region = _regions.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: _isDetectingLocation 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, color: AgriAgentTheme.infoBlue),
                          onPressed: _isDetectingLocation ? null : _detectLocation,
                          tooltip: L10n.tr(context, 'detect_location'),
                          style: IconButton.styleFrom(
                            backgroundColor: AgriAgentTheme.infoBlue.withOpacity(0.1),
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: L10n.tr(context, 'province_city'),
                      icon: Icons.location_on_outlined,
                      value: _location,
                      items: _locations,
                      onChanged: (val) => setState(() => _location = val!),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    // Dynamic Plots Area
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
                      onPressed: _goToCoopStep,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AgriAgentTheme.mossGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            L10n.tr(context, 'continue_btn'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(L10n.tr(context, 'back_to_login'), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ── Page 1: Cooperative ──────────────────────────────────────────────────

  Widget _buildCooperativePage() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Step indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepDot(isActive: false, isDone: true),
                Container(
                  width: 40,
                  height: 2,
                  color: AgriAgentTheme.mossGreen,
                ),
                _buildStepDot(isActive: true, isDone: false),
              ],
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.groups_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              L10n.tr(context, 'coop_title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.tr(context, 'coop_subtitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Option cards
            _buildCoopOptionCard(
              index: 0,
              emoji: '🏗️',
              title: L10n.tr(context, 'create_network'),
              subtitle: L10n.tr(context, 'create_network_desc'),
              icon: Icons.add_circle_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildCoopOptionCard(
              index: 1,
              emoji: '🤝',
              title: L10n.tr(context, 'join_network'),
              subtitle: L10n.tr(context, 'join_network_desc'),
              icon: Icons.group_add_outlined,
            ),
            const SizedBox(height: 12),
            _buildCoopOptionCard(
              index: 2,
              emoji: '⏭️',
              title: L10n.tr(context, 'skip_for_now'),
              subtitle: L10n.tr(context, 'skip_desc'),
              icon: Icons.skip_next_outlined,
            ),
            const SizedBox(height: 20),

            // Expanded form area based on choice
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _buildCoopForm(),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _goBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(L10n.tr(context, 'back_btn')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _coopChoice == -1) ? null : _handleCoopSubmit,
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
                        : Text(
                            _coopChoice == 2 ? L10n.tr(context, 'complete_profile') : L10n.tr(context, 'create_and_complete'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStepDot({required bool isActive, required bool isDone}) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isDone
            ? AgriAgentTheme.mossGreen
            : isActive
                ? AgriAgentTheme.mossGreen.withOpacity(0.2)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        shape: BoxShape.circle,
        border: isActive
            ? Border.all(color: AgriAgentTheme.mossGreen, width: 2)
            : null,
      ),
      child: isDone
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : isActive
              ? Container(
                  margin: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AgriAgentTheme.mossGreen,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
    );
  }

  Widget _buildCoopOptionCard({
    required int index,
    required String emoji,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _coopChoice == index;
    final accentColor = index == 0
        ? AgriAgentTheme.infoBlue
        : index == 1
            ? AgriAgentTheme.mossGreen
            : AgriAgentTheme.warningOrange;

    return GlassCard(
      onTap: () => setState(() => _coopChoice = index),
      showGradientBorder: isSelected,
      accentColor: accentColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? accentColor
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? accentColor : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCoopForm() {
    if (_coopChoice == 0) {
      // Create new network
      return GlassCard(
        key: const ValueKey('create_form'),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_business_rounded,
                  color: AgriAgentTheme.infoBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  L10n.tr(context, 'new_network_info'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AgriAgentTheme.infoBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: L10n.tr(context, 'coop_name'),
              icon: Icons.business_outlined,
              onSaved: (_) {},
              validator: (val) => null,
              onChanged: (val) => _coopName = val,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: L10n.tr(context, 'coop_description'),
              icon: Icons.description_outlined,
              onSaved: (_) {},
              validator: (val) => null,
              onChanged: (val) => _coopDescription = val,
            ),
            const SizedBox(height: 12),
            // Type selector
            Row(
              children: [
                Expanded(
                  child: _buildTypeChip(
                    label: L10n.tr(context, 'official_coop'),
                    icon: Icons.verified_outlined,
                    value: 'official',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTypeChip(
                    label: L10n.tr(context, 'voluntary_network'),
                    icon: Icons.handshake_outlined,
                    value: 'collective',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_coopChoice == 1) {
      // Join existing network
      return GlassCard(
        key: const ValueKey('join_form'),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.vpn_key_rounded,
                  color: AgriAgentTheme.mossGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Join Code',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AgriAgentTheme.mossGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Join Code (e.g. ABC-123)',
              icon: Icons.tag_rounded,
              onSaved: (_) {},
              validator: (val) => null,
              onChanged: (val) => _joinCode = val,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the code you received from the cooperative administrator.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // No form for skip or no choice
    return const SizedBox.shrink(key: ValueKey('empty'));
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _coopType == value;
    return GestureDetector(
      onTap: () => setState(() => _coopType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AgriAgentTheme.infoBlue.withOpacity(0.15)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AgriAgentTheme.infoBlue
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AgriAgentTheme.infoBlue
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AgriAgentTheme.infoBlue
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required void Function(String?) onSaved,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      validator: validator,
      onSaved: onSaved,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdown({required String label, required IconData icon, required String value, required List<String> items, required void Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      dropdownColor: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
  // ── Auto-detect irrigation ──────────────────────────────────────────────

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
            children: _crops.map((crop) {
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
          const SizedBox(height: 16),
          _buildIrrigationAutoCard(index),
        ],
      ),
    );
  }

  Widget _buildIrrigationAutoCard(int plotIndex) {
    final plot = _plots[plotIndex];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _irrigationDetails != null
              ? _getIrrigationColor(plot.irrigationLevel).withOpacity(0.4)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.water_drop_outlined,
                color: _irrigationDetails != null
                    ? _getIrrigationColor(plot.irrigationLevel)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                L10n.tr(context, 'irrigation_need'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_irrigationDetails != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getIrrigationColor(plot.irrigationLevel).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plot.irrigationLevel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getIrrigationColor(plot.irrigationLevel),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_irrigationDetails != null) ...[
            Text(
              _irrigationRecommendation ?? '',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMiniStat(L10n.tr(context, 'soil_moisture'), '%${_irrigationDetails!['soil_moisture_percent']}'),
                const SizedBox(width: 12),
                _buildMiniStat('ET0', '${_irrigationDetails!['et0_daily_mm']}mm/day'),
                const SizedBox(width: 12),
                _buildMiniStat(L10n.tr(context, 'last_7_days'), '${_irrigationDetails!['precipitation_last_7days_mm']}mm'),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDetectingIrrigation ? null : () => _detectIrrigation(plotIndex),
                icon: _isDetectingIrrigation
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.satellite_alt, size: 16),
                label: Text(
                  _isDetectingIrrigation ? L10n.tr(context, 'analyzing_irrigation') : L10n.tr(context, 'detect_from_satellite'),
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AgriAgentTheme.infoBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color _getIrrigationColor(String level) {
    switch (level) {
      case 'None': return AgriAgentTheme.mossGreen;
      case 'Low': return AgriAgentTheme.infoBlue;
      case 'Medium': return AgriAgentTheme.warningOrange;
      case 'High': return Colors.redAccent;
      default: return AgriAgentTheme.infoBlue;
    }
  }

  Future<void> _detectIrrigation(int plotIndex) async {
    setState(() => _isDetectingIrrigation = true);
    try {
      final plot = _plots[plotIndex];
      final crop = plot.crops.isNotEmpty ? plot.crops.first.toLowerCase().replaceAll(' ', '_') : 'tomato';
      final url = Uri.parse(
        'https://agriagent-backend-385185579211.us-central1.run.app/irrigation/assess/$_location?crop=$crop',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          plot.irrigationLevel = data['level'] as String;
          _irrigationRecommendation = data['recommendation'] as String;
          _irrigationDetails = data;
        });
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L10n.tr(context, 'irrigation_failed')}: $e'),
            backgroundColor: AgriAgentTheme.warningOrange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingIrrigation = false);
      }
    }
  }
}
