import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../shared/formatters/currency_input_formatter.dart';
import '../../data/amount_calculator_service.dart';

class AmountExpressionInput extends StatefulWidget {
  const AmountExpressionInput({
    required this.controller,
    required this.result,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final AmountCalculationResult result;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<AmountExpressionInput> createState() => _AmountExpressionInputState();
}

class _AmountExpressionInputState extends State<AmountExpressionInput> {
  bool _isCalculatorOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final expression = widget.controller.text.trim();
    final value = widget.result.value;
    final hasText = expression.isNotEmpty;
    final isValid = widget.result.isValid && value != null && value > 0;
    final helperText = isValid
        ? _formatCurrency(value)
        : 'Nhập số tiền hoặc dùng máy tính';
    final errorText = hasText && !isValid
        ? widget.result.errorMessage ?? 'Số tiền không hợp lệ.'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: widget.controller,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: const [CurrencyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Số tiền',
                hintText: '0',
                helperText: errorText == null ? helperText : null,
                errorText: errorText,
                suffixText: 'đ',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasText)
                      IconButton(
                        tooltip: 'Xóa số tiền',
                        onPressed: widget.enabled
                            ? () => _setAmountExpression('')
                            : null,
                        icon: const Icon(Icons.close),
                      ),
                    IconButton(
                      tooltip: 'Mở máy tính',
                      onPressed: widget.enabled && !_isCalculatorOpen
                          ? _openCalculatorSheet
                          : null,
                      icon: const Icon(Icons.calculate_outlined),
                    ),
                  ],
                ),
                border: const OutlineInputBorder(),
              ),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
              onChanged: widget.onChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            _QuickAmountSuggestions(
              enabled: widget.enabled,
              input: expression,
              onSelected: _setQuickAmount,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCalculatorSheet() async {
    if (!widget.enabled || _isCalculatorOpen) {
      return;
    }

    setState(() {
      _isCalculatorOpen = true;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (sheetContext) {
        return _AmountCalculatorSheet(
          initialExpression: widget.controller.text,
          enabled: widget.enabled,
          onDone: (value) {
            _commitAmount(value);
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _isCalculatorOpen = false;
    });
  }

  void _setAmountExpression(String next) {
    final formatted = CurrencyInputFormatter.formatDigits(next);
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onChanged(widget.controller.text);
  }

  void _commitAmount(double value) {
    if (!widget.enabled) {
      return;
    }

    if (value <= 0) {
      return;
    }

    final next = _formatCalculatorValue(value);
    _setAmountExpression(next);
  }

  void _setQuickAmount(int amount) {
    if (!widget.enabled) {
      return;
    }

    _setAmountExpression(amount.toString());
  }

  String _formatCurrency(double value) {
    final rounded = value.roundToDouble();
    final decimalDigits = (value - rounded).abs() < 0.000001 ? 0 : 2;
    final pattern = decimalDigits == 0 ? '#,##0' : '#,##0.##';
    return '${NumberFormat(pattern, 'en_US').format(value).replaceAll(',', '.')} VND';
  }

  String _formatCalculatorValue(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.000001) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _AmountCalculatorSheet extends StatefulWidget {
  const _AmountCalculatorSheet({
    required this.initialExpression,
    required this.enabled,
    required this.onDone,
  });

  final String initialExpression;
  final bool enabled;
  final ValueChanged<double> onDone;

  @override
  State<_AmountCalculatorSheet> createState() => _AmountCalculatorSheetState();
}

class _AmountCalculatorSheetState extends State<_AmountCalculatorSheet> {
  static const _calculator = AmountCalculatorService();

  late String _expression;
  late AmountCalculationResult _result;
  late bool _hasCalculatedResult;

  @override
  void initState() {
    super.initState();
    _expression = widget.initialExpression;
    _result = _calculator.evaluate(_expression);
    _hasCalculatedResult = _isPositiveResult(_result);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final expression = _expression.trim();
    final value = _result.value;
    final hasText = expression.isNotEmpty;
    final isValid = _hasCalculatedResult && _isPositiveResult(_result);
    final resultText = !hasText
        ? 'Chạm số để nhập số tiền'
        : !_hasCalculatedResult
        ? 'Nhấn = để tính kết quả'
        : isValid
        ? 'Kết quả: ${_formatCurrency(value!)}'
        : _result.errorMessage ?? 'Biểu thức không hợp lệ.';
    final resultColor = !hasText
        ? const Color(0xFFB7BDBA)
        : !_hasCalculatedResult
        ? const Color(0xFFB7BDBA)
        : isValid
        ? const Color(0xFF34D399)
        : colorScheme.error;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Material(
            color: const Color(0xFF151A18),
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CalculatorDisplay(
                    expression: expression,
                    resultText: resultText,
                    resultColor: resultColor,
                    value: value,
                    isValid: isValid,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CalculatorKeypad(
                    enabled: widget.enabled,
                    onPressed: _handleKey,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CalculatorDoneButton(
                    enabled: widget.enabled && isValid,
                    onPressed: _commitAmount,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleKey(String key) {
    if (!widget.enabled) {
      return;
    }

    final current = _expression;
    if (key == '=') {
      _calculateExpression();
      return;
    }

    final next = switch (key) {
      'AC' => '',
      '⌫' => current.isEmpty ? '' : current.substring(0, current.length - 1),
      '()' => _toggleParenthesis(current),
      '+/-' => _toggleSign(current),
      ',' => _appendComma(current),
      '%' => _appendPercent(current),
      '+' || '-' || '×' || '÷' => _appendOperator(current, key),
      _ => current + key,
    };

    _setExpression(next);
  }

  void _setExpression(String next) {
    setState(() {
      _expression = next;
      _result = AmountCalculationResult.error(
        expression: _calculator.sanitize(next),
        message: 'Nhấn = để tính kết quả.',
      );
      _hasCalculatedResult = false;
    });
  }

  void _calculateExpression() {
    final result = _calculateResult(_expression);
    final value = result.value;

    setState(() {
      if (result.isValid && value != null && value > 0) {
        _expression = _formatCalculatorValue(value);
        _result = _calculateResult(_expression);
      } else {
        _result = result;
      }
      _hasCalculatedResult = true;
    });
  }

  void _commitAmount() {
    final value = _result.value;
    if (!_hasCalculatedResult ||
        !_result.isValid ||
        value == null ||
        value <= 0) {
      return;
    }

    widget.onDone(value);
  }

  String _appendOperator(String current, String operator) {
    if (current.isEmpty) {
      return operator == '-' ? '-' : current;
    }

    final last = current.characters.last;
    if (last == '(' && operator != '-') {
      return current;
    }
    if (_isOperator(last)) {
      return current.substring(0, current.length - 1) + operator;
    }
    if (last == ',') {
      return current.substring(0, current.length - 1) + operator;
    }
    return current + operator;
  }

  String _appendComma(String current) {
    if (current.isEmpty) {
      return '0,';
    }

    final last = current.characters.last;
    if (_isOperator(last) || last == '(') {
      return '${current}0,';
    }
    if (last == ')' ||
        last == '%' ||
        _currentNumberSegment(current).contains(',')) {
      return current;
    }
    return '$current,';
  }

  String _appendPercent(String current) {
    if (current.isEmpty) {
      return current;
    }

    final last = current.characters.last;
    if (_isOperator(last) || last == '(' || last == ',' || last == '%') {
      return current;
    }
    return '$current%';
  }

  String _toggleParenthesis(String current) {
    if (current.isEmpty) {
      return '(';
    }

    final openCount = '('.allMatches(current).length;
    final closeCount = ')'.allMatches(current).length;
    final last = current.characters.last;

    if (_isOperator(last) || last == '(') {
      return '$current(';
    }
    if (openCount > closeCount) {
      return '$current)';
    }
    return '$current×(';
  }

  String _toggleSign(String current) {
    if (current.isEmpty) {
      return '-';
    }
    if (current.startsWith('-')) {
      return current.substring(1);
    }
    return '-($current)';
  }

  String _currentNumberSegment(String current) {
    final lastBoundary = current.lastIndexOf(RegExp(r'[+\-×÷*/()]'));
    return current.substring(lastBoundary + 1);
  }

  bool _isOperator(String value) {
    return value == '+' ||
        value == '-' ||
        value == '×' ||
        value == '÷' ||
        value == '*' ||
        value == '/';
  }

  AmountCalculationResult _calculateResult(String expression) {
    final result = _calculator.evaluate(expression);
    final value = result.value;
    if (result.isValid && value != null && value <= 0) {
      return AmountCalculationResult.error(
        expression: result.expression,
        message: 'Số tiền phải lớn hơn 0.',
      );
    }
    return result;
  }

  bool _isPositiveResult(AmountCalculationResult result) {
    final value = result.value;
    return result.isValid && value != null && value > 0;
  }

  String _formatCurrency(double value) {
    final rounded = value.roundToDouble();
    final decimalDigits = (value - rounded).abs() < 0.000001 ? 0 : 2;
    final pattern = decimalDigits == 0 ? '#,##0' : '#,##0.##';
    return '${NumberFormat(pattern, 'en_US').format(value).replaceAll(',', '.')} VND';
  }

  String _formatCalculatorValue(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.000001) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _QuickAmountSuggestions extends StatelessWidget {
  const _QuickAmountSuggestions({
    required this.enabled,
    required this.input,
    required this.onSelected,
  });

  final bool enabled;
  final String input;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final amounts = _quickAmountsForInput(input);

    return Row(
      children: [
        for (final amount in amounts) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: enabled ? () => onSelected(amount) : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  NumberFormat(
                    '#,##0',
                    'en_US',
                  ).format(amount).replaceAll(',', '.'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          if (amount != amounts.last) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}

List<int> _quickAmountsForInput(String input) {
  final cleanInput = input.replaceAll(RegExp(r'\D'), '');
  final base = int.tryParse(cleanInput);
  if (base == null || base <= 0) {
    return const [10000, 100000, 1000000];
  }

  final suggestions = <int>[];
  var multiplier = 10;
  while (suggestions.length < 3 && multiplier <= 100000000) {
    final amount = base * multiplier;
    if (amount >= 10000 && amount > base) {
      suggestions.add(amount);
    }
    multiplier *= 10;
  }

  return suggestions.isEmpty ? const [10000, 100000, 1000000] : suggestions;
}

class _CalculatorDisplay extends StatelessWidget {
  const _CalculatorDisplay({
    required this.expression,
    required this.resultText,
    required this.resultColor,
    required this.value,
    required this.isValid,
  });

  final String expression;
  final String resultText;
  final Color resultColor;
  final double? value;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF202523),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3C4440)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            expression.isEmpty ? '0' : expression,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFB7BDBA),
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              isValid && value != null ? _formatDisplayValue(value!) : '--',
              textAlign: TextAlign.right,
              style: theme.textTheme.displayMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              resultText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: resultColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDisplayValue(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.000001) {
      return NumberFormat('#,##0', 'en_US').format(value);
    }
    return NumberFormat('#,##0.##', 'en_US').format(value).replaceAll('.', ',');
  }
}

class _CalculatorKeypad extends StatelessWidget {
  const _CalculatorKeypad({required this.enabled, required this.onPressed});

  final bool enabled;
  final ValueChanged<String> onPressed;

  static const _rows = [
    ['⌫', 'AC', '()', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '-'],
    ['1', '2', '3', '+'],
    ['+/-', '0', ',', '='],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _rows) ...[
          Row(
            children: [
              for (final key in row) ...[
                Expanded(
                  child: _CalculatorKeyButton(
                    label: key,
                    enabled: enabled,
                    onPressed: () => onPressed(key),
                  ),
                ),
                if (key != row.last) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          if (row != _rows.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CalculatorDoneButton extends StatelessWidget {
  const _CalculatorDoneButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const doneColor = Color(0xFF16A34A);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Xong'),
        style: FilledButton.styleFrom(
          backgroundColor: doneColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: doneColor.withValues(alpha: 0.28),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _CalculatorKeyButton extends StatelessWidget {
  const _CalculatorKeyButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isOperator =
        label == '÷' ||
        label == '×' ||
        label == '-' ||
        label == '+' ||
        label == '=';
    final isControl =
        label == 'AC' || label == '⌫' || label == '()' || label == '%';
    final backgroundColor = isOperator
        ? const Color(0xFFFF9700)
        : isControl
        ? const Color(0xFF757B78)
        : const Color(0xFF454B48);
    final foregroundColor = Colors.white.withValues(alpha: enabled ? 1 : 0.45);

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: backgroundColor.withValues(alpha: enabled ? 1 : 0.42),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: _CalculatorKeyContent(label: label, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}

class _CalculatorKeyContent extends StatelessWidget {
  const _CalculatorKeyContent({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = switch (label) {
      '⌫' => Icons.backspace_outlined,
      '÷' => Icons.horizontal_rule,
      '×' => Icons.close,
      '-' => Icons.remove,
      '+' => Icons.add,
      _ => null,
    };

    if (label == '÷') {
      return Text(
        '÷',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    if (icon != null) {
      return Icon(icon, color: color, size: 28);
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
