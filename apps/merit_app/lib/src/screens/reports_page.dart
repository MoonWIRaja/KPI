import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../data/merit_repository.dart';
import '../widgets/thinking_orbs_loader.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.repository, required this.canExport, super.key});
  final MeritRepository repository;
  final bool canExport;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTime _from;
  late DateTime _to;
  List<MeritEvent> _events = const [];
  String _direction = 'All';
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
    _to = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final events = await widget.repository.loadReportEvents(from: _from, to: _to);
      if (mounted) setState(() { _events = events; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Report could not be loaded. Check your permissions and connection.'; _loading = false; });
    }
  }

  Future<void> _chooseDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() { if (start) { _from = picked; } else { _to = picked; } });
    await _load();
  }

  List<MeritEvent> get _visibleEvents => _events.where((event) {
        if (_direction == 'Increase') return event.deltaTenths > 0;
        if (_direction == 'Decrease') return event.deltaTenths < 0;
        return true;
      }).toList();

  String _safeCell(String value) => RegExp(r'^[=+\-@\t\r]').hasMatch(value) ? "'$value" : value;

  Future<void> _export() async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Export staff data?'),
      content: const Text('The file includes staff names, merit changes, and recorded reasons. Store it in an approved location and do not share it with unauthorized people.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Export CSV'))],
    ));
    if (confirmed != true) return;
    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        ['Timestamp (UTC)', 'Staff code', 'Staff name', 'Event', 'Change', 'Before', 'After', 'Reason', 'Updated by'],
        ..._visibleEvents.map((event) => [
          event.createdAt.toUtc().toIso8601String(),
          _safeCell(event.staffCode ?? ''),
          _safeCell(event.staffName ?? ''),
          event.type,
          formatDelta(event.deltaTenths),
          event.beforeTenths == null ? '' : formatMerit(event.beforeTenths!),
          formatMerit(event.afterTenths),
          _safeCell(event.reason),
          _safeCell(event.actorName ?? 'Unknown account'),
        ]),
      ];
      final csv = Csv().encode(rows);
      await widget.repository.recordReportExport(from: _from, to: _to, rows: _visibleEvents.length);
      await FileSaver.instance.saveFile(
        name: 'merit-report-${_from.year}${_from.month.toString().padLeft(2, '0')}-${_to.year}${_to.month.toString().padLeft(2, '0')}',
        bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
        fileExtension: 'csv',
        mimeType: MimeType.custom,
        customMimeType: 'text/csv; charset=utf-8',
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV report exported and recorded.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed. Check your permissions or try again.')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final changes = _visibleEvents.where((event) => event.type == 'adjustment').toList();
    final total = changes.fold<int>(0, (sum, event) => sum + event.deltaTenths);
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
        padding: EdgeInsets.fromLTRB(width < 700 ? 18 : 32, 18, width < 700 ? 18 : 32, 30),
      children: [
        Wrap(runSpacing: 8, alignment: WrapAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Merit reports', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 4), const Text('Review reasons for merit increases and decreases within a selected period.', style: TextStyle(color: Color(0xFF667894)))]), if (widget.canExport) OutlinedButton.icon(onPressed: _exporting || _loading ? null : _export, icon: _exporting ? const ThinkingOrbsLoader(size: 18, label: 'Exporting report') : const Icon(Icons.download_outlined), label: Text(_exporting ? 'Exporting…' : 'Export CSV'))]),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(onPressed: () => _chooseDate(true), icon: const Icon(Icons.calendar_today_outlined, size: 16), label: Text('From  ${formatDate(_from)}')),
          OutlinedButton.icon(onPressed: () => _chooseDate(false), icon: const Icon(Icons.event_outlined, size: 16), label: Text('To  ${formatDate(_to)}')),
          SizedBox(width: 170, child: DropdownButtonFormField<String>(initialValue: _direction, decoration: const InputDecoration(labelText: 'Change type', isDense: true), items: const ['All', 'Increase', 'Decrease'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _direction = value ?? 'All'))),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _SummaryCard(label: 'CHANGES', value: '${changes.length}', icon: Icons.swap_vert),
          _SummaryCard(label: 'INCREASES', value: '${changes.where((event) => event.deltaTenths > 0).length}', icon: Icons.trending_up),
          _SummaryCard(label: 'DECREASES', value: '${changes.where((event) => event.deltaTenths < 0).length}', icon: Icons.trending_down),
          _SummaryCard(label: 'NET CHANGE', value: formatDelta(total), icon: Icons.account_balance_outlined),
        ]),
        const SizedBox(height: 16),
        if (_loading) const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: ThinkingOrbsLoader())))
        else if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318)))))
        else if (_visibleEvents.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No records match this date range and filter.'))))
        else Card(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columns: const [DataColumn(label: Text('DATE')), DataColumn(label: Text('STAFF')), DataColumn(label: Text('CHANGE')), DataColumn(label: Text('REASON')), DataColumn(label: Text('BEFORE → AFTER')), DataColumn(label: Text('RECORDED BY'))],
          rows: _visibleEvents.map((event) => DataRow(cells: [
            DataCell(Text(formatDate(event.createdAt))),
            DataCell(Text('${event.staffCode ?? '—'}  ${event.staffName ?? ''}')),
            DataCell(Text(event.type == 'opening' ? 'Starting score ${formatMerit(event.afterTenths)}' : formatDelta(event.deltaTenths), style: TextStyle(color: event.deltaTenths < 0 ? const Color(0xFFB42318) : const Color(0xFF16804A), fontWeight: FontWeight.w700))),
            DataCell(SizedBox(width: 300, child: Text(event.reason, maxLines: 2, overflow: TextOverflow.ellipsis))),
            DataCell(Text(event.beforeTenths == null ? '— → ${formatMerit(event.afterTenths)}' : '${formatMerit(event.beforeTenths!)} → ${formatMerit(event.afterTenths)}')),
            DataCell(Text(event.actorName ?? 'Unknown account')),
          ])).toList(),
        ))),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: 170, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon, color: const Color(0xFF245CEB)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, letterSpacing: .4, color: Color(0xFF667894), fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))]))]))));
}
