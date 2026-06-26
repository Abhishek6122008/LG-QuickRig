import 'package:flutter/material.dart';

import '../../core/ssh/ssh_client.dart';

class ConnectionStatusBadge extends StatelessWidget {
  final SSHConnectionState state;

  const ConnectionStatusBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SSHConnectionState.connected => ('Connected', Colors.greenAccent),
      SSHConnectionState.connecting => ('Connecting…', Colors.amberAccent),
      SSHConnectionState.disconnecting => ('Disconnecting…', Colors.orange),
      SSHConnectionState.disconnected => ('Disconnected', Colors.redAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(20),
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
