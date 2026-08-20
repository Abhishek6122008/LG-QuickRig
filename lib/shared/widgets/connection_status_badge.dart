import 'package:flutter/material.dart';

import '../../core/ssh/ssh_client.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_spacing.dart';

class ConnectionStatusBadge extends StatelessWidget {
  final SSHConnectionState state;

  const ConnectionStatusBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // Was Colors.greenAccent/amberAccent — accent swatches are tuned for dark
    // surfaces and this badge sits on a near-white AppBar, which made it the
    // lowest-contrast element in the app.
    final accents = context.accents;
    final (label, color) = switch (state) {
      SSHConnectionState.connected => ('Connected', accents.connected),
      SSHConnectionState.connecting => ('Connecting…', accents.connecting),
      SSHConnectionState.disconnecting =>
        ('Disconnecting…', accents.disconnecting),
      SSHConnectionState.disconnected => ('Disconnected', accents.disconnected),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
