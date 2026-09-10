import 'package:flutter/material.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

/// One selectable entity (a carrier, a driver, a vehicle) in an admin picker.
class PickerOption {
  const PickerOption({required this.id, required this.label, this.subtitle});

  final String id;
  final String label;
  final String? subtitle;
}

/// A searchable dropdown over a backend collection.
///
/// The admin assignment dialogs used to expose bare `TextField`s in which the
/// operator had to type a raw MongoDB ObjectId — unusable in practice. This
/// loads the real records and lets them pick by name.
class EntityPicker extends StatefulWidget {
  const EntityPicker({
    super.key,
    required this.label,
    required this.loader,
    required this.value,
    required this.onChanged,
    this.emptyMessage,
    this.enabled = true,
  });

  final String label;
  final Future<List<PickerOption>> Function() loader;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? emptyMessage;
  final bool enabled;

  @override
  State<EntityPicker> createState() => _EntityPickerState();
}

class _EntityPickerState extends State<EntityPicker> {
  late Future<List<PickerOption>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  void didUpdateWidget(covariant EntityPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The driver list depends on the selected carrier, so reload when the
    // parent swaps the loader in.
    if (oldWidget.enabled != widget.enabled && widget.enabled) {
      _future = widget.loader();
    }
  }

  /// Lets a parent force a refresh (e.g. after the carrier selection changes).
  void reload() => setState(() => _future = widget.loader());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PickerOption>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return InputDecorator(
            decoration: InputDecoration(labelText: widget.label),
            child: Row(
              children: [
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(tr(context, 'loading'),
                    style: const TextStyle(color: AppColors.acier, fontSize: 13)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return InputDecorator(
            decoration: InputDecoration(labelText: widget.label),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: AppColors.halte, fontSize: 12.5),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: reload,
                  tooltip: tr(context, 'retry'),
                ),
              ],
            ),
          );
        }

        final options = snapshot.data ?? const <PickerOption>[];
        if (options.isEmpty) {
          return InputDecorator(
            decoration: InputDecoration(labelText: widget.label),
            child: Text(
              widget.emptyMessage ?? tr(context, 'no_results'),
              style: const TextStyle(color: AppColors.acier, fontSize: 13),
            ),
          );
        }

        // Guard against a stale selection that is no longer in the list.
        final value = options.any((o) => o.id == widget.value) ? widget.value : null;

        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: widget.label),
          items: options
              .map(
                (o) => DropdownMenuItem(
                  value: o.id,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.label, overflow: TextOverflow.ellipsis, maxLines: 1),
                      if (o.subtitle != null)
                        Text(
                          o.subtitle!,
                          style: const TextStyle(color: AppColors.acier, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: widget.enabled ? widget.onChanged : null,
        );
      },
    );
  }
}

/// Shared loaders for the admin pickers.
class AdminLookups {
  AdminLookups._();

  static Future<List<PickerOption>> carriers() async {
    final res = await ApiClient.instance.get('/users/carriers');
    return (res.data as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      final rating = (m['rating'] as num?)?.toDouble() ?? 0;
      final count = m['ratingCount'] ?? 0;
      return PickerOption(
        id: m['_id'],
        label: m['companyName'] ?? m['fullName'] ?? m['phone'] ?? '-',
        subtitle: [
          m['phone'],
          if (count > 0) '★ ${rating.toStringAsFixed(1)}',
        ].whereType<String>().join('  ·  '),
      );
    }).toList();
  }

  static Future<List<PickerOption>> driversOf(String carrierId) async {
    final res = await ApiClient.instance.get('/users/carriers/$carrierId/drivers');
    return (res.data as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      return PickerOption(
        id: m['_id'],
        label: m['fullName'] ?? m['phone'] ?? '-',
        subtitle: m['phone'],
      );
    }).toList();
  }

  static Future<List<PickerOption>> vehiclesOf(String carrierId) async {
    final res = await ApiClient.instance.get('/vehicles/mine', query: {'carrierId': carrierId});
    return (res.data as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      final brand = [m['brand'], m['model']].whereType<String>().join(' ').trim();
      return PickerOption(
        id: m['_id'],
        label: m['plateNumber'] ?? '-',
        subtitle: brand.isEmpty ? m['type'] : '$brand  ·  ${m['type'] ?? ''}',
      );
    }).toList();
  }
}
