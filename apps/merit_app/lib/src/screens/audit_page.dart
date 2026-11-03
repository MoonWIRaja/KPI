import 'package:flutter/material.dart';

import '../data/merit_repository.dart';
import '../widgets/merit_brand.dart';
import '../widgets/thinking_orbs_loader.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({required this.repository, required this.canReadSystemAudit, super.key});
  final MeritRepository repository;
  final bool canReadSystemAudit;

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  List<MeritEvent> _meritEvents = const [];
  List<Map<String, dynamic>> _systemEvents = const [];
  String _filter = 'all'; // 'all', 'merit', 'system'
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final meritEvents = await widget.repository.loadEvents(limit: 200);
      List<Map<String, dynamic>> systemEvents = const [];
      if (widget.canReadSystemAudit) {
        try {
          systemEvents = await widget.repository.loadAuditEvents(limit: 200);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _meritEvents = meritEvents;
          _systemEvents = systemEvents;
        });
      }
    } catch (_) {
      if (mounted) _error = 'Audit log could not be loaded.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
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
                Text('Audit Log', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text(
                  'Unified merit activity and system audit history.',
                  style: TextStyle(color: Color(0xFF667894)),
                ),
              ],
            ),
            if (widget.canReadSystemAudit)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'merit', label: Text('Merit')),
                  ButtonSegment(value: 'system', label: Text('System')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
          ],
        ),
        const SizedBox(height: 18),
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
              padding: const EdgeInsets.all(18),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
            ),
          )
        else
          _buildUnifiedList(context),
      ],
    );
  }

  Widget _buildUnifiedList(BuildContext context) {
    final items = <_AuditListItem>[];
    if (_filter == 'all' || _filter == 'merit') {
      for (final e in _meritEvents) {
        items.add(_AuditListItem(timestamp: e.createdAt, meritEvent: e));
      }
    }
    if ((_filter == 'all' || _filter == 'system') && widget.canReadSystemAudit) {
      for (final s in _systemEvents) {
        final action = s['action'] as String? ?? '';
        // Skip duplicate merit.adjust / staff.create entries when viewing 'all'
        if (_filter == 'all' && (action == 'merit.adjust' || action == 'merit.correct' || action == 'staff.create')) {
          continue;
        }
        items.add(
          _AuditListItem(
            timestamp: DateTime.tryParse(s['created_at'] as String? ?? '') ?? DateTime.now(),
            systemEvent: s,
          ),
        );
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No audit activity recorded yet.')),
        ),
      );
    }

    return Surface3DCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEEF2F8)),
            _buildRow(context, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, _AuditListItem item) {
    final merit = item.meritEvent;
    if (merit != null) {
      final positive = merit.deltaTenths >= 0;
      final isOpening = merit.type == 'opening';
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isOpening
              ? const Color(0xFFEEF3FF)
              : positive
                  ? const Color(0xFFE8F7EE)
                  : const Color(0xFFFFEEEE),
          child: Icon(
            isOpening
                ? Icons.flag_outlined
                : positive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
            color: isOpening
                ? const Color(0xFF245CEB)
                : positive
                    ? const Color(0xFF16804A)
                    : const Color(0xFFB42318),
            size: 18,
          ),
        ),
        title: Text(
          '${merit.staffName ?? 'Staff'} (${merit.staffCode ?? '—'})  •  ${isOpening ? 'Opening ${formatMerit(merit.afterTenths)}' : formatDelta(merit.deltaTenths)}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        subtitle: Text(
          '${merit.reason}\n${formatDate(merit.createdAt)}${merit.actorName != null ? '  ·  by ${merit.actorName}' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8FC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3E9F2)),
          ),
          child: Text(
            formatMerit(merit.afterTenths),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF141C2E)),
          ),
        ),
      );
    }

    final sys = item.systemEvent!;
    final action = sys['action'] as String? ?? 'system.event';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEEF3FF),
        child: Icon(Icons.shield_outlined, color: Color(0xFF245CEB), size: 18),
      ),
      title: Text(action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
      subtitle: Text(
        '${sys['target_type'] ?? ''}  ·  ${formatDate(item.timestamp)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: 'Details',
        icon: const Icon(Icons.info_outline, size: 18),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(action),
            content: SelectableText((sys['metadata'] ?? const {}).toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditListItem {
  const _AuditListItem({required this.timestamp, this.meritEvent, this.systemEvent});
  final DateTime timestamp;
  final MeritEvent? meritEvent;
  final Map<String, dynamic>? systemEvent;
}
