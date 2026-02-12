import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/dayflow/planner/planning_item.dart';
import '../../state/user_state.dart';
import '../result.dart';
import '../supabase/auth_helpers.dart';
import '../supabase/supabase_parsers.dart';

class DayPlanSnapshot {
  final Map<String, DayPlanBlock> blocks;
  final List<PlanningItem> items;
  final Set<String> completedItemIds;
  final List<String> blockOrder;

  const DayPlanSnapshot({
    required this.blocks,
    required this.items,
    required this.completedItemIds,
    required this.blockOrder,
  });
}

class DayPlanRepository {
  DayPlanRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  Future<Result<DayPlanSnapshot>> fetchDayPlan(DateTime day) async {
    final uid = requireUser(_client);
    if (uid == null) {
      return Result.ok(
        const DayPlanSnapshot(
          blocks: {},
          items: [],
          completedItemIds: {},
          blockOrder: [],
        ),
      );
    }
    try {
      final dayKey = _dateKey(day);
      final blocksResponse = await _client
          .from('day_plan_blocks')
          .select(
              'block_id,outcome,method_ids,done_method_ids,done')
          .eq('user_id', uid)
          .eq('day', dayKey);
      final itemsResponse = await _client
          .from('day_plan_items')
          .select(
              'item_id,title,description,type,duration_min,priority,area,fixed_start,completed')
          .eq('user_id', uid)
          .eq('day', dayKey);
      final orderResponse = await _client
          .from('day_plan_block_order')
          .select('block_ids')
          .eq('user_id', uid)
          .eq('day', dayKey)
          .maybeSingle();

      final blocksRows =
          (blocksResponse as List).cast<Map<String, dynamic>>();
      final itemsRows =
          (itemsResponse as List).cast<Map<String, dynamic>>();
      final blocks = <String, DayPlanBlock>{};
      for (final row in blocksRows) {
        final blockId = parseString(row['block_id']);
        if (blockId.isEmpty) continue;
        blocks[blockId] = DayPlanBlock(
          blockId: blockId,
          outcome: row['outcome']?.toString(),
          methodIds: parseList(row['method_ids']),
          doneMethodIds: parseList(row['done_method_ids']),
          done: parseBool(row['done']),
        );
      }
      final items = <PlanningItem>[];
      final completed = <String>{};
      for (final row in itemsRows) {
        final itemId = parseString(row['item_id']);
        if (itemId.isEmpty) continue;
        final type = _typeFromDb(row['type']);
        final fixedStart = row['fixed_start'] == null
            ? null
            : parseDateTime(row['fixed_start']);
        items.add(
          PlanningItem(
            id: itemId,
            title: parseString(row['title']),
            description: row['description']?.toString(),
            type: type,
            durationMin: parseInt(row['duration_min']),
            priority: parseInt(row['priority'], fallback: 2),
            area: row['area']?.toString(),
            fixedStart: fixedStart,
          ),
        );
        if (parseBool(row['completed'])) completed.add(itemId);
      }
      final blockOrder = orderResponse == null
          ? const <String>[]
          : parseList(orderResponse['block_ids']);
      return Result.ok(
        DayPlanSnapshot(
          blocks: blocks,
          items: items,
          completedItemIds: completed,
          blockOrder: blockOrder,
        ),
      );
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'day_plan fetch failed', cause: e));
    }
  }

  Future<Result<void>> upsertDayPlanBlock(
    DateTime day,
    DayPlanBlock block,
  ) async {
    final uid = requireUser(_client);
    if (uid == null) return Result.ok(null);
    try {
      await _client.from('day_plan_blocks').upsert(
        {
          'user_id': uid,
          'day': _dateKey(day),
          'block_id': block.blockId,
          'outcome': block.outcome,
          'method_ids': block.methodIds,
          'done_method_ids': block.doneMethodIds,
          'done': block.done,
        },
        onConflict: 'user_id,day,block_id',
      );
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'day_plan upsert failed', cause: e));
    }
  }

  Future<Result<void>> deleteDayPlanForDate(DateTime day) async {
    final uid = requireUser(_client);
    if (uid == null) return Result.ok(null);
    try {
      final dayKey = _dateKey(day);
      await _client
          .from('day_plan_blocks')
          .delete()
          .eq('user_id', uid)
          .eq('day', dayKey);
      await _client
          .from('day_plan_items')
          .delete()
          .eq('user_id', uid)
          .eq('day', dayKey);
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'day_plan delete failed', cause: e));
    }
  }

  Future<Result<void>> deleteDayPlanBlock(
    DateTime day,
    String blockId,
  ) async {
    final uid = requireUser(_client);
    if (uid == null) return Result.ok(null);
    try {
      await _client
          .from('day_plan_blocks')
          .delete()
          .eq('user_id', uid)
          .eq('day', _dateKey(day))
          .eq('block_id', blockId);
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'day_plan block delete failed', cause: e));
    }
  }

  Future<Result<void>> upsertPlanningItem(
    DateTime day,
    PlanningItem item, {
    required bool completed,
  }) async {
    final uid = requireUser(_client);
    if (uid == null) return Result.ok(null);
    try {
      await _client.from('day_plan_items').upsert(
        {
          'user_id': uid,
          'day': _dateKey(day),
          'item_id': item.id,
          'title': item.title,
          'description': item.description,
          'type': item.type.name,
          'duration_min': item.durationMin,
          'priority': item.priority,
          'area': item.area,
          'fixed_start': item.fixedStart?.toIso8601String(),
          'completed': completed,
        },
        onConflict: 'user_id,day,item_id',
      );
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'day_plan item upsert failed', cause: e));
    }
  }

  Future<Result<void>> deletePlanningItem(DateTime day, String itemId) async {
    final uid = requireUser(_client);
    if (uid == null) return Result.ok(null);
    try {
      await _client
          .from('day_plan_items')
          .delete()
          .eq('user_id', uid)
          .eq('day', _dateKey(day))
          .eq('item_id', itemId);
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'day_plan item delete failed', cause: e));
    }
  }

  Future<Result<void>> upsertDayBlockOrder(
    DateTime day,
    List<String> blockIds,
  ) async {
    final uid = requireUser(_client);
    if (uid == null) return Result.ok(null);
    try {
      await _client.from('day_plan_block_order').upsert(
        {
          'user_id': uid,
          'day': _dateKey(day),
          'block_ids': blockIds,
        },
        onConflict: 'user_id,day',
      );
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'block order upsert failed', cause: e));
    }
  }

  Future<Result<void>> deleteDayBlockOrder(DateTime day) async {
    final uid = requireUser(_client);
    if (uid == null) return Result.ok(null);
    try {
      await _client
          .from('day_plan_block_order')
          .delete()
          .eq('user_id', uid)
          .eq('day', _dateKey(day));
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'block order delete failed', cause: e));
    }
  }

  Future<Result<void>> setPlanningItemCompleted(
    DateTime day,
    String itemId,
    bool completed,
  ) async {
    final uid = requireUser(_client);
    if (uid == null) return Result.ok(null);
    try {
      await _client
          .from('day_plan_items')
          .update({'completed': completed})
          .eq('user_id', uid)
          .eq('day', _dateKey(day))
          .eq('item_id', itemId);
      return Result.ok(null);
    } on PostgrestException catch (e) {
      return Result.fail(_toError(e));
    } catch (e) {
      return Result.fail(DataError(message: 'day_plan item update failed', cause: e));
    }
  }

  PlanningType _typeFromDb(dynamic value) {
    final raw = value?.toString().toLowerCase().trim() ?? '';
    switch (raw) {
      case 'appointment':
      case 'termin':
        return PlanningType.appointment;
      case 'personal':
        return PlanningType.personal;
      default:
        return PlanningType.todo;
    }
  }

  DataError _toError(PostgrestException e) {
    return DataError(
      message: e.message,
      details: e.details?.toString(),
      hint: e.hint?.toString(),
      code: e.code?.toString(),
    );
  }

  String _dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split('T').first;
  }
}

