import 'package:flutter/material.dart';

import '../data/merit_repository.dart';
import '../widgets/thinking_orbs_loader.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({required this.repository, super.key});
  final MeritRepository repository;

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  List<Map<String, dynamic>> _events = const [];
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
      final events = await widget.repository.loadAuditEvents();
      if (mounted) setState(() => _events = events);
    } catch (_) {
      if (mounted) _error = 'Audit log could not be loaded, or your account does not have permission.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 700 ? 18 : 28,
          18,
          MediaQuery.sizeOf(context).width < 700 ? 18 : 28,
          MediaQuery.sizeOf(context).width < 700
              ? 104 + MediaQuery.paddingOf(context).bottom
              : 30,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System audit', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    const Text(
                      'Server-recorded administrative actions and exports.',
                      style: TextStyle(color: Color(0xFF667894)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
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
          else if (_events.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Center(child: Text('There are no audit events yet.')),
              ),
            )
          else
            Card(
              child: Column(
                children: _events
                    .map(
                      (event) => ListTile(
                        leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF245CEB)),
                        title: Text(event['action'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${event['target_type']}${event['target_id'] == null ? '' : ' Â· ${event['target_id']}'}\n'
                          'Account: ${event['actor_id'] ?? 'Unknown'}  ·  '
                          '${formatDate(DateTime.parse(event['created_at'] as String))}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Audit metadata',
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Audit details'),
                              content: SelectableText((event['metadata'] ?? const {}).toString()),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                          icon: const Icon(Icons.info_outline),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      );
}
