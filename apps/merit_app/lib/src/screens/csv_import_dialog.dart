import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/merit_repository.dart';
import '../widgets/thinking_orbs_loader.dart';

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
        throw const FormatException('The CSV file must be smaller than 2 MB.');
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > maxBytes) throw const FormatException('The CSV file must be smaller than 2 MB.');
      final decoded = Csv().decode(utf8.decode(bytes, allowMalformed: false).replaceFirst('\uFEFF', ''));
      if (decoded.length < 2) throw const FormatException('The file must contain a header and at least one record.');
      final headers = decoded.first.map((value) => value.toString().trim().toLowerCase()).toList();
      int column(List<String> aliases) => headers.indexWhere(aliases.contains);
      final codeColumn = column(const ['staff_code', 'code']);
      final nameColumn = column(const ['full_name', 'name']);
      final departmentColumn = column(const ['department']);
      final meritColumn = column(const ['starting_merit', 'merit', 'score']);
      if (codeColumn < 0 || nameColumn < 0 || meritColumn < 0) {
        throw const FormatException('Required headers: staff_code, full_name, starting_merit. department is optional.');
      }
      if (decoded.length - 1 > 500) throw const FormatException('The import limit is 500 staff per file.');

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
        if (code.isEmpty || code.length > 40) issues.add('Row $line: staff code is required (maximum 40 characters).');
        if (name.isEmpty || name.length > 160) issues.add('Row $line: name is required (maximum 160 characters).');
        if (merit == null) issues.add('Row $line: merit must be a number with at most one decimal place.');
        if (code.isNotEmpty && !seen.add(code.toLowerCase())) issues.add('Row $line: duplicate staff code in file.');
        if (code.isNotEmpty && name.isNotEmpty && merit != null) {
          parsed.add({
            'staff_code': code,
            'full_name': name,
            'department': departmentColumn < 0 ? null : cell(departmentColumn),
            'starting_score_tenths': merit,
          });
        }
      }
      if (parsed.isEmpty && issues.isEmpty) issues.add('No staff records found.');
      if (!mounted) return;
      setState(() { _rows = parsed; _errors = issues; });
    } on FormatException catch (error) {
      if (mounted) setState(() => _errors = [error.message]);
    } catch (_) {
      if (mounted) setState(() => _errors = const ['The file is not a valid UTF-8 CSV.']);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count staff records imported successfully.')));
      Navigator.of(context).pop(true);
    } on MeritRepositoryException catch (error) {
      if (mounted) setState(() { _errors = [error.message]; _busy = false; });
    } catch (_) {
      if (mounted) setState(() { _errors = const ['Import failed. No records were changed. Check the data and try again.']; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Import staff from CSV'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              const Text('UTF-8 CSV â€¢ maximum 2 MB and 500 staff. Duplicate staff codes will cancel the entire import.'),
              const SizedBox(height: 10),
              const SelectableText('staff_code,full_name,department,starting_merit\nS001,Staff Name,Operations,5.0'),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _busy ? null : _chooseFile, icon: const Icon(Icons.upload_file_outlined), label: Text(_fileName ?? 'Choose CSV file')),
              if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: ThinkingOrbsLoader(size: 30))),
              if (_rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${_rows.length} valid rows to preview', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._rows.take(5).map((row) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${row['staff_code']} â€¢ ${row['full_name']}'), subtitle: Text('${row['department'] ?? 'No department'}  Â·  merit ${formatMerit(row['starting_score_tenths'] as int)}'))),
                if (_rows.length > 5) Text('and ${_rows.length - 5} more', style: const TextStyle(color: Color(0xFF667894))),
              ],
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _errors.take(8).map((issue) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(issue, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12)))).toList())),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy || _committed ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _busy || _rows.isEmpty || _errors.isNotEmpty ? null : _import, child: const Text('Confirm import')),
        ],
      );
}
