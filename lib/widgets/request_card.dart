import 'package:flutter/material.dart';

import '../models/models.dart';
import 'status_badge.dart';

enum RequestCardType { pending, active, history }

/// Karta SOS požadavku — zobrazuje se v dashboardu a historii.
class RequestCard extends StatelessWidget {
  final SosRequest request;
  final RequestCardType type;
  final VoidCallback? onAccept;
  final VoidCallback? onTap;

  const RequestCard({
    super.key,
    required this.request,
    required this.type,
    this.onAccept,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = type == RequestCardType.pending
        ? const Color(0xFFEF4444).withOpacity(0.2)
        : type == RequestCardType.active
            ? const Color(0xFF3B82F6).withOpacity(0.2)
            : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey[200]!);

    final bgColor = type == RequestCardType.pending
        ? const Color(0xFFEF4444).withOpacity(isDark ? 0.04 : 0.02)
        : type == RequestCardType.active
            ? const Color(0xFF3B82F6).withOpacity(isDark ? 0.04 : 0.02)
            : (isDark ? Colors.white.withOpacity(0.02) : Colors.white);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Category + Status + Time
              Row(
                children: [
                  // Category icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _categoryIcon,
                      color: _categoryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Category label + address
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.kategorieLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        if (request.adresa != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            request.adresa!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark ? Colors.white38 : Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status + time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(
                        label: request.status.label,
                        color: _statusColor,
                        isActive: request.status.isActive,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.timeAgo,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white24 : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Description
              if (request.popis != null) ...[
                const SizedBox(height: 10),
                Text(
                  request.popis!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
              ],

              // Coordinates
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 12,
                    color: isDark ? Colors.white24 : Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${request.lat.toStringAsFixed(4)}, ${request.lng.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white24 : Colors.grey[400],
                    ),
                  ),
                  const Spacer(),

                  // Accept button (only for pending)
                  if (type == RequestCardType.pending && onAccept != null)
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        icon:
                            const Icon(Icons.check_rounded, size: 14),
                        label: const Text('Přijmout',
                            style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                  // Arrow for active/history
                  if (type != RequestCardType.pending && onTap != null)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: isDark ? Colors.white24 : Colors.grey[400],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _categoryColor {
    switch (request.kategorie) {
      case 'zamecnik':
        return const Color(0xFFF59E0B); // amber
      case 'odtahovka':
        return const Color(0xFF3B82F6); // blue
      case 'servis':
        return const Color(0xFF8B5CF6); // purple
      case 'instalater':
        return const Color(0xFF06B6D4); // cyan
      default:
        return Colors.grey;
    }
  }

  IconData get _categoryIcon {
    switch (request.kategorie) {
      case 'zamecnik':
        return Icons.key_rounded;
      case 'odtahovka':
        return Icons.local_shipping_rounded;
      case 'servis':
        return Icons.build_rounded;
      case 'instalater':
        return Icons.water_drop_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color get _statusColor {
    switch (request.status) {
      case SosStatus.pending:
        return const Color(0xFFF59E0B);
      case SosStatus.accepted:
        return const Color(0xFF3B82F6);
      case SosStatus.inProgress:
        return const Color(0xFF8B5CF6);
      case SosStatus.completed:
        return const Color(0xFF22C55E);
      case SosStatus.cancelled:
        return Colors.grey;
    }
  }
}
