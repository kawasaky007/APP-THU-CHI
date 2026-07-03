class AmountCalculationResult {
  const AmountCalculationResult._({
    required this.expression,
    required this.value,
    required this.errorMessage,
  });

  final String expression;
  final double? value;
  final String? errorMessage;

  bool get isValid => value != null && errorMessage == null;

  factory AmountCalculationResult.success({
    required String expression,
    required double value,
  }) {
    return AmountCalculationResult._(
      expression: expression,
      value: _normalizePrecision(value),
      errorMessage: null,
    );
  }

  factory AmountCalculationResult.error({
    required String expression,
    required String message,
  }) {
    return AmountCalculationResult._(
      expression: expression,
      value: null,
      errorMessage: message,
    );
  }
}

class AmountCalculatorService {
  const AmountCalculatorService();

  AmountCalculationResult evaluate(String input) {
    final expression = sanitize(input);
    if (expression.isEmpty) {
      return AmountCalculationResult.error(
        expression: expression,
        message: 'Vui lòng nhập số tiền.',
      );
    }

    try {
      final parser = _AmountExpressionParser(expression);
      final value = parser.parse();
      if (!value.isFinite) {
        return AmountCalculationResult.error(
          expression: expression,
          message: 'Kết quả không hợp lệ.',
        );
      }

      return AmountCalculationResult.success(
        expression: expression,
        value: value,
      );
    } on _AmountExpressionException catch (error) {
      return AmountCalculationResult.error(
        expression: expression,
        message: error.message,
      );
    }
  }

  String sanitize(String input) {
    final normalizedOperators = input.replaceAll('×', '*').replaceAll('÷', '/');

    return _normalizeNumberSeparators(normalizedOperators)
        .replaceAll(RegExp(r'[^0-9+\-*/().%\s]'), '')
        .replaceAll(RegExp(r'\s+'), '');
  }
}

String _normalizeNumberSeparators(String input) {
  return input.replaceAllMapped(RegExp(r'\d[\d,.]*'), (match) {
    final token = match.group(0)!;
    if (!token.contains(',')) {
      if (!token.contains('.')) {
        return token;
      }

      final parts = token.split('.');
      final looksLikeThousands =
          parts.length > 1 &&
          parts.first.isNotEmpty &&
          parts.first.length <= 3 &&
          parts.skip(1).every((part) => part.length == 3);

      return looksLikeThousands ? parts.join() : token;
    }
    if (token.contains('.')) {
      return token.replaceAll(',', '');
    }

    final parts = token.split(',');
    final looksLikeThousands =
        parts.length > 1 &&
        parts.first.isNotEmpty &&
        parts.first.length <= 3 &&
        parts.skip(1).every((part) => part.length == 3);

    return looksLikeThousands ? parts.join() : token.replaceAll(',', '.');
  });
}

class _AmountExpressionParser {
  _AmountExpressionParser(this._source);

  final String _source;
  int _index = 0;

  double parse() {
    final value = _parseExpression().value;
    if (!_isAtEnd) {
      throw const _AmountExpressionException('Biểu thức không hợp lệ.');
    }
    return value;
  }

  _ParsedAmount _parseExpression() {
    final firstTerm = _parseTerm();
    var value = firstTerm.value;
    var isPercentage = firstTerm.isPercentage;

    while (!_isAtEnd) {
      if (_match('+')) {
        final term = _parseTerm();
        value += term.isPercentage ? value * term.value : term.value;
        isPercentage = false;
      } else if (_match('-')) {
        final term = _parseTerm();
        value -= term.isPercentage ? value * term.value : term.value;
        isPercentage = false;
      } else {
        break;
      }
    }

    return _ParsedAmount(value, isPercentage: isPercentage);
  }

  _ParsedAmount _parseTerm() {
    final firstFactor = _parseFactor();
    var value = firstFactor.value;
    var isPercentage = firstFactor.isPercentage;

    while (!_isAtEnd) {
      if (_match('*')) {
        value *= _parseFactor().value;
        isPercentage = false;
      } else if (_match('/')) {
        final divisor = _parseFactor().value;
        if (divisor.abs() < 0.000000000001) {
          throw const _AmountExpressionException('Không thể chia cho 0.');
        }
        value /= divisor;
        isPercentage = false;
      } else {
        break;
      }
    }

    return _ParsedAmount(value, isPercentage: isPercentage);
  }

  _ParsedAmount _parseFactor() {
    if (_match('+')) {
      return _parseFactor();
    }
    if (_match('-')) {
      final factor = _parseFactor();
      return _ParsedAmount(-factor.value, isPercentage: factor.isPercentage);
    }

    final value = _parsePrimary();
    return _parsePercentSuffix(value);
  }

  _ParsedAmount _parsePrimary() {
    if (_match('(')) {
      final value = _parseExpression();
      if (!_match(')')) {
        throw const _AmountExpressionException('Thiếu dấu ngoặc đóng.');
      }
      return value;
    }

    return _parseNumber();
  }

  _ParsedAmount _parsePercentSuffix(_ParsedAmount value) {
    var resolvedValue = value.value;
    var isPercentage = value.isPercentage;
    while (_match('%')) {
      resolvedValue /= 100;
      isPercentage = true;
    }
    return _ParsedAmount(resolvedValue, isPercentage: isPercentage);
  }

  _ParsedAmount _parseNumber() {
    final start = _index;
    var dotCount = 0;
    var digitCount = 0;

    while (!_isAtEnd) {
      final char = _source[_index];
      if (_isDigit(char)) {
        digitCount++;
        _index++;
      } else if (char == '.') {
        dotCount++;
        if (dotCount > 1) {
          throw const _AmountExpressionException('Số tiền không hợp lệ.');
        }
        _index++;
      } else {
        break;
      }
    }

    if (digitCount == 0) {
      throw const _AmountExpressionException('Biểu thức không hợp lệ.');
    }

    final value = double.tryParse(_source.substring(start, _index));
    if (value == null) {
      throw const _AmountExpressionException('Số tiền không hợp lệ.');
    }
    return _ParsedAmount(value);
  }

  bool _match(String token) {
    if (_isAtEnd || _source[_index] != token) {
      return false;
    }
    _index++;
    return true;
  }

  bool get _isAtEnd => _index >= _source.length;

  bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}

class _ParsedAmount {
  const _ParsedAmount(this.value, {this.isPercentage = false});

  final double value;
  final bool isPercentage;
}

class _AmountExpressionException implements Exception {
  const _AmountExpressionException(this.message);

  final String message;
}

double _normalizePrecision(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.000001) {
    return rounded;
  }
  return double.parse(value.toStringAsFixed(2));
}
