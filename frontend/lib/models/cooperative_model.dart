/// A machine registered in a cooperative fleet.
class CoopMachine {
  final String machineId;
  final String name;
  final String type; // seeder, harvester, sprayer, tractor
  final String ownerId;
  final String ownerName;
  final bool shared;
  final double dailyRentalCost;
  final String status; // active, maintenance, retired

  const CoopMachine({
    required this.machineId,
    required this.name,
    required this.type,
    required this.ownerId,
    required this.ownerName,
    required this.shared,
    required this.dailyRentalCost,
    required this.status,
  });

  factory CoopMachine.fromJson(Map<String, dynamic> json) {
    return CoopMachine(
      machineId: json['machine_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'tractor',
      ownerId: json['owner_id'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
      shared: json['shared'] as bool? ?? false,
      dailyRentalCost: (json['daily_rental_cost'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'machine_id': machineId,
        'name': name,
        'type': type,
        'owner_id': ownerId,
        'owner_name': ownerName,
        'shared': shared,
        'daily_rental_cost': dailyRentalCost,
        'status': status,
      };
}

/// A cooperative or sharing network that farmers belong to.
class Cooperative {
  final String coopId;
  final String name;
  final String region;
  final String description;
  final String coopType; // official, collective
  final List<String> memberIds;
  final List<CoopMachine> machines;
  final String adminId;
  final String joinCode;
  final DateTime createdAt;

  const Cooperative({
    required this.coopId,
    required this.name,
    required this.region,
    required this.description,
    required this.coopType,
    required this.memberIds,
    required this.machines,
    required this.adminId,
    required this.joinCode,
    required this.createdAt,
  });

  factory Cooperative.fromJson(Map<String, dynamic> json) {
    return Cooperative(
      coopId: json['coop_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coopType: json['coop_type'] as String? ?? 'collective',
      memberIds: (json['member_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      machines: (json['machines'] as List<dynamic>?)
              ?.map((e) => CoopMachine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      adminId: json['admin_id'] as String? ?? '',
      joinCode: json['join_code'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'coop_id': coopId,
        'name': name,
        'region': region,
        'description': description,
        'coop_type': coopType,
        'member_ids': memberIds,
        'machines': machines.map((e) => e.toJson()).toList(),
        'admin_id': adminId,
        'join_code': joinCode,
        'created_at': createdAt.toIso8601String(),
      };
}
