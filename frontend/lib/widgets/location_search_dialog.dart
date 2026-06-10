import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../app/theme.dart';
import '../app/l10n/translations.dart';

/// Result from the location search dialog.
typedef LocationResult = ({String location, String region});

/// A full-screen dialog that provides location search with autocomplete
/// using OpenStreetMap Nominatim API.
class LocationSearchDialog extends StatefulWidget {
  final String currentLocation;

  const LocationSearchDialog({super.key, required this.currentLocation});

  /// Show the dialog and return the selected location + region, or null if cancelled.
  static Future<LocationResult?> show(BuildContext context, String currentLocation) {
    return showDialog<LocationResult>(
      context: context,
      builder: (_) => LocationSearchDialog(currentLocation: currentLocation),
    );
  }

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<_PlaceResult> _results = [];
  bool _isLoading = false;
  _PlaceResult? _selectedPlace;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.currentLocation;
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  final _dio = Dio();

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '6',
          'accept-language': Localizations.localeOf(context).languageCode,
        },
        options: Options(headers: {'User-Agent': 'AgriAgent-App/1.0'}),
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data as List;
        setState(() {
          _results = data.map((item) => _PlaceResult.fromJson(item as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520, maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AgriAgentTheme.mossGreen, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    L10n.tr(context, 'edit_location'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Search Field ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: L10n.tr(context, 'search_location_hint'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = [];
                              _selectedPlace = null;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AgriAgentTheme.mossGreen.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Results ─────────────────────────────────────────────────
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AgriAgentTheme.mossGreen,
                        ),
                      ),
                    )
                  : _results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.travel_explore_rounded,
                                size: 40,
                                color: colorScheme.onSurface.withOpacity(0.15),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                L10n.tr(context, 'search_location_desc'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (_, i) {
                            final place = _results[i];
                            final isSelected =
                                _selectedPlace?.shortLabel == place.shortLabel;
                            return _PlaceCard(
                              place: place,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedPlace = place;
                                  _controller.text = place.shortLabel;
                                });
                              },
                            );
                          },
                        ),
            ),

            // ── Actions ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(L10n.tr(context, 'cancel')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedPlace != null
                        ? () => Navigator.pop(context, (
                              location: _selectedPlace!.shortLabel,
                              region: _selectedPlace!.state ?? _selectedPlace!.country ?? '',
                            ))
                        : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(L10n.tr(context, 'save')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AgriAgentTheme.mossGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AgriAgentTheme.mossGreen.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceResult {
  final String displayName;
  final String type;
  final String? city;
  final String? state;
  final String? country;
  final double lat;
  final double lon;

  _PlaceResult({
    required this.displayName,
    required this.type,
    this.city,
    this.state,
    this.country,
    required this.lat,
    required this.lon,
  });

  factory _PlaceResult.fromJson(Map<String, dynamic> json) {
    final addr = json['address'] as Map<String, dynamic>? ?? {};
    return _PlaceResult(
      displayName: json['display_name'] ?? '',
      type: json['type'] ?? '',
      city: addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'],
      state: addr['state'],
      country: addr['country'],
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      lon: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
    );
  }

  /// Short label like "Tekirdağ, Turkey"
  String get shortLabel {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (state != null && state != city) parts.add(state!);
    if (country != null) parts.add(country!);
    if (parts.isEmpty) return displayName;
    return parts.join(', ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Place Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceCard extends StatelessWidget {
  final _PlaceResult place;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.place,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _typeIcon {
    switch (place.type) {
      case 'city':
      case 'town':
        return Icons.location_city_rounded;
      case 'village':
      case 'hamlet':
        return Icons.house_rounded;
      case 'administrative':
      case 'state':
        return Icons.map_rounded;
      case 'country':
        return Icons.flag_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? AgriAgentTheme.mossGreen.withOpacity(0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AgriAgentTheme.mossGreen.withOpacity(0.15)
                      : colorScheme.surfaceContainerHighest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _typeIcon,
                  size: 18,
                  color: isSelected
                      ? AgriAgentTheme.mossGreen
                      : colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.shortLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AgriAgentTheme.mossGreen
                            : colorScheme.onSurface,
                      ),
                    ),
                    if (place.displayName != place.shortLabel)
                      Text(
                        place.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: AgriAgentTheme.mossGreen, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
