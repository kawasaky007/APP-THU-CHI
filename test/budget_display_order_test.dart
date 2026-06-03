import 'package:flutter_test/flutter_test.dart';
import 'package:thu_chi_viet_nam/core/models/budget.dart';

void main() {
  group('Budget model - displayOrder', () {
    test('fromJson parses display_order correctly', () {
      final json = {
        'id': 'budget-1',
        'household_id': 'household-1',
        'category_id': 'category-1',
        'month': 6,
        'year': 2026,
        'amount': 500000,
        'display_order': 3,
        'created_by': 'user-1',
        'created_at': '2026-05-31T00:00:00Z',
        'updated_at': '2026-05-31T00:00:00Z',
      };

      final budget = Budget.fromJson(json);

      expect(budget.displayOrder, 3);
    });

    test('fromJson defaults displayOrder to 0 when null', () {
      final json = {
        'id': 'budget-1',
        'household_id': 'household-1',
        'category_id': 'category-1',
        'month': 6,
        'year': 2026,
        'amount': 500000,
        'display_order': null,
      };

      final budget = Budget.fromJson(json);

      expect(budget.displayOrder, 0);
    });

    test('fromJson defaults displayOrder to 0 when missing', () {
      final json = {
        'id': 'budget-1',
        'household_id': 'household-1',
        'category_id': 'category-1',
        'month': 6,
        'year': 2026,
        'amount': 500000,
      };

      final budget = Budget.fromJson(json);

      expect(budget.displayOrder, 0);
    });

    test('toJson includes display_order', () {
      const budget = Budget(
        id: 'budget-1',
        householdId: 'household-1',
        categoryId: 'category-1',
        month: 6,
        year: 2026,
        amount: 500000,
        displayOrder: 5,
      );

      final json = budget.toJson();

      expect(json['display_order'], 5);
    });

    test('copyWith updates displayOrder', () {
      const budget = Budget(
        id: 'budget-1',
        householdId: 'household-1',
        categoryId: 'category-1',
        month: 6,
        year: 2026,
        amount: 500000,
        displayOrder: 0,
      );

      final reordered = budget.copyWith(displayOrder: 7);

      expect(reordered.displayOrder, 7);
      expect(reordered.id, 'budget-1');
      expect(reordered.amount, 500000);
    });

    test('copyWith preserves displayOrder when not specified', () {
      const budget = Budget(
        id: 'budget-1',
        householdId: 'household-1',
        categoryId: 'category-1',
        month: 6,
        year: 2026,
        amount: 500000,
        displayOrder: 4,
      );

      final copied = budget.copyWith(amount: 600000);

      expect(copied.displayOrder, 4);
      expect(copied.amount, 600000);
    });
  });

  group('Budget sorting by displayOrder', () {
    test('budgets sort by displayOrder ascending', () {
      final budgets = [
        const Budget(
          id: 'b3', householdId: 'h1', categoryId: 'c3',
          month: 6, year: 2026, amount: 100, displayOrder: 2,
        ),
        const Budget(
          id: 'b1', householdId: 'h1', categoryId: 'c1',
          month: 6, year: 2026, amount: 200, displayOrder: 0,
        ),
        const Budget(
          id: 'b2', householdId: 'h1', categoryId: 'c2',
          month: 6, year: 2026, amount: 300, displayOrder: 1,
        ),
      ];

      budgets.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      expect(budgets[0].id, 'b1');
      expect(budgets[1].id, 'b2');
      expect(budgets[2].id, 'b3');
    });

    test('reorder simulation produces correct display_order values', () {
      final budgets = [
        const Budget(
          id: 'b1', householdId: 'h1', categoryId: 'c1',
          month: 6, year: 2026, amount: 100, displayOrder: 0,
        ),
        const Budget(
          id: 'b2', householdId: 'h1', categoryId: 'c2',
          month: 6, year: 2026, amount: 200, displayOrder: 1,
        ),
        const Budget(
          id: 'b3', householdId: 'h1', categoryId: 'c3',
          month: 6, year: 2026, amount: 300, displayOrder: 2,
        ),
      ];

      // Simulate dragging item at index 2 to index 0
      final reordered = List<Budget>.from(budgets);
      final item = reordered.removeAt(2);
      reordered.insert(0, item);

      final updatedBudgets = [
        for (var i = 0; i < reordered.length; i++)
          reordered[i].copyWith(displayOrder: i),
      ];

      expect(updatedBudgets[0].id, 'b3');
      expect(updatedBudgets[0].displayOrder, 0);
      expect(updatedBudgets[1].id, 'b1');
      expect(updatedBudgets[1].displayOrder, 1);
      expect(updatedBudgets[2].id, 'b2');
      expect(updatedBudgets[2].displayOrder, 2);
    });
  });
}
