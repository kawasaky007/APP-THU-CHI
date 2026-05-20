import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/models/models.dart';
import '../../../core/services/supabase_service.dart';

class ProfileRepository {
  ProfileRepository(this._supabaseService);

  final SupabaseService _supabaseService;

  supabase.SupabaseClient get _client => _supabaseService.client;

  Stream<List<UserProfile>> watchProfiles(String householdId) {
    debugPrint('WATCH PROFILES STARTED: $householdId');

    return _client
        .from(SupabaseTables.userProfiles)
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .asyncMap((rows) {
          final deduplicatedRows = _dedupeRowsById(
            rows,
            entityName: 'PROFILES',
          );
          debugPrint('PROFILES REALTIME UPDATE: ${deduplicatedRows.length}');
          return deduplicatedRows.map(UserProfile.fromJson).toList();
        });
  }

  Future<List<UserProfile>> fetchProfiles(String householdId) async {
    final rows = await _client
        .from(SupabaseTables.userProfiles)
        .select()
        .eq('household_id', householdId);

    return rows.map((row) => UserProfile.fromJson(row)).toList();
  }
}

List<Map<String, dynamic>> _dedupeRowsById(
  Iterable<Map<String, dynamic>> rows, {
  required String entityName,
}) {
  final latestRowsById = <String, Map<String, dynamic>>{};
  final rowsWithoutId = <Map<String, dynamic>>[];

  for (final row in rows) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) {
      rowsWithoutId.add(row);
      continue;
    }
    latestRowsById[id] = row;
  }

  final deduplicatedRows = [...latestRowsById.values, ...rowsWithoutId];
  final removed = rows.length - deduplicatedRows.length;
  if (removed > 0) {
    debugPrint('$entityName REALTIME DEDUPED: removed=$removed');
  }
  return deduplicatedRows;
}
