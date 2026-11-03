import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/merit_repository.dart';
import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    required this.repository,
    required this.staff,
    required this.canExport,
    super.key,
  });
  final MeritRepository repository;
  final List<StaffMember> staff;
  final bool canExport;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTime _from;
  late DateTime _to;
  final _search = TextEditingController();
  final Set<String> _selectedStaffIds = {};
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
    for (final s in widget.staff.where((s) => !s.archived)) {
      _selectedStaffIds.add(s.id);
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant ReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedStaffIds.isEmpty && widget.staff.isNotEmpty) {
      for (final s in widget.staff.where((s) => !s.archived)) {
        _selectedStaffIds.add(s.id);
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.repository.loadReportEvents(from: _from, to: _to);
      if (mounted) {
        setState(() {
          _events = events;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Report could not be loaded.';
          _loading = false;
        });
      }
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
    setState(() {
      if (start) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    await _load();
  }

  List<StaffMember> get _filteredStaff {
    final query = _search.text.trim().toLowerCase();
    return widget.staff.where((s) {
      if (s.archived) return false;
      if (query.isEmpty) return true;
      return '${s.code} ${s.name} ${s.department ?? ''}'.toLowerCase().contains(query);
    }).toList();
  }

  List<StaffMember> get _selectedStaffList =>
      widget.staff.where((s) => _selectedStaffIds.contains(s.id)).toList();

  List<MeritEvent> _eventsForStaff(String staffId) => _events.where((event) {
        if (event.staffId != staffId) return false;
        if (_direction == 'Increase') return event.deltaTenths > 0;
        if (_direction == 'Decrease') return event.deltaTenths < 0;
        return true;
      }).toList();

  void _toggleSelectAll() {
    final activeIds = _filteredStaff.map((s) => s.id).toSet();
    final allSelected = activeIds.isNotEmpty && activeIds.every(_selectedStaffIds.contains);
    setState(() {
      if (allSelected) {
        _selectedStaffIds.removeAll(activeIds);
      } else {
        _selectedStaffIds.addAll(activeIds);
      }
    });
  }

  Future<void> _previewReport({List<StaffMember>? targetStaff}) async {
    final staffList = targetStaff ?? _selectedStaffList;
    if (staffList.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ReportPreviewDialog(
        staffList: staffList,
        eventsByStaff: {
          for (final s in staffList) s.id: _eventsForStaff(s.id),
        },
        from: _from,
        to: _to,
        canExport: widget.canExport,
        onExportPdf: () => _exportPdf(targetStaff: staffList),
      ),
    );
  }

  Future<void> _exportPdf({List<StaffMember>? targetStaff}) async {
    final staffList = targetStaff ?? _selectedStaffList;
    if (staffList.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final doc = pw.Document();
      final totalRows = staffList.fold<int>(0, (sum, s) => sum + _eventsForStaff(s.id).length);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFD9E1EC), width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MESRC MERIT TRACKER — STAFF MERIT REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF1E4FD8),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Period: ${formatDate(_from)} – ${formatDate(_to)}   |   Staff selected: ${staffList.length}',
                      style: const pw.TextStyle(fontSize: 9.5, color: PdfColor.fromInt(0xFF53637D)),
                    ),
                  ],
                ),
                pw.Text(
                  'Generated ${formatDate(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF667894)),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF667894)),
            ),
          ),
          build: (context) => [
            for (final staff in staffList) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                margin: const pw.EdgeInsets.only(bottom: 8, top: 8),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF5F8FC),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFD9E1EC)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${staff.name} (${staff.code})',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF141C2E)),
                        ),
                        if (staff.department != null && staff.department!.isNotEmpty)
                          pw.Text(
                            staff.department!,
                            style: const pw.TextStyle(fontSize: 9.5, color: PdfColor.fromInt(0xFF667894)),
                          ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFEAF0FF),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'Current Merit: ${formatMerit(staff.scoreTenths)}',
                        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1E4FD8)),
                      ),
                    ),
                  ],
                ),
              ),
              if (_eventsForStaff(staff.id).isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12, left: 4),
                  child: pw.Text(
                    'No merit changes recorded in this period.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF667894)),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEF3FF)),
                  headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF141C2E)),
                  cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF25334A)),
                  border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE3E9F2), width: 0.5),
                  headers: const ['Date', 'Type', 'Delta', 'Before -> After', 'Reason', 'By'],
                  data: _eventsForStaff(staff.id).map((e) {
                    return [
                      formatDate(e.createdAt),
                      e.type.toUpperCase(),
                      e.type == 'opening' ? formatMerit(e.afterTenths) : formatDelta(e.deltaTenths),
                      e.beforeTenths == null ? '-> ${formatMerit(e.afterTenths)}' : '${formatMerit(e.beforeTenths!)} -> ${formatMerit(e.afterTenths)}',
                      e.reason,
                      e.actorName ?? 'System',
                    ];
                  }).toList(),
                ),
              pw.SizedBox(height: 10),
            ],
          ],
        ),
      );

      final bytes = await doc.save();
      try {
        await widget.repository.recordReportExport(from: _from, to: _to, rows: totalRows);
      } catch (_) {}
      final suffix = staffList.length == 1
          ? staffList.first.code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          : '${staffList.length}-staff';
      await FileSaver.instance.saveFile(
        name: 'merit-report-$suffix-${_from.year}${_from.month.toString().padLeft(2, '0')}',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'pdf',
        mimeType: MimeType.custom,
        customMimeType: 'application/pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF report exported.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF export failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final staffRows = _filteredStaff;
    final allFilteredSelected =
        staffRows.isNotEmpty && staffRows.every((s) => _selectedStaffIds.contains(s.id));

    return ListView(
      padding: EdgeInsets.fromLTRB(
        width < 700 ? 18 : 32,
        18,
        width < 700 ? 18 : 32,
        width < 700 ? 104 + MediaQuery.paddingOf(context).bottom : 30,
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Staff Merit Reports', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text(
                  'Select one or multiple staff to preview or export a formatted PDF report.',
                  style: TextStyle(color: Color(0xFF667894)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _selectedStaffIds.isEmpty || _loading ? null : () => _previewReport(),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text('Preview (${_selectedStaffIds.length})'),
                ),
                if (widget.canExport)
                  FilledButton.icon(
                    onPressed: _selectedStaffIds.isEmpty || _exporting || _loading ? null : () => _exportPdf(),
                    icon: _exporting
                        ? const ThinkingOrbsLoader(size: 18, label: 'Exporting PDF')
                        : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(_exporting ? 'Exporting…' : 'Export PDF (${_selectedStaffIds.length})'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _chooseDate(true),
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text('From  ${formatDate(_from)}'),
            ),
            OutlinedButton.icon(
              onPressed: () => _chooseDate(false),
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text('To  ${formatDate(_to)}'),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _direction,
                decoration: const InputDecoration(labelText: 'Filter', isDense: true),
                items: const ['All', 'Increase', 'Decrease']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _direction = value ?? 'All'),
              ),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Search staff name or code',
                  isDense: true,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: staffRows.isEmpty ? null : _toggleSelectAll,
              icon: Icon(
                allFilteredSelected ? Icons.deselect_outlined : Icons.select_all_outlined,
                size: 18,
              ),
              label: Text(allFilteredSelected ? 'Clear selection' : 'Select all'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: ThinkingOrbsLoader()),
            ),
          )
        else if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            ),
          )
        else if (staffRows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No active staff records found.')),
            ),
          )
        else
          Surface3DCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < staffRows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Color(0xFFEEF2F8)),
                  _buildStaffReportRow(context, staffRows[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStaffReportRow(BuildContext context, StaffMember staff) {
    final selected = _selectedStaffIds.contains(staff.id);
    final events = _eventsForStaff(staff.id);
    final adjustments = events.where((e) => e.type == 'adjustment').toList();
    final netDelta = adjustments.fold<int>(0, (sum, e) => sum + e.deltaTenths);

    return ListTile(
      onTap: () => _previewReport(targetStaff: [staff]),
      leading: Checkbox(
        value: selected,
        onChanged: (value) => setState(() {
          if (value == true) {
            _selectedStaffIds.add(staff.id);
          } else {
            _selectedStaffIds.remove(staff.id);
          }
        }),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              staff.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Merit: ${formatMerit(staff.scoreTenths)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: Color(0xFF245CEB),
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${staff.code}  •  ${staff.department ?? 'No department'}  •  ${adjustments.length} changes (${formatDelta(netDelta)})',
          style: const TextStyle(color: Color(0xFF667894), fontSize: 12),
        ),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'View staff report',
            onPressed: () => _previewReport(targetStaff: [staff]),
            icon: const Icon(Icons.open_in_full_rounded, size: 18),
          ),
          if (widget.canExport)
            IconButton(
              tooltip: 'Export PDF for ${staff.name}',
              onPressed: _exporting ? null : () => _exportPdf(targetStaff: [staff]),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFF245CEB)),
            ),
        ],
      ),
    );
  }
}

class _ReportPreviewDialog extends StatelessWidget {
  const _ReportPreviewDialog({
    required this.staffList,
    required this.eventsByStaff,
    required this.from,
    required this.to,
    required this.canExport,
    required this.onExportPdf,
  });

  final List<StaffMember> staffList;
  final Map<String, List<MeritEvent>> eventsByStaff;
  final DateTime from;
  final DateTime to;
  final bool canExport;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < 700 ? 12 : 28,
        vertical: screen.height < 700 ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1120,
          maxHeight: screen.height * 0.9,
          minWidth: screen.width < 700 ? screen.width - 24 : 720,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE3E9F2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staffList.length == 1
                              ? 'Staff Report — ${staffList.first.name}'
                              : 'Staff Merit Report (${staffList.length} Staff)',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Period: ${formatDate(from)} – ${formatDate(to)}',
                          style: const TextStyle(color: Color(0xFF667894), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  if (canExport)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onExportPdf();
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('Export PDF'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: staffList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (context, index) {
                  final staff = staffList[index];
                  final events = eventsByStaff[staff.id] ?? const [];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE3E9F2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${staff.name} (${staff.code})',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    staff.department ?? 'No department',
                                    style: const TextStyle(color: Color(0xFF667894), fontSize: 12),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF3FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Current Merit: ${formatMerit(staff.scoreTenths)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF245CEB),
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (events.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'No merit events recorded in this period.',
                              style: TextStyle(color: Color(0xFF667894), fontSize: 13),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('DATE')),
                                DataColumn(label: Text('TYPE')),
                                DataColumn(label: Text('CHANGE')),
                                DataColumn(label: Text('BEFORE → AFTER')),
                                DataColumn(label: Text('REASON')),
                                DataColumn(label: Text('BY')),
                              ],
                              rows: events
                                  .map(
                                    (e) => DataRow(
                                      cells: [
                                        DataCell(Text(formatDate(e.createdAt))),
                                        DataCell(Text(e.type.toUpperCase())),
                                        DataCell(
                                          Text(
                                            e.type == 'opening'
                                                ? formatMerit(e.afterTenths)
                                                : formatDelta(e.deltaTenths),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: e.deltaTenths < 0
                                                  ? const Color(0xFFB42318)
                                                  : const Color(0xFF16804A),
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            e.beforeTenths == null
                                                ? '— → ${formatMerit(e.afterTenths)}'
                                                : '${formatMerit(e.beforeTenths!)} → ${formatMerit(e.afterTenths)}',
                                          ),
                                        ),
                                        DataCell(
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 360),
                                            child: Text(e.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ),
                                        ),
                                        DataCell(Text(e.actorName ?? 'System')),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
