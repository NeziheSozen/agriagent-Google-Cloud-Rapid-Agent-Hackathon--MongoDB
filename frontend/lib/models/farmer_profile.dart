/// A single year's crop record for rotation history.
class CropHistoryEntry {
  final int year;
  final String crop;
  final double yieldTonsPerHectare;
  final double profit;
  final String? notes;

  const CropHistoryEntry({
    required this.year,
    required this.crop,
    required this.yieldTonsPerHectare,
    required this.profit,
    this.notes,
  });

  factory CropHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CropHistoryEntry(
      year: json['year'] as int,
      crop: json['crop'] as String,
      yieldTonsPerHectare:
          (json['yield_tons_per_hectare'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'year': year,
        'crop': crop,
        'yield_tons_per_hectare': yieldTonsPerHectare,
        'profit': profit,
        'notes': notes,
      };
}

/// Lab soil test results.
class SoilAnalysis {
  final double ph;
  final double nitrogenPpm;
  final double phosphorusPpm;
  final double potassiumPpm;
  final double organicMatterPercent;
  final double salinityDsM;
  final String texture;
  final String testDate;

  const SoilAnalysis({
    required this.ph,
    required this.nitrogenPpm,
    required this.phosphorusPpm,
    required this.potassiumPpm,
    required this.organicMatterPercent,
    required this.salinityDsM,
    required this.texture,
    required this.testDate,
  });

  factory SoilAnalysis.fromJson(Map<String, dynamic> json) {
    return SoilAnalysis(
      ph: (json['ph'] as num).toDouble(),
      nitrogenPpm: (json['nitrogen_ppm'] as num).toDouble(),
      phosphorusPpm: (json['phosphorus_ppm'] as num).toDouble(),
      potassiumPpm: (json['potassium_ppm'] as num).toDouble(),
      organicMatterPercent:
          (json['organic_matter_percent'] as num).toDouble(),
      salinityDsM: (json['salinity_ds_m'] as num).toDouble(),
      texture: json['texture'] as String,
      testDate: json['test_date'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'ph': ph,
        'nitrogen_ppm': nitrogenPpm,
        'phosphorus_ppm': phosphorusPpm,
        'potassium_ppm': potassiumPpm,
        'organic_matter_percent': organicMatterPercent,
        'salinity_ds_m': salinityDsM,
        'texture': texture,
        'test_date': testDate,
      };
}

/// A specific plot or greenhouse.
class FarmPlot {
  final String plotId;
  final String name;
  final double sizeHectares;
  final String irrigationLevel;
  final String tenureType;
  final SoilAnalysis? soilAnalysis;
  final List<CropHistoryEntry> cropHistory;

  const FarmPlot({
    required this.plotId,
    required this.name,
    required this.sizeHectares,
    required this.irrigationLevel,
    required this.tenureType,
    this.soilAnalysis,
    required this.cropHistory,
  });

  factory FarmPlot.fromJson(Map<String, dynamic> json) {
    return FarmPlot(
      plotId: json['plot_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Ana Tarla',
      sizeHectares: (json['size_hectares'] as num).toDouble(),
      irrigationLevel: json['irrigation_level'] as String? ?? 'Medium',
      tenureType: json['tenure_type'] as String? ?? 'Owned',
      soilAnalysis: json['soil_analysis'] != null
          ? SoilAnalysis.fromJson(json['soil_analysis'] as Map<String, dynamic>)
          : null,
      cropHistory: (json['crop_history'] as List<dynamic>?)
              ?.map((e) => CropHistoryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'plot_id': plotId,
        'name': name,
        'size_hectares': sizeHectares,
        'irrigation_level': irrigationLevel,
        'tenure_type': tenureType,
        'soil_analysis': soilAnalysis?.toJson(),
        'crop_history': cropHistory.map((e) => e.toJson()).toList(),
      };
}

/// Complete farmer profile containing multiple plots.
class FarmerProfile {
  final String userId;
  final String name;
  final String location;
  final String region;
  final int age;
  final String gender;
  final List<String> crops;
  final List<FarmPlot> plots;
  final String createdAt;
  final String? cooperativeId;
  final String? cooperativeName;
  final Map<String, dynamic>? locationGeo;

  const FarmerProfile({
    required this.userId,
    required this.name,
    required this.location,
    required this.region,
    required this.age,
    this.gender = 'Prefer not to say',
    this.crops = const [],
    required this.plots,
    required this.createdAt,
    this.cooperativeId,
    this.cooperativeName,
    this.locationGeo,
  });

  factory FarmerProfile.fromJson(Map<String, dynamic> json) {
    return FarmerProfile(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      region: json['region'] as String,
      age: json['age'] as int? ?? 45,
      gender: json['gender'] as String? ?? 'Prefer not to say',
      crops: (json['crops'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      plots: (json['plots'] as List<dynamic>?)
              ?.map((e) => FarmPlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] as String,
      cooperativeId: json['cooperative_id'] as String?,
      cooperativeName: json['cooperative_name'] as String?,
      locationGeo: json['location_geo'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'location': location,
        'region': region,
        'age': age,
        'gender': gender,
        'crops': crops,
        'plots': plots.map((e) => e.toJson()).toList(),
        'created_at': createdAt,
        'cooperative_id': cooperativeId,
        'cooperative_name': cooperativeName,
        'location_geo': locationGeo,
      };
}
