import 'package:flutter/material.dart';
import '../../core/l10n/app_strings.dart';
import 'vehicles_screen.dart';
import 'drivers_screen.dart';

/// Section 5.2 "إدارة الأسطول": segmented view over vehicles and drivers.
class FleetScreen extends StatefulWidget {
  const FleetScreen({super.key});

  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(tr(context, 'vehicles')), icon: const Icon(Icons.local_shipping)),
              ButtonSegment(value: 1, label: Text(tr(context, 'drivers')), icon: const Icon(Icons.badge)),
            ],
            selected: {_segment},
            onSelectionChanged: (s) => setState(() => _segment = s.first),
          ),
        ),
        Expanded(child: _segment == 0 ? const VehiclesScreen() : const DriversScreen()),
      ],
    );
  }
}
