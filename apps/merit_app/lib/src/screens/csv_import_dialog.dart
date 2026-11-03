import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/merit_repository.dart';

class CsvImportDialog extends StatefulWidget {
  const CsvImportDialog({required this.repository, super.key});
  final MeritRepository repository;

  @override
  State<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<CsvImportDialog> {
  List<Map<String, dynamic>> _rows = const [];
  List<String> _errors = const [];
  String? _fileName;
  bool _busy = false;
  bool _committed = false;

  Future<void> _chooseFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null) return;
    setState(() { _busy = true; _fileName = file.name; _errors = const []; _rows = const []; });
    try {
      const maxBytes = 2 * 1024 * 1024;
      final size = file.lengthSync() ?? await file.length();
      if (size == null || size > maxBytes) {
        throw const FormatException('Fail CSV mesti lebih kecil daripada 2 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > maxBytes) throw const FormatException('Fail CSV mesti lebih kecil daripada 2 MB.');
      final decoded = Csv().decode(utf8.decode(bytes, allowMalformed: false).replaceFirst('\uFEFF', ''));
      if (decoded.length < 2) throw const FormatException('Fail mesti mengandungi header dan sekurang-kurangnya satu rekod.');
      final headers = decoded.first.map((value) => value.toString().trim().toLowerCase()).toList();
      int column(List<String> aliases) => headers.indexWhere(aliases.contains);
      final codeColumn = column(const ['staff_code', 'code', 'kod_staff']);
      final nameColumn = column(const ['full_name', 'name', 'nama']);
      final departmentColumn = column(const ['department', 'jabatan']);
      final meritColumn = column(const ['starting_merit', 'merit', 'score', 'skor']);
      if (codeColumn < 0 || nameColumn < 0 || meritColumn < 0) {
        throw const FormatException('Header wajib: staff_code, full_name, starting_merit. department pilihan.');
      }
      if (decoded.length - 1 > 500) throw const FormatException('Had import ialah 500 staff bagi satu fail.');

      final parsed = <Map<String, dynamic>>[];
      final issues = <String>[];
      final seen = <String>{};
      for (var index = 1; index < decoded.length; index++) {
        final row = decoded[index];
        if (row.every((cell) => cell.toString().trim().isEmpty)) continue;
        String cell(int position) => position < row.length ? row[position].toString().trim() : '';
        final code = cell(codeColumn);
        final name = cell(nameColumn);
        final merit = parseScoreTenths(cell(meritColumn));
        final line = index + 1;
        if (code.isEmpty || code.length > 40) issues.add('Baris $line: kod staff wajib, maksimum 40 aksara.');
        if (name.isEmpty || name.length > 160) issues.add('Baris $line: nama wajib, maksimum 160 aksara.');
        if (merit == null) issues.add('Baris $line: merit mesti nombor dengan maksimum satu perpuluhan.');
        if (code.isNotEmpty && !seen.add(code.toLowerCase())) issues.add('Baris $line: kod staff berulang dalam fail.');
        if (code.isNotEmpty && name.isNotEmpty && merit != null) {
          parsed.add({
            'staff_code': code,
            'full_name': name,
            'department': departmentColumn < 0 ? null : cell(departmentColumn),
            'starting_score_tenths': merit,
          });
        }
      }
      if (parsed.isEmpty && issues.isEmpty) issues.add('Tiada rekod staff ditemui.');
      if (!mounted) return;
      setState(() { _rows = parsed; _errors = issues; });
    } on FormatException catch (error) {
      if (mounted) setState(() => _errors = [error.message]);
    } catch (_) {
      if (mounted) setState(() => _errors = const ['Fail tidak dapat dibaca sebagai CSV UTF-8 yang sah.']);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final count = await widget.repository.importStaff(_rows);
      if (!mounted) return;
      setState(() { _committed = true; _busy = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count rekod staff berjaya diimport.')));
      Navigator.of(context).pop(true);
    } on MeritRepositoryException catch (error) {
      if (mounted) setState(() { _errors = [error.message]; _busy = false; });
    } catch (_) {
      if (mounted) setState(() { _errors = const ['Import gagal. Tiada rekod diubah. Cuba semula selepas menyemak data.']; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Import staff daripada CSV'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              const Text('CSV UTF-8 • maksimum 2 MB dan 500 staff. Kod staff pendua akan membatalkan keseluruhan import.'),
              const SizedBox(height: 10),
              const SelectableText('staff_code,full_name,department,starting_merit\nS001,Nama Staff,Operasi,5.0'),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _busy ? null : _chooseFile, icon: const Icon(Icons.upload_file_outlined), label: Text(_fileName ?? 'Pilih fail CSV')),
              if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${_rows.length} baris sah untuk preview', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._rows.take(5).map((row) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${row['staff_code']} • ${row['full_name']}'), subtitle: Text('${row['department'] ?? 'Tanpa jabatan'}  ·  merit ${formatMerit(row['starting_score_tenths'] as int)}'))),
                if (_rows.length > 5) Text('dan ${_rows.length - 5} lagi', style: const TextStyle(color: Color(0xFF667894))),
              ],
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _errors.take(8).map((issue) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(issue, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12)))).toList())),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy || _committed ? null : () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: _busy || _rows.isEmpty || _errors.isNotEmpty ? null : _import, child: const Text('Sahkan import')),
        ],
      );
}
