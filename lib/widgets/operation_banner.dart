import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

class OperationBanner extends StatelessWidget {
  const OperationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final op = context.watch<AppState>().operation;
    if (!op.running && op.message.isEmpty) return const SizedBox.shrink();

    final running = op.running;
    final color = running
        ? context.appPrimary
        : (op.message.startsWith('Failed')
            ? context.appError
            : context.appSuccess);
    final hasProgress = running && op.total > 0;
    final fraction = hasProgress ? (op.done / op.total).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: color.withValues(alpha: running ? 0.10 : 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                      running ? Icons.sync : Icons.check_circle,
                      size: 20,
                      color: color),
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
                  if (hasProgress)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${(fraction * 100).round()}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
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
              if (hasProgress) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${op.done} / ${op.total}',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
