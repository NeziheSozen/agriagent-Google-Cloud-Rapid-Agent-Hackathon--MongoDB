import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/l10n/translations.dart';
import '../app/theme.dart';
import '../models/fleet_schedule.dart';
import '../providers/fleet_provider.dart';
import '../providers/cooperative_provider.dart';
import '../providers/farmer_provider.dart';
import 'glass_card.dart';

class FleetCalendarCard extends ConsumerWidget {
  const FleetCalendarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleetAsync = ref.watch(fleetProvider);

    return fleetAsync.when(
      data: (fleet) {
        if (fleet == null) return const SizedBox.shrink();
        
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AgriAgentTheme.infoBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.agriculture_rounded,
                            color: AgriAgentTheme.infoBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr(context, 'rental_calendar'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                fleet.machine,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AgriAgentTheme.successGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      L10n.tr(context, 'coop_discount').replaceAll('%s', fleet.synergyDiscountPercent.toStringAsFixed(0)),
                      style: const TextStyle(
                        color: AgriAgentTheme.successGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Timeline items
              ...fleet.schedule.map((item) {
                final isMe = item.isCurrentUser;
                final isAvailable = item.status.toLowerCase() == 'available';
                final color = isMe
                    ? AgriAgentTheme.mossGreen
                    : isAvailable
                        ? AgriAgentTheme.infoBlue
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.3);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Icon(
                            isMe
                                ? Icons.check_circle_rounded
                                : isAvailable
                                    ? Icons.radio_button_unchecked
                                    : Icons.circle_outlined,
                            color: color,
                            size: 16,
                          ),
                          if (item != fleet.schedule.last)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 2,
                              height: 30,
                              color: color.withOpacity(0.3),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.date,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isMe ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.assignee,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: color,
                                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
                                      ),
                                    ),
                                    // Show "Kirala" button for available slots
                                    if (isAvailable) ...[
                                      const SizedBox(width: 8),
                                      _BookButton(
                                        item: item,
                                        fleet: fleet,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.reason,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

/// Small "Kirala" booking button shown on available days.
class _BookButton extends ConsumerStatefulWidget {
  final FleetScheduleItem item;
  final FleetSchedule fleet;

  const _BookButton({required this.item, required this.fleet});

  @override
  ConsumerState<_BookButton> createState() => _BookButtonState();
}

class _BookButtonState extends ConsumerState<_BookButton> {
  bool _isBooking = false;

  Future<void> _handleBook() async {
    // Check if farmer has a cooperative
    final farmer = await ref.read(currentFarmerProvider.future);
    if (farmer.cooperativeId == null || farmer.cooperativeId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
               L10n.tr(context, 'join_coop_to_rent'),
            ),
            backgroundColor: AgriAgentTheme.warningOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isBooking = true);

    try {
      await bookMachine(
        ref,
        machineId: widget.fleet.machine,
        farmerName: farmer.name,
        date: widget.item.date,
        coopId: farmer.cooperativeId!,
      );

      // Refresh fleet data after booking
      ref.invalidate(fleetProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.tr(context, 'booking_success').replaceAll('%s', widget.item.date)),
            backgroundColor: AgriAgentTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L10n.tr(context, 'booking_failed')}: $e'),
            backgroundColor: AgriAgentTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: TextButton(
        onPressed: _isBooking ? null : _handleBook,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          backgroundColor: AgriAgentTheme.mossGreen.withOpacity(0.15),
          foregroundColor: AgriAgentTheme.mossGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: _isBooking
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AgriAgentTheme.mossGreen,
                ),
              )
            : Text(
                L10n.tr(context, 'rent_btn'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
