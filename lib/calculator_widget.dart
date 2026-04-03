import 'package:flutter/material.dart';

// ════════════════════════════════════════════════
// ── Draggable Calculator ──────────────────────
// ════════════════════════════════════════════════

class DraggableCalculator extends StatefulWidget {
  final VoidCallback onClose;
  const DraggableCalculator({super.key, required this.onClose});

  @override
  State<DraggableCalculator> createState() => _DraggableCalculatorState();
}

class _DraggableCalculatorState extends State<DraggableCalculator> {
  double _x = 20;
  double _y = 100;
  double _width = 300;
  double _height = 440;

  // ── Calculator engine ─────────────────────────
  String _display = '0';
  String _expression = '';

  double _accumulated = 0;
  String? _pendingOp;
  bool _freshOperand = true;

  // ── Core button handler ───────────────────────
  void _onButton(String val) {
    setState(() {
      if (val == 'C') {
        _display = '0';
        _expression = '';
        _accumulated = 0;
        _pendingOp = null;
        _freshOperand = true;
      } else if (val == '⌫') {
        if (!_freshOperand) {
          _display = _display.length > 1
              ? _display.substring(0, _display.length - 1)
              : '0';
        }
      } else if (['+', '-', '×', '÷'].contains(val)) {
        final current = double.tryParse(_display) ?? 0;
        if (_pendingOp == null) {
          _accumulated = current;
        } else {
          _accumulated = _applyOp(_accumulated, _pendingOp!, current);
        }
        _pendingOp = val;
        _freshOperand = true;
        final accStr = _formatResult(_accumulated);
        _expression = '$accStr $val';
        _display = _formatResult(_accumulated);
      } else if (val == '=') {
        if (_pendingOp != null) {
          final current = double.tryParse(_display) ?? 0;
          _accumulated = _applyOp(_accumulated, _pendingOp!, current);
          _expression = '${_expression} ${_formatResult(current)} =';
          _display = _formatResult(_accumulated);
          _pendingOp = null;
          _freshOperand = true;
        }
      } else if (val == '%') {
        final num = double.tryParse(_display) ?? 0;
        _display = _formatResult(num / 100);
      } else if (val == '+/-') {
        final num = double.tryParse(_display) ?? 0;
        _display = _formatResult(num * -1);
      } else if (val == '.') {
        if (_freshOperand) {
          _display = '0.';
          _freshOperand = false;
        } else if (!_display.contains('.')) {
          _display = '$_display.';
        }
      } else {
        if (_freshOperand) {
          _display = val;
          _freshOperand = false;
        } else {
          _display = _display == '0' ? val : '$_display$val';
        }
      }
    });
  }

  double _applyOp(double acc, String op, double current) {
    switch (op) {
      case '+':
        return acc + current;
      case '-':
        return acc - current;
      case '×':
        return acc * current;
      case '÷':
        return current != 0 ? acc / current : 0;
      default:
        return current;
    }
  }

  String _formatResult(double result) {
    return result == result.truncateToDouble()
        ? result.toInt().toString()
        : result
              .toStringAsFixed(6)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
  }

  Widget _btn(String label, {Color? bg, Color? fg}) {
    final buttonSize = (_width - 32) / 4;
    return GestureDetector(
      onTap: () => _onButton(label),
      child: Container(
        width: buttonSize,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg ?? const Color(0xFF333333),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fg ?? Colors.white,
              fontSize: _width * 0.046,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    return Positioned(
      left: _x,
      top: _y,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: Column(
            children: [
              // ── Drag handle / header ──────
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _x += details.delta.dx;
                    _y += details.delta.dy;
                    _x = _x.clamp(0.0, screenW - _width);
                    _y = _y.clamp(0.0, screenH - _height);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calculate,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Calculator',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_width > 280) {
                            _width = 240;
                            _height = 370;
                          } else {
                            _width = 320;
                            _height = 460;
                          }
                        }),
                        child: Icon(
                          _width > 280 ? Icons.zoom_out : Icons.zoom_in,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Display ──────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                color: const Color(0xFF1C1C1E),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression.isEmpty ? ' ' : _expression,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: _width * 0.036,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      _display,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _width * 0.095,
                        fontWeight: FontWeight.w300,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.grey[800], height: 1),
              // ── Buttons ──────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _btn('C', bg: const Color(0xFF505050)),
                            _btn('+/-', bg: const Color(0xFF505050)),
                            _btn('%', bg: const Color(0xFF505050)),
                            _btn('÷', bg: Colors.orange),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _btn('7'),
                            _btn('8'),
                            _btn('9'),
                            _btn('×', bg: Colors.orange),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _btn('4'),
                            _btn('5'),
                            _btn('6'),
                            _btn('-', bg: Colors.orange),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _btn('1'),
                            _btn('2'),
                            _btn('3'),
                            _btn('+', bg: Colors.orange),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            _btn('⌫', bg: const Color(0xFF505050)),
                            _btn('0'),
                            _btn('.'),
                            _btn('=', bg: Colors.green),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Resize handle ─────────────
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _width += details.delta.dx;
                      _height += details.delta.dy;
                      _width = _width.clamp(220.0, 380.0);
                      _height = _height.clamp(340.0, 580.0);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.open_in_full,
                      color: Colors.grey[600],
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// ── Calculator Dialog (Edit Transaction) ─────
// ════════════════════════════════════════════════

class CalculatorDialog extends StatefulWidget {
  final Function(String) onResult;
  final num initialAmount;

  const CalculatorDialog({
    Key? key,
    required this.onResult,
    required this.initialAmount,
  }) : super(key: key);

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  late String _display;
  String _expression = '';

  double _accumulated = 0;
  String? _pendingOp;
  bool _freshOperand = true;

  @override
  void initState() {
    super.initState();
    _display = widget.initialAmount.toString();
    _expression = '';
  }

  void _onButton(String val) {
    setState(() {
      if (val == 'C') {
        _display = '0';
        _expression = '';
        _accumulated = 0;
        _pendingOp = null;
        _freshOperand = true;
      } else if (val == '⌫') {
        if (!_freshOperand) {
          _display = _display.length > 1
              ? _display.substring(0, _display.length - 1)
              : '0';
        }
      } else if (['+', '-', '×', '÷'].contains(val)) {
        final current = double.tryParse(_display) ?? 0;
        if (_pendingOp == null) {
          _accumulated = current;
        } else {
          _accumulated = _applyOp(_accumulated, _pendingOp!, current);
        }
        _pendingOp = val;
        _freshOperand = true;
        _expression = '${_formatResult(_accumulated)} $val';
        _display = _formatResult(_accumulated);
      } else if (val == '=') {
        if (_pendingOp != null) {
          final current = double.tryParse(_display) ?? 0;
          _accumulated = _applyOp(_accumulated, _pendingOp!, current);
          _expression = '$_expression ${_formatResult(current)} =';
          _display = _formatResult(_accumulated);
          _pendingOp = null;
          _freshOperand = true;
        }
      } else if (val == '%') {
        final num = double.tryParse(_display) ?? 0;
        _display = _formatResult(num / 100);
      } else if (val == '+/-') {
        final num = double.tryParse(_display) ?? 0;
        _display = _formatResult(num * -1);
      } else if (val == '.') {
        if (_freshOperand) {
          _display = '0.';
          _freshOperand = false;
        } else if (!_display.contains('.')) {
          _display = '$_display.';
        }
      } else {
        if (_freshOperand) {
          _display = val;
          _freshOperand = false;
        } else {
          _display = _display == '0' ? val : '$_display$val';
        }
      }
    });
  }

  double _applyOp(double acc, String op, double current) {
    switch (op) {
      case '+':
        return acc + current;
      case '-':
        return acc - current;
      case '×':
        return acc * current;
      case '÷':
        return current != 0 ? acc / current : 0;
      default:
        return current;
    }
  }

  String _formatResult(double result) {
    return result == result.truncateToDouble()
        ? result.toInt().toString()
        : result
              .toStringAsFixed(6)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
  }

  Widget _btn(String label, {Color? bg, Color? fg}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onButton(label),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bg ?? const Color(0xFF333333),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: fg ?? Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 80),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Calculator',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.grey,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            // ── Display ──────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _expression.isEmpty ? ' ' : _expression,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs.$_display',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[800], height: 1),
            // ── Buttons ──────────────────
            SizedBox(
              height: 300,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _btn('C', bg: const Color(0xFF505050)),
                          _btn('+/-', bg: const Color(0xFF505050)),
                          _btn('%', bg: const Color(0xFF505050)),
                          _btn('÷', bg: Colors.orange),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _btn('7'),
                          _btn('8'),
                          _btn('9'),
                          _btn('×', bg: Colors.orange),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _btn('4'),
                          _btn('5'),
                          _btn('6'),
                          _btn('-', bg: Colors.orange),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _btn('1'),
                          _btn('2'),
                          _btn('3'),
                          _btn('+', bg: Colors.orange),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          _btn('⌫', bg: const Color(0xFF505050)),
                          _btn('0'),
                          _btn('.'),
                          _btn('=', bg: Colors.green),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Use Amount Button ─────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    'Use Rs.$_display',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    widget.onResult(_display);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text('Amount set to Rs.$_display'),
                          ],
                        ),
                        backgroundColor: Colors.blue,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}