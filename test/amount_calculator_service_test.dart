import 'package:flutter_test/flutter_test.dart';
import 'package:thu_chi_viet_nam/features/transactions/data/amount_calculator_service.dart';

void main() {
  group('AmountCalculatorService', () {
    const service = AmountCalculatorService();

    test('parses raw numbers', () {
      final result = service.evaluate('500000');

      expect(result.isValid, true);
      expect(result.value, 500000);
    });

    test('parses dot-separated VND thousands', () {
      final result = service.evaluate('30.000');

      expect(result.isValid, true);
      expect(result.value, 30000);
    });

    test('calculates addition and subtraction with commas', () {
      final result = service.evaluate('1,000,000 - 150,000 + 20,000');

      expect(result.isValid, true);
      expect(result.value, 870000);
    });

    test('respects multiplication, division, and parentheses', () {
      final result = service.evaluate('(500000 + 200000) / 2');

      expect(result.isValid, true);
      expect(result.value, 350000);
    });

    test('supports calculator display operators', () {
      final result = service.evaluate('(500000 + 200000) ÷ 2 × 3');

      expect(result.isValid, true);
      expect(result.value, 1050000);
    });

    test('supports percentage suffix in expressions', () {
      final result = service.evaluate('500000 + 500000 × 10%');

      expect(result.isValid, true);
      expect(result.value, 550000);
    });

    test('calculates additive percentages from the left amount', () {
      final result = service.evaluate('100 - 30%');

      expect(result.isValid, true);
      expect(result.value, 70);
    });

    test('calculates additive percentage increases from the left amount', () {
      final result = service.evaluate('100 + 30%');

      expect(result.isValid, true);
      expect(result.value, 130);
    });

    test('supports percentage suffix after parentheses', () {
      final result = service.evaluate('(500000 + 200000) × 50%');

      expect(result.isValid, true);
      expect(result.value, 350000);
    });

    test('supports decimal comma input', () {
      final result = service.evaluate('3,5+1,5+2,5+2,5');

      expect(result.isValid, true);
      expect(result.value, 10);
    });

    test('ignores letters and invalid characters while sanitizing', () {
      final result = service.evaluate('abc500000xyz + @20000');

      expect(result.isValid, true);
      expect(result.expression, '500000+20000');
      expect(result.value, 520000);
    });

    test('handles floating point precision', () {
      final result = service.evaluate('0.1 + 0.2');

      expect(result.isValid, true);
      expect(result.value, 0.3);
    });

    test('handles large numbers', () {
      final result = service.evaluate('999,999,999,999 + 1');

      expect(result.isValid, true);
      expect(result.value, 1000000000000);
    });

    test('returns error for empty input', () {
      final result = service.evaluate('');

      expect(result.isValid, false);
      expect(result.errorMessage, 'Vui lòng nhập số tiền.');
    });

    test('returns error for division by zero', () {
      final result = service.evaluate('500000 / 0');

      expect(result.isValid, false);
      expect(result.errorMessage, 'Không thể chia cho 0.');
    });

    test('returns error for invalid parentheses', () {
      final result = service.evaluate('(500000 + 200000');

      expect(result.isValid, false);
      expect(result.errorMessage, 'Thiếu dấu ngoặc đóng.');
    });

    test('returns error for invalid syntax', () {
      final result = service.evaluate('500000 + * 2');

      expect(result.isValid, false);
      expect(result.errorMessage, 'Biểu thức không hợp lệ.');
    });
  });
}
