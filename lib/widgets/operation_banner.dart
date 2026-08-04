import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Inline banner reflecting the current injection/restore operation.
class OperationBanner extends StatelessWidget {
  const OperationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final op = context.watch<AppState>().operation;
    if (!op.running && op.message.isEmpty) return const SizedBox.shrink();

    final running = op.running;
    final color = running
        ? context.appPrimary
        : (op.message.startsWith('Failed') ? context.appError : context.appSuccess);

    return Material(
      color: color.withValues(alpha: running ? 0.10 : 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(running ? Icons.sync : Icons.check_circle,
                  size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  op.message,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!running) ...[
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  color: color,
                  onPressed: () =>
                      context.read<AppState>().dismissOperation(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
