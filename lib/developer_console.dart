import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'game/developer_scenarios.dart';
import 'game/table_data.dart';

/// Compact phone-friendly test controls above the running Flame playfield.
/// These use callbacks so new scenarios can be added without rebuilding the UI.
class PinballDeveloperConsole extends StatelessWidget {
  const PinballDeveloperConsole({
    super.key,
    required this.accent,
    required this.currentTable,
    required this.collisionOverlayVisible,
    required this.scoreNotSaved,
    required this.eventFeed,
    required this.onScenario,
    required this.onStepFrame,
    required this.onClearEvents,
    required this.onOverlayChanged,
    required this.onTableSelected,
    required this.onClose,
  });

  final Color accent;
  final PinballTableId currentTable;
  final bool collisionOverlayVisible;
  final bool scoreNotSaved;
  final ValueListenable<List<String>> eventFeed;
  final ValueChanged<PinballDeveloperScenario> onScenario;
  final VoidCallback onStepFrame;
  final VoidCallback onClearEvents;
  final ValueChanged<bool> onOverlayChanged;
  final ValueChanged<PinballTableId> onTableSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xF5050B16),
    elevation: 12,
    borderRadius: BorderRadius.circular(13),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: 0.85)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.science_outlined, color: accent, size: 20),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'DEVELOPER • LIVE TEST',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close developer controls',
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
            const Text(
              'Scenarios reuse the running game. Launch buttons reset the round.',
              style: TextStyle(fontSize: 10, color: Color(0xFFB2C4D5)),
            ),
            if (scoreNotSaved)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'DEV SESSION • SCORE NOT SAVED',
                  style: TextStyle(
                    color: Color(0xFFFFD378),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: <Widget>[
                for (final scenario in PinballDeveloperScenario.values)
                  SizedBox(
                    width: 139,
                    child: OutlinedButton(
                      onPressed: () => onScenario(scenario),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: accent.withValues(alpha: 0.46)),
                      ),
                      child: Text(
                        scenario.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onStepFrame,
                    icon: const Icon(Icons.skip_next, size: 16),
                    label: const Text('STEP PAUSED FRAME'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: onClearEvents,
                  child: const Text('CLEAR LOG', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const Text(
              'LIVE PHYSICS CONTACTS (newest first)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: Color(0xFFB8CCE0),
              ),
            ),
            ValueListenableBuilder<List<String>>(
              valueListenable: eventFeed,
              builder: (context, events, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final event in events.reversed.take(4))
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        event,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF83ECD6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (events.isEmpty)
                    const Text(
                      'Run a test to capture contacts and exits.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF91A4B6)),
                    ),
                ],
              ),
            ),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Show wall / bumper / flipper hitboxes',
                style: TextStyle(fontSize: 11),
              ),
              value: collisionOverlayVisible,
              onChanged: onOverlayChanged,
            ),
            Row(
              children: <Widget>[
                const Text('TABLE', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButton<PinballTableId>(
                    value: currentTable,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                    items: <DropdownMenuItem<PinballTableId>>[
                      for (final table in pinballTables)
                        DropdownMenuItem<PinballTableId>(
                          value: table.id,
                          child: Text(
                            table.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null && id != currentTable) {
                        onTableSelected(id);
                      }
                    },
                  ),
                ),
              ],
            ),
            const Text(
              'Test tools are diagnostic; they do not prove real touch accuracy.',
              style: TextStyle(fontSize: 10, color: Color(0xFF9BAEBF)),
            ),
          ],
        ),
      ),
    ),
  );
}
