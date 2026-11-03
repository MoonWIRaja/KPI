import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class StaffMember {
  const StaffMember({
    required this.id,
    required this.code,
    required this.name,
    required this.scoreTenths,
    required this.archived,
    this.department,
  });

  final String id;
  final String code;
  final String name;
  final String? department;
  final int scoreTenths;
  final bool archived;

  factory StaffMember.fromMap(Map<String, dynamic> row) => StaffMember(
        id: row['id'] as String,
        code: row['staff_code'] as String,
        name: row['full_name'] as String,
        department: row['department'] as String?,
        scoreTenths: row['current_score_tenths'] as int,
        archived: row['is_archived'] as bool,
      );
}

class MeritEvent {
  const MeritEvent({
    required this.id,
    required this.staffId,
    required this.type,
    required this.deltaTenths,
    required this.beforeTenths,
    required this.afterTenths,
    required this.reason,
    required this.createdAt,
    this.staffName,
    this.staffCode,
  });

  final String id;
  final String staffId;
  final String type;
  final int deltaTenths;
  final int? beforeTenths;
  final int afterTenths;
  final String reason;
  final DateTime createdAt;
  final String? staffName;
  final String? staffCode;

  factory MeritEvent.fromMap(Map<String, dynamic> row) {
    final staff = row['staff'] as Map<String, dynamic>?;
    return MeritEvent(
      id: row['id'] as String,
      staffId: row['staff_id'] as String,
      type: row['event_type'] as String,
      deltaTenths: row['delta_tenths'] as int,
      beforeTenths: row['score_before_tenths'] as int?,
      afterTenths: row['score_after_tenths'] as int,
      reason: row['reason'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      staffName: staff?['full_name'] as String?,
      staffCode: staff?['staff_code'] as String?,
    );
  }
}

class MeritRepository {
  MeritRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> loadProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('user_id', userId).maybeSingle();
    if (row == null || row['is_active'] != true) {
      throw const MeritRepositoryException('Akaun ini belum diaktifkan. Hubungi pemantau sistem.');
    }
    return row;
  }

  Future<List<StaffMember>> loadStaff() async {
    final rows = await _client
        .from('staff')
        .select('id, staff_code, full_name, department, current_score_tenths, is_archived')
        .order('full_name');
    return rows.map((row) => StaffMember.fromMap(row)).toList();
  }

  Future<List<MeritEvent>> loadEvents({int limit = 100}) async {
    final rows = await _client
        .from('merit_events')
        .select('id, staff_id, event_type, delta_tenths, score_before_tenths, score_after_tenths, reason, created_at, staff(full_name, staff_code)')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((row) => MeritEvent.fromMap(row)).toList();
  }

  Future<List<Map<String, dynamic>>> loadProfiles() async {
    final rows = await _client
        .from('profiles')
        .select('user_id, email, display_name, role, staff_id, is_active, created_at')
        .order('created_at');
    return rows;
  }

  Future<int> defaultScoreTenths() async {
    final settings = await _client.from('organization_settings').select('default_starting_score_tenths').eq('id', true).single();
    return settings['default_starting_score_tenths'] as int;
  }

  Future<void> createStaff({
    required String code,
    required String name,
    String? department,
    int? startingScoreTenths,
  }) async {
    try {
      await _client.rpc('create_staff', params: {
        'staff_code_input': code.trim(),
        'full_name_input': name.trim(),
        'department_input': department?.trim(),
        'starting_score_tenths_input': startingScoreTenths,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const MeritRepositoryException('Kod staff itu telah digunakan.');
      throw const MeritRepositoryException('Rekod staff tidak dapat disimpan. Semak akses dan input.');
    }
  }

  Future<void> adjustMerit({
    required String staffId,
    required int deltaTenths,
    required String reason,
  }) async {
    try {
      await _client.rpc('adjust_merit', params: {
        'target_staff_id': staffId,
        'delta_tenths_input': deltaTenths,
        'reason_input': reason.trim(),
        'request_id_input': _uuidV4(),
      });
    } on PostgrestException catch (error) {
      final message = error.message;
      if (message.contains('below the configured minimum')) {
        throw const MeritRepositoryException('Perubahan ini melepasi nilai minimum yang ditetapkan.');
      }
      if (message.contains('above the configured maximum')) {
        throw const MeritRepositoryException('Perubahan ini melepasi nilai maksimum yang ditetapkan.');
      }
      if (message.contains('Not authorized')) throw const MeritRepositoryException('Akaun ini tiada kebenaran untuk mengubah merit.');
      throw const MeritRepositoryException('Perubahan merit tidak dapat disimpan. Segarkan data dan cuba lagi.');
    }
  }

  Future<void> inviteUser({
    required String email,
    required String displayName,
    required String role,
    String? staffId,
  }) async {
    try {
      await _client.functions.invoke('invite-user', body: {
        'email': email.trim(),
        'display_name': displayName.trim(),
        'role': role,
        'staff_id': staffId,
      });
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw MeritRepositoryException(details['error'] as String);
      }
      throw const MeritRepositoryException('Jemputan tidak berjaya. Semak SMTP dan cuba lagi.');
    } catch (_) {
      throw const MeritRepositoryException('Jemputan tidak berjaya. Semak SMTP dan cuba lagi.');
    }
  }
}

class MeritRepositoryException implements Exception {
  const MeritRepositoryException(this.message);
  final String message;
}

String formatMerit(int tenths) => (tenths / 10).toStringAsFixed(1);

int? parseScoreTenths(String input) {
  final match = RegExp(r'^(-?)(\d+)(?:[.,](\d))?$').firstMatch(input.trim());
  if (match == null) return null;
  final whole = int.tryParse(match.group(2)!);
  if (whole == null || whole > 900719925474098) return null;
  final fraction = int.tryParse(match.group(3) ?? '0') ?? 0;
  final value = whole * 10 + fraction;
  return match.group(1) == '-' ? -value : value;
}

String formatDelta(int tenths) {
  final sign = tenths > 0 ? '+' : '';
  return '$sign${formatMerit(tenths)}';
}

String formatDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
