import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/merit_repository.dart';
import '../widgets/app_modal.dart';
import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    required this.repository,
    required this.staff,
    required this.canExport,
    this.organizationName = 'MESRC DEVICE',
    this.scoreUnit = 'merit',
    super.key,
  });
  final MeritRepository repository;
  final List<StaffMember> staff;
  final bool canExport;
  final String organizationName;
  final String scoreUnit;

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
    _load();
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

  Future<void> _openFilterModal() async {
    await showAppModal(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AppModalCard(
          maxWidth: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter Reports',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('DATE RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF667894))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _from,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() {});
                          setState(() => _from = picked);
                          await _load();
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 15),
                      label: Text('From: ${formatDate(_from)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _to,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() {});
                          setState(() => _to = picked);
                          await _load();
                        }
                      },
                      icon: const Icon(Icons.event_outlined, size: 15),
                      label: Text('To: ${formatDate(_to)}', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('${widget.scoreUnit.toUpperCase()} MOVEMENT', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF667894))),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('All')),
                  ButtonSegment(value: 'Increase', label: Text('Increase (+)')),
                  ButtonSegment(value: 'Decrease', label: Text('Decrease (-)')),
                ],
                selected: {_direction},
                onSelectionChanged: (selected) {
                  setModalState(() {});
                  setState(() => _direction = selected.first);
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
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
    await showAppModal<void>(
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
        scoreUnit: widget.scoreUnit,
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
                      '${widget.organizationName.toUpperCase()} — STAFF ${widget.scoreUnit.toUpperCase()} REPORT',
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
                        'Current ${widget.scoreUnit}: ${formatMerit(staff.scoreTenths)}',
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
                    'No ${widget.scoreUnit} changes recorded in this period.',
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
    final isMobile = width < 700;

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 14 : 24, 14, isMobile ? 14 : 24, 18),
      child: Surface3DCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isMobile) ...[
              // Modern compact mobile toolbar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: 'Search staff name or code',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: _search.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setState(() => _search.clear()),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Filters & date range',
                    onPressed: _openFilterModal,
                    icon: Badge(
                      isLabelVisible: _direction != 'All',
                      child: const Icon(Icons.tune_rounded, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _openFilterModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF3FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD0E1FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF245CEB)),
                          const SizedBox(width: 6),
                          Text(
                            '${formatDate(_from)} – ${formatDate(_to)}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF245CEB)),
                          ),
                          if (_direction != 'All') ...[
                            const SizedBox(width: 6),
                            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF245CEB), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(
                              _direction,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF245CEB)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: staffRows.isEmpty ? null : _toggleSelectAll,
                    icon: Icon(
                      allFilteredSelected ? Icons.deselect_outlined : Icons.select_all_outlined,
                      size: 16,
                    ),
                    label: Text(allFilteredSelected ? 'Clear' : 'Select all', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 8,
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
                        width: 145,
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
                        width: 220,
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
            ],
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: ThinkingOrbsLoader())
                  : _error != null
                      ? Center(
                          child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
                        )
                      : staffRows.isEmpty
                          ? const Center(child: Text('No active staff records found.'))
                          : ListView.builder(
                              itemCount: staffRows.length,
                              itemBuilder: (context, index) => _buildStaffReportRow(context, staffRows[index]),
                            ),
            ),
            if (isMobile && _selectedStaffIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : () => _previewReport(),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: Text('Preview (${_selectedStaffIds.length})', style: const TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    if (widget.canExport) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exporting || _loading ? null : () => _exportPdf(),
                          icon: _exporting
                              ? const ThinkingOrbsLoader(size: 16, label: 'Exporting PDF')
                              : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: Text(_exporting ? 'Exporting…' : 'Export (${_selectedStaffIds.length})', style: const TextStyle(fontSize: 12.5)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStaffReportRow(BuildContext context, StaffMember staff) {
    final selected = _selectedStaffIds.contains(staff.id);
    final events = _eventsForStaff(staff.id);
    final adjustments = events.where((e) => e.type == 'adjustment').toList();
    final netDelta = adjustments.fold<int>(0, (sum, e) => sum + e.deltaTenths);
    final isMobile = MediaQuery.sizeOf(context).width < 650;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Surface3DCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 12,
        interactive: true,
        onTap: () => _previewReport(targetStaff: [staff]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: selected,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) => setState(() {
                if (value == true) {
                  _selectedStaffIds.add(staff.id);
                } else {
                  _selectedStaffIds.remove(staff.id);
                }
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          staff.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF141C2E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF3FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD6E3FF)),
                        ),
                        child: Text(
                          '${formatMerit(staff.scoreTenths)} ${widget.scoreUnit}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF245CEB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${staff.code}  •  ${staff.department ?? 'No department'}',
                          style: const TextStyle(color: Color(0xFF667894), fontSize: 11.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: netDelta > 0
                              ? const Color(0xFFE8F7EE)
                              : netDelta < 0
                                  ? const Color(0xFFFFEEEE)
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${adjustments.length} changes (${formatDelta(netDelta)})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: netDelta > 0
                                ? const Color(0xFF16804A)
                                : netDelta < 0
                                    ? const Color(0xFFB42318)
                                    : const Color(0xFF667894),
                          ),
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'View staff report',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _previewReport(targetStaff: [staff]),
                          icon: const Icon(Icons.open_in_full_rounded, size: 16),
                        ),
                        if (widget.canExport)
                          IconButton(
                            tooltip: 'Export PDF for ${staff.name}',
                            visualDensity: VisualDensity.compact,
                            onPressed: _exporting ? null : () => _exportPdf(targetStaff: [staff]),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFF245CEB)),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
    this.scoreUnit = 'merit',
  });

  final List<StaffMember> staffList;
  final Map<String, List<MeritEvent>> eventsByStaff;
  final DateTime from;
  final DateTime to;
  final bool canExport;
  final VoidCallback onExportPdf;
  final String scoreUnit;

  @override
  Widget build(BuildContext context) {
    return AppModalCard(
      maxWidth: 1120,
      scrollable: false,
      padding: EdgeInsets.zero,
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
                              : 'Staff $scoreUnit Report (${staffList.length} Staff)',
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
                                  'Current $scoreUnit: ${formatMerit(staff.scoreTenths)}',
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
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(
                              'No $scoreUnit events recorded in this period.',
                              style: const TextStyle(color: Color(0xFF667894), fontSize: 13),
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
      );
  }
}
