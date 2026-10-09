import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_controller.dart';
import '../l10n/app_text.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/patient_scaffold.dart';

class VitalsHistoryScreen extends StatefulWidget {
  const VitalsHistoryScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<VitalsHistoryScreen> createState() => _VitalsHistoryScreenState();
}

class _VitalsHistoryScreenState extends State<VitalsHistoryScreen> {
  static const _pageSize = 10;
  final _items = <VitalHistoryEntry>[];
  int _days = 30;
  bool _oldest = false;
  bool _loading = true, _loadingMore = false, _hasMore = false;
  String? _error, _moreError;
  int? _expanded;
  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
      _expanded = null;
      _items.clear();
    });
    try {
      final p = await widget.controller.fetchVitalsHistory(
        limit: _pageSize,
        days: _days,
        oldest: _oldest,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(p.items);
        _hasMore = p.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'error';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final p = await widget.controller.fetchVitalsHistory(
        limit: _pageSize,
        offset: _items.length,
        days: _days,
        oldest: _oldest,
      );
      if (!mounted) return;
      final seen = _items.map((e) => e.visitId).toSet();
      setState(() {
        _items.addAll(p.items.where((e) => seen.add(e.visitId)));
        _hasMore = p.hasMore;
        _loadingMore = false;
        _moreError = null;
      });
    } catch (_) {
      if (mounted) setState(() => _moreError = 'error');
    } finally {
      if (mounted && _loadingMore) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final t = AppText.of(c);
    return PatientScaffold(
      title: t(T.vitalsHistoryTitle),
      controller: widget.controller,
      body: _loading
          ? Center(child: Text(t(T.vitalsHistoryLoading)))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t(T.vitalsHistoryError)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadInitial,
                    child: Text(t(T.tryAgain)),
                  ),
                ],
              ),
            )
          : _body(c, t),
    );
  }

  Widget _body(BuildContext c, AppText t) {
    final groups = <String, List<VitalHistoryEntry>>{};
    for (final e in _items) {
      final d = DateTime.tryParse(e.visitDate ?? '');
      final k = d == null
          ? 'Other'
          : DateFormat.yMMMM(
              Localizations.localeOf(c).toString(),
            ).format(d).toUpperCase();
      groups.putIfAbsent(k, () => []).add(e);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          t(T.vitalsHistoryHint),
          style: TextStyle(color: c.saathiColors.textMuted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _rangePicker(c)),
            const SizedBox(width: 8),
            Expanded(child: _sortPicker(c)),
          ],
        ),
        const SizedBox(height: 12),
        if (_items.isEmpty)
          Center(child: Text(t(T.vitalsHistoryEmpty)))
        else
          ...groups.entries.expand(
            (g) => [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 5),
                child: Text(
                  g.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: c.saathiColors.textMuted,
                  ),
                ),
              ),
              ...g.value.map(
                (e) => _Card(
                  entry: e,
                  expanded: _expanded == e.visitId,
                  onTap: () => setState(
                    () => _expanded = _expanded == e.visitId ? null : e.visitId,
                  ),
                ),
              ),
            ],
          ),
        if (_hasMore || _moreError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                if (_moreError != null)
                  Text(
                    t(T.vitalsHistoryError),
                    style: TextStyle(color: c.saathiColors.emergency),
                  ),
                OutlinedButton.icon(
                  onPressed: _loadingMore ? null : _loadMore,
                  icon: _loadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(
                    _loadingMore
                        ? 'Loading older visits…'
                        : 'Load Older Visits',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rangePicker(BuildContext c) => DropdownButtonFormField<int>(
    initialValue: _days,
    decoration: const InputDecoration(isDense: true),
    items: const [
      DropdownMenuItem(value: 7, child: Text('Last 7 Days')),
      DropdownMenuItem(value: 30, child: Text('Last 30 Days')),
      DropdownMenuItem(value: 90, child: Text('Last 3 Months')),
      DropdownMenuItem(value: 180, child: Text('Last 6 Months')),
      DropdownMenuItem(value: 0, child: Text('All History')),
    ],
    onChanged: (v) {
      if (v != null && v != _days) {
        setState(() => _days = v);
        _loadInitial();
      }
    },
  );
  Widget _sortPicker(BuildContext c) => DropdownButtonFormField<bool>(
    initialValue: _oldest,
    decoration: const InputDecoration(isDense: true),
    items: const [
      DropdownMenuItem(value: false, child: Text('Newest First')),
      DropdownMenuItem(value: true, child: Text('Oldest First')),
    ],
    onChanged: (v) {
      if (v != null && v != _oldest) {
        setState(() => _oldest = v);
        _loadInitial();
      }
    },
  );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.entry,
    required this.expanded,
    required this.onTap,
  });
  final VitalHistoryEntry entry;
  final bool expanded;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) {
    final t = AppText.of(c);
    final col = c.saathiColors;
    final v = [
      (T.healthHeartRate, entry.pulse, 'bpm'),
      (T.healthBloodPressure, entry.bloodPressure, 'mmHg'),
      (T.healthOxygen, entry.spo2, '%'),
      (T.healthTemperature, entry.temperature, '°C'),
      (T.healthWeight, entry.weight, 'kg'),
      (T.healthHeight, entry.height, 'cm'),
    ];
    String value((T, String?, String) x) => x.$2?.trim().isNotEmpty == true
        ? '${x.$2} ${x.$3}'
        : t(T.healthNotRecorded);
    return Card(
      color: col.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: col.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.visitDate ?? '',
                style: TextStyle(fontWeight: FontWeight.w800, color: col.text),
              ),
              if (entry.doctorName?.isNotEmpty == true)
                Text(
                  'Dr. ${entry.doctorName}',
                  style: TextStyle(color: col.textMuted),
                ),
              const SizedBox(height: 7),
              Row(
                children: v
                    .take(3)
                    .map(
                      (x) => Expanded(
                        child: Text(
                          '${t(x.$1)}\n${value(x)}',
                          style: TextStyle(fontSize: 12, color: col.textMuted),
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (expanded) ...[
                const Divider(),
                ...v.map(
                  (x) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          t(x.$1),
                          style: TextStyle(color: col.textMuted),
                        ),
                      ),
                      Text(
                        value(x),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: col.text,
                        ),
                      ),
                    ],
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
