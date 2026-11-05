import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
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
    this.actorName,
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
  final String? actorName;
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
      actorName: row['actor_display_name'] as String?,
      staffName: staff?['full_name'] as String?,
      staffCode: staff?['staff_code'] as String?,
    );
  }
}

class InviteUserResult {
  final bool success;
  final bool emailDispatched;

  const InviteUserResult({
    required this.success,
    required this.emailDispatched,
  });
}

class MeritRepository {
  MeritRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> loadProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('user_id', userId).maybeSingle();
    if (row == null || row['is_active'] != true) {
      throw const MeritRepositoryException('This account has not been activated. Contact the system owner.');
    }
    final user = _client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_data_url'] as String?;
    return {
      ...row,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
    };
  }

  Future<void> updateAvatarDataUrl(String? dataUrl) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'avatar_data_url': dataUrl ?? ''}),
      );
    } on AuthException catch (error) {
      throw MeritRepositoryException(error.message);
    } catch (_) {
      throw const MeritRepositoryException('Profile image could not be saved.');
    }
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
        .select('id, staff_id, actor_display_name, event_type, delta_tenths, score_before_tenths, score_after_tenths, reason, created_at, staff(full_name, staff_code)')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map((row) => MeritEvent.fromMap(row)).toList();
  }

  Future<List<MeritEvent>> loadReportEvents({DateTime? from, DateTime? to}) async {
    final result = <MeritEvent>[];
    var offset = 0;
    const pageSize = 1000;
    while (true) {
      var query = _client
          .from('merit_events')
          .select('id, staff_id, actor_display_name, event_type, delta_tenths, score_before_tenths, score_after_tenths, reason, created_at, staff(full_name, staff_code)');
      if (from != null) query = query.gte('created_at', from.toUtc().toIso8601String());
      if (to != null) query = query.lt('created_at', to.add(const Duration(days: 1)).toUtc().toIso8601String());
      final rows = await query.order('created_at', ascending: false).range(offset, offset + pageSize - 1);
      result.addAll(rows.map((row) => MeritEvent.fromMap(row)));
      if (result.length > 10000) throw const MeritRepositoryException('The report exceeds 10,000 rows. Narrow the date range and try again.');
      if (rows.length < pageSize) return result;
      offset += pageSize;
    }
  }

  Future<List<Map<String, dynamic>>> loadProfiles() async {
    final rows = await _client
        .from('profiles')
        .select('user_id, email, display_name, role, staff_id, is_active, must_set_password, created_at, user_permissions(permission_key)')
        .order('created_at');
    return rows;
  }

  Future<List<Map<String, dynamic>>> loadAuditEvents({int limit = 300}) async {
    final rows = await _client
        .from('audit_events')
        .select('id, actor_id, action, target_type, target_id, metadata, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows;
  }

  Future<Set<String>> loadPermissions(String userId) async {
    final rows = await _client.from('user_permissions').select('permission_key').eq('user_id', userId);
    return rows.map((row) => row['permission_key'] as String).toSet();
  }

  Future<({
    int defaultScoreTenths,
    int? floorTenths,
    int? ceilingTenths,
    String organizationName,
    String scoreUnit,
  })> loadSettings() async {
    final row = await _client.from('organization_settings').select().eq('id', true).single();
    String? localOrgName;
    String? localScoreUnit;
    try {
      final prefs = await SharedPreferences.getInstance();
      localOrgName = prefs.getString('org_settings_name');
      localScoreUnit = prefs.getString('org_settings_unit');
    } catch (_) {}

    final dbOrgName = row['organization_name'] as String?;
    final dbScoreUnit = row['score_unit'] as String?;

    return (
      defaultScoreTenths: row['default_starting_score_tenths'] as int,
      floorTenths: row['floor_tenths'] as int?,
      ceilingTenths: row['ceiling_tenths'] as int?,
      organizationName: localOrgName ?? dbOrgName ?? 'MESRC DEVICE',
      scoreUnit: localScoreUnit ?? dbScoreUnit ?? 'merit',
    );
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
      if (error.code == '23505') throw const MeritRepositoryException('That staff code is already in use.');
      throw const MeritRepositoryException('Staff record could not be saved. Check access and input.');
    }
  }

  Future<int> importStaff(List<Map<String, dynamic>> rows) async {
    try {
      final count = await _client.rpc('import_staff', params: {'rows_input': rows});
      return count as int;
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const MeritRepositoryException('A staff code in the file already exists. No rows were imported.');
      if (error.message.contains('Not authorized')) throw const MeritRepositoryException('This account does not have permission to import CSV.');
      throw const MeritRepositoryException('CSV import failed. Check for duplicate rows, merit values, and score limits.');
    }
  }

  Future<void> updateStaff(StaffMember staff, {required String code, required String name, String? department}) async {
    try {
      await _client.rpc('update_staff', params: {
        'target_staff_id': staff.id,
        'staff_code_input': code.trim(),
        'full_name_input': name.trim(),
        'department_input': department?.trim(),
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const MeritRepositoryException('That staff code is already in use.');
      throw const MeritRepositoryException('Staff record could not be updated. Check permissions and input.');
    }
  }

  Future<void> setStaffArchived(String staffId, bool archived) async {
    try {
      await _client.rpc('set_staff_archived', params: {'target_staff_id': staffId, 'archived_input': archived});
    } on PostgrestException {
      throw const MeritRepositoryException('Staff status could not be updated.');
    }
  }

  Future<void> deleteStaff(String staffId) async {
    try {
      await _client.rpc('delete_staff', params: {'target_staff_id': staffId});
    } on PostgrestException {
      try {
        await _client.rpc('delete_staff_without_history', params: {'target_staff_id': staffId});
      } on PostgrestException {
        throw const MeritRepositoryException('Staff record could not be deleted.');
      }
    }
  }

  Future<void> deleteStaffWithoutHistory(String staffId) async => deleteStaff(staffId);

  Future<void> correctMerit({required String staffId, required int scoreTenths, required String reason}) async {
    try {
      await _client.rpc('correct_merit', params: {
        'target_staff_id': staffId,
        'new_score_tenths': scoreTenths,
        'reason_input': reason.trim(),
        'request_id_input': _uuidV4(),
      });
    } on PostgrestException catch (error) {
      if (error.message.contains('minimum')) throw const MeritRepositoryException('The corrected score is below the configured minimum.');
      if (error.message.contains('maximum')) throw const MeritRepositoryException('The corrected score exceeds the configured maximum.');
      throw const MeritRepositoryException('Correction could not be saved. Check permissions and values.');
    }
  }

  Future<void> updateSettings({
    required int defaultScoreTenths,
    int? floorTenths,
    int? ceilingTenths,
    String? organizationName,
    String? scoreUnit,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (organizationName != null && organizationName.trim().isNotEmpty) {
        await prefs.setString('org_settings_name', organizationName.trim());
      }
      if (scoreUnit != null && scoreUnit.trim().isNotEmpty) {
        await prefs.setString('org_settings_unit', scoreUnit.trim());
      }
    } catch (_) {}

    try {
      await _client.rpc('update_organization_settings_v2', params: {
        'default_score_input': defaultScoreTenths,
        'floor_input': floorTenths,
        'ceiling_input': ceilingTenths,
        'org_name_input': organizationName ?? 'MESRC DEVICE',
        'score_unit_input': scoreUnit ?? 'merit',
      });
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' ||
          error.message.contains('update_organization_settings_v2') ||
          error.message.contains('not find') ||
          error.message.contains('does not exist') ||
          error.message.contains('function')) {
        await _client.rpc('update_organization_settings', params: {
          'default_score_input': defaultScoreTenths,
          'floor_input': floorTenths,
          'ceiling_input': ceilingTenths,
        });
        try {
          await _client.from('organization_settings').update({
            if (organizationName != null && organizationName.trim().isNotEmpty) 'organization_name': organizationName.trim(),
            if (scoreUnit != null && scoreUnit.trim().isNotEmpty) 'score_unit': scoreUnit.trim(),
          }).eq('id', true);
        } catch (_) {}
        return;
      }
      if (error.message.contains('minimum')) throw const MeritRepositoryException('The default score must be at or above the minimum.');
      if (error.message.contains('maximum')) throw const MeritRepositoryException('The default score must be at or below the maximum.');
      throw const MeritRepositoryException('Merit settings could not be saved. Check values and permissions.');
    }
  }

  Future<void> setUserPermissions(String userId, Set<String> permissionKeys) async {
    try {
      await _client.rpc('set_user_permissions', params: {
        'target_user_id': userId,
        'permission_keys_input': permissionKeys.toList(),
      });
    } on PostgrestException {
      throw const MeritRepositoryException('User permissions could not be updated.');
    }
  }

  Future<void> setUserActive(String userId, bool active) async {
    try {
      await _client.rpc('set_user_active', params: {'target_user_id': userId, 'active_input': active});
    } on PostgrestException {
      throw const MeritRepositoryException('Account status could not be updated.');
    }
  }

  Future<void> recordReportExport({DateTime? from, DateTime? to, required int rows}) async {
    await _client.rpc('record_report_export', params: {
      'from_input': from?.toUtc().toIso8601String(),
      'to_input': to?.add(const Duration(days: 1)).toUtc().toIso8601String(),
      'rows_input': rows,
    });
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
        throw const MeritRepositoryException('This adjustment would go below the configured minimum.');
      }
      if (message.contains('above the configured maximum')) {
        throw const MeritRepositoryException('This adjustment would exceed the configured maximum.');
      }
      if (message.contains('Not authorized')) throw const MeritRepositoryException('This account does not have permission to adjust merit.');
      throw const MeritRepositoryException('Merit adjustment could not be saved. Refresh the data and try again.');
    }
  }

  Future<InviteUserResult> inviteUser({
    required String email,
    String? displayName,
    required String role,
    String? staffId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : (role == 'ceo' ? 'CEO' : (role == 'admin' ? 'Admin' : cleanEmail.split('@').first));

    bool rpcSuccess = false;
    // 1. Try direct database RPC first (fast, reliable, zero edge-function CORS issues)
    try {
      await _client.rpc('invite_user_direct', params: {
        'email_input': cleanEmail,
        'display_name_input': cleanName,
        'role_input': role,
        'staff_id_input': staffId,
      });
      rpcSuccess = true;
    } on PostgrestException catch (error) {
      final msg = error.message.toLowerCase();
      if (!msg.contains('invite_user_direct') && !msg.contains('does not exist') && error.code != 'PGRST202') {
        throw MeritRepositoryException(error.message);
      }
      // RPC not yet applied on remote database, fall back to Edge Function
    }

    // 2. Fall back to Edge Function if deployed and RPC was not present
    if (!rpcSuccess) {
      try {
        await _client.functions.invoke('invite-user', body: {
          'email': cleanEmail,
          'display_name': cleanName,
          'role': role,
          'staff_id': staffId,
        });
      } on FunctionException catch (error) {
        final details = error.details;
        if (details is Map && details['error'] is String) {
          throw MeritRepositoryException(details['error'] as String);
        }
        throw const MeritRepositoryException(
          'Invitation failed. Please run migration 20261105030000_fix_invited_user_identities.sql in Supabase SQL Editor.',
        );
      } catch (_) {
        throw const MeritRepositoryException(
          'Invitation service not ready: Please run migration 20261105030000_fix_invited_user_identities.sql in Supabase SQL Editor.',
        );
      }
    }

    // 3. Dispatch the login verification code email via Supabase SMTP (exact same as login page)
    var emailDispatched = false;
    try {
      await _client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: false,
      );
      emailDispatched = true;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('rate limit') || e.statusCode == '429') {
        emailDispatched = true;
      } else {
        try {
          await _client.auth.signInWithOtp(
            email: cleanEmail,
            shouldCreateUser: true,
          );
          emailDispatched = true;
        } catch (_) {
          emailDispatched = false;
        }
      }
    } catch (_) {
      emailDispatched = false;
    }

    return InviteUserResult(
      success: true,
      emailDispatched: emailDispatched,
    );
  }

  Future<void> resendLoginEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      await _client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: false,
      );
    } on AuthException catch (error) {
      if (error.message.toLowerCase().contains('rate limit') || error.statusCode == '429') {
        throw const MeritRepositoryException('Hourly email rate limit reached. Please wait a bit before resending.');
      }
      throw MeritRepositoryException(error.message);
    } catch (_) {
      throw const MeritRepositoryException('Failed to send invitation email. Check SMTP settings in Supabase.');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _client.rpc('delete_user_account', params: {
        'target_user_id': userId,
      });
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' || error.message.contains('delete_user_account') || error.message.contains('does not exist')) {
        try {
          await _client.from('user_permissions').delete().eq('user_id', userId);
          await _client.from('profiles').delete().eq('user_id', userId);
          return;
        } catch (_) {}
      }
      throw MeritRepositoryException(error.message);
    } catch (_) {
      throw const MeritRepositoryException('Failed to delete user account. Check permissions and try again.');
    }
  }

  Future<void> updateMyDisplayName(String newName) async {
    final clean = newName.trim();
    if (clean.isEmpty) throw const MeritRepositoryException('Name cannot be empty.');
    try {
      await _client.rpc('update_my_profile_name', params: {
        'display_name_input': clean,
      });
      return;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' || error.message.contains('update_my_profile_name') || error.message.contains('does not exist')) {
        final userId = _client.auth.currentUser?.id;
        if (userId != null) {
          await _client.from('profiles').update({'display_name': clean}).eq('user_id', userId);
          return;
        }
      }
      throw MeritRepositoryException(error.message);
    } catch (_) {
      throw const MeritRepositoryException('Failed to update display name. Try again.');
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
