import 'package:flutter/material.dart';
import '../home/dashboard.dart';
import '../../widgets/main_layout.dart';

class VehicleScreen extends StatelessWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MainLayout(
      radio: radio,
      battery: battery,
      gps: gps,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        child: Column(
          children: [
            Text(
              'Vehicle OBD-II Status',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Gauges and bars in a grid-like layout
            Expanded(
              child: Center(
                child: Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  children: const [
                    _GaugeWidget(
                      label: 'RPM',
                      value: 2150,
                      min: 0,
                      max: 8000,
                      icon: Icons.speed,
                      units: 'rpm',
                    ),
                    _GaugeWidget(
                      label: 'Speed',
                      value: 58,
                      min: 0,
                      max: 160,
                      icon: Icons.directions_car,
                      units: 'mph',
                    ),
                    _BarWidget(
                      label: 'Coolant',
                      value: 190,
                      min: 120,
                      max: 260,
                      icon: Icons.thermostat,
                      units: '°F',
                    ),
                    _BarWidget(
                      label: 'Throttle',
                      value: 34,
                      min: 0,
                      max: 100,
                      icon: Icons.linear_scale,
                      units: '%',
                    ),
                    _BarWidget(
                      label: 'Fuel',
                      value: 62,
                      min: 0,
                      max: 100,
                      icon: Icons.local_gas_station,
                      units: '%',
                    ),
                    _BarWidget(
                      label: 'Battery',
                      value: 13.7,
                      min: 10,
                      max: 15,
                      icon: Icons.battery_full,
                      units: 'V',
                    ),
                    _BarWidget(
                      label: 'Air Temp',
                      value: 72,
                      min: -20,
                      max: 120,
                      icon: Icons.air,
                      units: '°F',
                    ),
                    _BarWidget(
                      label: 'MAF',
                      value: 12.4,
                      min: 0,
                      max: 50,
                      icon: Icons.blur_on,
                      units: 'g/s',
                    ),
                    _BarWidget(
                      label: 'O2 Sensor',
                      value: 0.85,
                      min: 0,
                      max: 1.0,
                      icon: Icons.science,
                      units: 'V',
                    ),
                    _StatusWidget(
                      label: 'DTCs',
                      value: 'None',
                      icon: Icons.warning_amber_outlined,
                      ok: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeWidget extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final IconData icon;
  final String units;

  const _GaugeWidget({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.icon,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 10,
                backgroundColor: theme.colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            ),
            Icon(icon, size: 38, color: theme.colorScheme.primary),
            Positioned(
              bottom: 12,
              child: Text(
                '${value.toStringAsFixed(0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$label (${units})',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BarWidget extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final IconData icon;
  final String units;

  const _BarWidget({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.icon,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 26, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} $units',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 12,
              backgroundColor: theme.colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool ok;

  const _StatusWidget({
    required this.label,
    required this.value,
    required this.icon,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 170,
      child: Row(
        children: [
          Icon(icon, size: 26, color: ok ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ok ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}