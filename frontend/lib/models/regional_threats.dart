/// A single pest/disease/weather threat alert.
class ThreatAlert {
  final String threatName;
  final String? threatNameTr;
  final String? localThreatName;
  final String threatType;
  final List<String> affectedCrops;
  final String severity;
  final String sourceLocation;
  final String reportedDate;
  final double spreadRiskToNeighbors;
  final String description;
  final String? descriptionTr;
  final String? localDescription;
  final String? imageUrl;

  const ThreatAlert({
    required this.threatName,
    this.threatNameTr,
    this.localThreatName,
    required this.threatType,
    required this.affectedCrops,
    required this.severity,
    required this.sourceLocation,
    required this.reportedDate,
    required this.spreadRiskToNeighbors,
    required this.description,
    this.descriptionTr,
    this.localDescription,
    this.imageUrl,
  });

  factory ThreatAlert.fromJson(Map<String, dynamic> json) {
    return ThreatAlert(
      threatName: json['threat_name'] as String,
      threatNameTr: json['threat_name_tr'] as String?,
      localThreatName: json['local_threat_name'] as String?,
      threatType: json['threat_type'] as String,
      affectedCrops: (json['affected_crops'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      severity: json['severity'] as String,
      sourceLocation: json['source_location'] as String,
      reportedDate: json['reported_date'] as String,
      spreadRiskToNeighbors:
          (json['spread_risk_to_neighbors'] as num).toDouble(),
      description: json['description'] as String,
      descriptionTr: json['description_tr'] as String?,
      localDescription: json['local_description'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'threat_name': threatName,
        'threat_name_tr': threatNameTr,
        'local_threat_name': localThreatName,
        'threat_type': threatType,
        'affected_crops': affectedCrops,
        'severity': severity,
        'source_location': sourceLocation,
        'reported_date': reportedDate,
        'spread_risk_to_neighbors': spreadRiskToNeighbors,
        'description': description,
        'description_tr': descriptionTr,
        'local_description': localDescription,
        'image_url': imageUrl,
      };
}

/// Regional threat overview for a specific region.
class RegionalThreats {
  final String region;
  final String queryDate;
  final List<ThreatAlert> activeThreats;
  final String overallRiskLevel;
  final String advisory;

  const RegionalThreats({
    required this.region,
    required this.queryDate,
    required this.activeThreats,
    required this.overallRiskLevel,
    required this.advisory,
  });

  factory RegionalThreats.fromJson(Map<String, dynamic> json) {
    return RegionalThreats(
      region: json['region'] as String,
      queryDate: json['query_date'] as String,
      activeThreats: (json['active_threats'] as List<dynamic>)
          .map((e) => ThreatAlert.fromJson(e as Map<String, dynamic>))
          .toList(),
      overallRiskLevel: json['overall_risk_level'] as String,
      advisory: json['advisory'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'region': region,
        'query_date': queryDate,
        'active_threats': activeThreats.map((e) => e.toJson()).toList(),
        'overall_risk_level': overallRiskLevel,
        'advisory': advisory,
      };
}
