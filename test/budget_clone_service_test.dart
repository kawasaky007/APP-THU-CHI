import 'package:flutter_test/flutter_test.dart';
import 'package:thu_chi_viet_nam/core/models/budget.dart';

/// Tests for the budget clone logic (mirrors BudgetCloneService behavior).
/// Since BudgetCloneService delegates to BudgetRepository which requires
/// Supabase, we test the pure cloning logic in isolation.

void main() {
  group('Budget clone logic', () {
    group('checkBudgetExists', () {
      test('returns false when store has no budgets for month', () {
        final store = <Budget>[];
        final exists = _hasBudgetsForMonth(store, 'h1', 6, 2026);
        expect(exists, false);
      });

      test('returns true when store has budgets for month', () {
        final store = [
          const Budget(
            id: 'b1',
            householdId: 'h1',
            categoryId: 'c1',
            month: 6,
            year: 2026,
            amount: 500000,
          ),
        ];
        final exists = _hasBudgetsForMonth(store, 'h1', 6, 2026);
        expect(exists, true);
      });

      test('returns false for different household', () {
        final store = [
          const Budget(
            id: 'b1',
            householdId: 'h2',
            categoryId: 'c1',
            month: 6,
            year: 2026,
            amount: 500000,
          ),
        ];
        final exists = _hasBudgetsForMonth(store, 'h1', 6, 2026);
        expect(exists, false);
      });
    });

    group('findLatestBudgetMonth', () {
      test('returns null for new user with no budgets', () {
        final store = <Budget>[];
        final result = _findLatestBefore(store, 'h1', 6, 2026);
        expect(result, isNull);
      });

      test('finds the latest month before target', () {
        final store = [
          const Budget(
            id: 'b1', householdId: 'h1', categoryId: 'c1',
            month: 3, year: 2026, amount: 100000,
          ),
          const Budget(
            id: 'b2', householdId: 'h1', categoryId: 'c1',
            month: 5, year: 2026, amount: 200000,
          ),
        ];

        final result = _findLatestBefore(store, 'h1', 6, 2026);
        expect(result, isNotNull);
        expect(result!.month, 5);
        expect(result.year, 2026);
      });

      test('finds latest month across year boundary', () {
        final store = [
          const Budget(
            id: 'b1', householdId: 'h1', categoryId: 'c1',
            month: 11, year: 2025, amount: 100000,
          ),
          const Budget(
            id: 'b2', householdId: 'h1', categoryId: 'c1',
            month: 12, year: 2025, amount: 200000,
          ),
        ];

        final result = _findLatestBefore(store, 'h1', 1, 2026);
        expect(result, isNotNull);
        expect(result!.month, 12);
        expect(result.year, 2025);
      });

      test('does not return months at or after target', () {
        final store = [
          const Budget(
            id: 'b1', householdId: 'h1', categoryId: 'c1',
            month: 6, year: 2026, amount: 100000,
          ),
          const Budget(
            id: 'b2', householdId: 'h1', categoryId: 'c1',
            month: 7, year: 2026, amount: 200000,
          ),
        ];

        final result = _findLatestBefore(store, 'h1', 6, 2026);
        expect(result, isNull);
      });
    });

    group('cloneBudgetMonth', () {
      test('clones budgets with correct target month/year', () {
        final store = [
          const Budget(
            id: 'b1', householdId: 'h1', categoryId: 'c1',
            month: 5, year: 2026, amount: 5000000, displayOrder: 0,
          ),
          const Budget(
            id: 'b2', householdId: 'h1', categoryId: 'c2',
            month: 5, year: 2026, amount: 2000000, displayOrder: 1,
          ),
        ];

        final cloned = _cloneBudgets(
          source: store,
          householdId: 'h1',
          sourceMonth: 5,
          sourceYear: 2026,
          targetMonth: 6,
          targetYear: 2026,
          createdBy: 'user1',
        );

        expect(cloned.length, 2);
        expect(cloned[0].categoryId, 'c1');
        expect(cloned[0].amount, 5000000);
        expect(cloned[0].displayOrder, 0);
        expect(cloned[0].month, 6);
        expect(cloned[0].year, 2026);
        expect(cloned[0].createdBy, 'user1');
        expect(cloned[1].categoryId, 'c2');
        expect(cloned[1].amount, 2000000);
        expect(cloned[1].displayOrder, 1);
      });

      test('does not clone id from source', () {
        final store = [
          const Budget(
            id: 'original-id', householdId: 'h1', categoryId: 'c1',
            month: 5, year: 2026, amount: 1000000, displayOrder: 0,
          ),
        ];

        final cloned = _cloneBudgets(
          source: store,
          householdId: 'h1',
          sourceMonth: 5,
          sourceYear: 2026,
          targetMonth: 6,
          targetYear: 2026,
        );

        expect(cloned[0].id, isEmpty);
      });

      test('returns empty list when source month is empty', () {
        final cloned = _cloneBudgets(
          source: [],
          householdId: 'h1',
          sourceMonth: 5,
          sourceYear: 2026,
          targetMonth: 6,
          targetYear: 2026,
        );

        expect(cloned, isEmpty);
      });
    });

    group('cloneBudgetIfNeeded (integration)', () {
      test('clones from latest month when target is empty', () {
        final store = [
          const Budget(
            id: 'b1', householdId: 'h1', categoryId: 'c1',
            month: 5, year: 2026, amount: 5000000, displayOrder: 0,
          ),
          const Budget(
            id: 'b2', householdId: 'h1', categoryId: 'c2',
            month: 5, year: 2026, amount: 2000000, displayOrder: 1,
          ),
          const Budget(
            id: 'b3', householdId: 'h1', categoryId: 'c3',
            month: 5, year: 2026, amount: 1500000, displayOrder: 2,
          ),
        ];

        final result = _simulateCloneIfNeeded(
          store: store,
          householdId: 'h1',
          targetMonth: 6,
          targetYear: 2026,
          createdBy: 'user1',
        );

        expect(result.cloned, true);
        expect(result.budgets.length, 3);
        expect(result.budgets[0].amount, 5000000);
        expect(result.budgets[1].amount, 2000000);
        expect(result.budgets[2].amount, 1500000);
      });

      test('skips cloning when target month already has budgets', () {
        final store = [
          const Budget(
            id: 'b1', householdId: 'h1', categoryId: 'c1',
            month: 5, year: 2026, amount: 5000000,
          ),
          const Budget(
            id: 'b2', householdId: 'h1', categoryId: 'c1',
            month: 6, year: 2026, amount: 3000000,
          ),
        ];

        final result = _simulateCloneIfNeeded(
          store: store,
          householdId: 'h1',
          targetMonth: 6,
          targetYear: 2026,
        );

        expect(result.cloned, false);
        expect(result.budgets, isEmpty);
      });

      test('returns false for new user with no previous budgets', () {
        final result = _simulateCloneIfNeeded(
          store: [],
          householdId: 'h1',
          targetMonth: 6,
          targetYear: 2026,
        );

        expect(result.cloned, false);
        expect(result.budgets, isEmpty);
      });

      test('clones across year boundary', () {
        final store = [
          const Budget(
            id: 'b1', householdId: 'h1', categoryId: 'c1',
            month: 12, year: 2025, amount: 4000000, displayOrder: 0,
          ),
        ];

        final result = _simulateCloneIfNeeded(
          store: store,
          householdId: 'h1',
          targetMonth: 1,
          targetYear: 2026,
        );

        expect(result.cloned, true);
        expect(result.budgets.length, 1);
        expect(result.budgets[0].amount, 4000000);
        expect(result.budgets[0].month, 1);
        expect(result.budgets[0].year, 2026);
      });

      test('preserves display_order during cloning', () {
        final store = [
          const Budget(
            id: 'b1', householdId: 'h1', categoryId: 'c1',
            month: 5, year: 2026, amount: 1000000, displayOrder: 2,
          ),
          const Budget(
            id: 'b2', householdId: 'h1', categoryId: 'c2',
            month: 5, year: 2026, amount: 2000000, displayOrder: 0,
          ),
          const Budget(
            id: 'b3', householdId: 'h1', categoryId: 'c3',
            month: 5, year: 2026, amount: 3000000, displayOrder: 1,
          ),
        ];

        final result = _simulateCloneIfNeeded(
          store: store,
          householdId: 'h1',
          targetMonth: 6,
          targetYear: 2026,
        );

        expect(result.cloned, true);
        final sorted = result.budgets..sort(
          (a, b) => a.displayOrder.compareTo(b.displayOrder),
        );
        expect(sorted[0].categoryId, 'c2');
        expect(sorted[0].displayOrder, 0);
        expect(sorted[1].categoryId, 'c3');
        expect(sorted[1].displayOrder, 1);
        expect(sorted[2].categoryId, 'c1');
        expect(sorted[2].displayOrder, 2);
      });
    });
  });
}

// --- Helper functions that mirror BudgetCloneService logic ---

bool _hasBudgetsForMonth(
  List<Budget> store,
  String householdId,
  int month,
  int year,
) {
  return store.any(
    (b) => b.householdId == householdId && b.month == month && b.year == year,
  );
}

({int month, int year})? _findLatestBefore(
  List<Budget> store,
  String householdId,
  int targetMonth,
  int targetYear,
) {
  ({int month, int year})? latest;

  for (final b in store) {
    if (b.householdId != householdId) continue;
    if (b.year > targetYear || (b.year == targetYear && b.month >= targetMonth)) {
      continue;
    }
    if (latest == null ||
        b.year > latest.year ||
        (b.year == latest.year && b.month > latest.month)) {
      latest = (month: b.month, year: b.year);
    }
  }

  return latest;
}

List<Budget> _cloneBudgets({
  required List<Budget> source,
  required String householdId,
  required int sourceMonth,
  required int sourceYear,
  required int targetMonth,
  required int targetYear,
  String? createdBy,
}) {
  final sourceBudgets = source.where(
    (b) => b.householdId == householdId &&
        b.month == sourceMonth &&
        b.year == sourceYear,
  ).toList();

  return sourceBudgets.map((budget) {
    return Budget(
      id: '',
      householdId: householdId,
      categoryId: budget.categoryId,
      month: targetMonth,
      year: targetYear,
      amount: budget.amount,
      displayOrder: budget.displayOrder,
      createdBy: createdBy,
    );
  }).toList();
}

({bool cloned, List<Budget> budgets}) _simulateCloneIfNeeded({
  required List<Budget> store,
  required String householdId,
  required int targetMonth,
  required int targetYear,
  String? createdBy,
}) {
  if (_hasBudgetsForMonth(store, householdId, targetMonth, targetYear)) {
    return (cloned: false, budgets: <Budget>[]);
  }

  final source = _findLatestBefore(store, householdId, targetMonth, targetYear);
  if (source == null) {
    return (cloned: false, budgets: <Budget>[]);
  }

  final cloned = _cloneBudgets(
    source: store,
    householdId: householdId,
    sourceMonth: source.month,
    sourceYear: source.year,
    targetMonth: targetMonth,
    targetYear: targetYear,
    createdBy: createdBy,
  );

  return (cloned: true, budgets: cloned);
}
