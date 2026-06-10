class FleetScheduleItem {
  final String date;
  final String status;
  final String assignee;
  final String reason;
  final bool isCurrentUser;

  const FleetScheduleItem({
    required this.date,
    required this.status,
    required this.assignee,
    required this.reason,
    required this.isCurrentUser,
  });

  factory FleetScheduleItem.fromJson(Map<String, dynamic> json) {
    return FleetScheduleItem(
      date: json['date'] as String,
      status: json['status'] as String,
      assignee: json['assignee'] as String,
      reason: json['reason'] as String,
      isCurrentUser: json['is_current_user'] as bool,
    );
  }
}

class FleetSchedule {
  final String machine;
  final String region;
  final double synergyDiscountPercent;
  final List<FleetScheduleItem> schedule;

  const FleetSchedule({
    required this.machine,
    required this.region,
    required this.synergyDiscountPercent,
    required this.schedule,
  });

  factory FleetSchedule.fromJson(Map<String, dynamic> json) {
    return FleetSchedule(
      machine: json['machine'] as String,
      region: json['region'] as String,
      synergyDiscountPercent: (json['synergy_discount_percent'] as num).toDouble(),
      schedule: (json['schedule'] as List<dynamic>)
          .map((e) => FleetScheduleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
