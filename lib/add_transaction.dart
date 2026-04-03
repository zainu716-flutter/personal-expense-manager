import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/transaction_provider.dart';

class AddTransaction extends StatefulWidget {
  final String? accountId;
  final String? accountName;
  final String initialType; // ← ADDED

  const AddTransaction({
    Key? key,
    this.accountId,
    this.accountName,
    this.initialType = 'cash_in', // ← ADDED (default = cash_in)
  }) : super(key: key);

  @override
  State<AddTransaction> createState() => _AddTransactionState();
}

class _AddTransactionState extends State<AddTransaction> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  late String _type; // ← CHANGED from: String _type = 'cash_in';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType; // ← ADDED: picks up 'cash_in' or 'cash_out'
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ── Date Picker ───────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Colors.blue,
            surface: Color(0xFF2C2C2C),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  // ── Time Picker ───────────────────────────────
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Colors.blue,
            surface: Color(0xFF2C2C2C),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  // ── Open Calculator Popup ─────────────────────
  void _openCalculatorPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _CalculatorDialog(
        onResult: (result) {
          _amountController.text = result;
        },
      ),
    );
  }

  // ── Save Transaction — pop first, Firebase in background ──
  void _saveTransaction() {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();

    if (title.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Fire Firebase in background — no await
    context.read<TransactionProvider>().addTransaction(
      title: title,
      amount: amount,
      type: _type,
      accountId: widget.accountId,
      accountName: widget.accountName,
      date: _selectedDate,
    );

    // ✅ Pop immediately — don't wait for Firebase
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.accountName != null && widget.accountId != null
              ? 'Add — ${widget.accountName}'
              : 'Add Transaction',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Amount ────────────────────────
              Text(
                'Amount',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Color(0xFF1A1A1A),
                  prefixText: 'Rs. ',
                  prefixStyle: TextStyle(color: Colors.white),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.calculate_outlined,
                      color: Colors.blue,
                      size: 22,
                    ),
                    onPressed: _openCalculatorPopup,
                    tooltip: 'Calculator',
                  ),
                ),
              ),

              SizedBox(height: 14),

              // ── Title ─────────────────────────
              Text('Title', style: TextStyle(color: Colors.grey, fontSize: 12)),
              SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter title...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Color(0xFF1A1A1A),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.blue, width: 1.5),
                  ),
                ),
              ),

              SizedBox(height: 14),

              // ── Date & Time ───────────────────
              Text(
                'Date & Time',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  // Date
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.blue,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_selectedDate),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Time
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.blue,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('hh:mm a').format(_selectedDate),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 14),

              // ── Type selector ─────────────────
              Text('Type', style: TextStyle(color: Colors.grey, fontSize: 12)),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'cash_in'),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _type == 'cash_in'
                              ? Colors.green
                              : Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _type == 'cash_in'
                                ? Colors.green
                                : Colors.grey[800]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '⬆ Cash In',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'cash_out'),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _type == 'cash_out'
                              ? Colors.red
                              : Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _type == 'cash_out'
                                ? Colors.red
                                : Colors.grey[800]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '⬇ Cash Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // ── Save Button ───────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Save Transaction',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

// ── Calculator Dialog ─────────────────────────────

class _CalculatorDialog extends StatefulWidget {
  final Function(String) onResult;

  const _CalculatorDialog({Key? key, required this.onResult}) : super(key: key);

  @override
  State<_CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<_CalculatorDialog> {
  String _display = '0';
  String _expression = '';
  double? _firstOperand;
  String? _operator;
  bool _waitingForSecond = false;

  void _onButton(String val) {
    setState(() {
      if (val == 'C') {
        _display = '0';
        _expression = '';
        _firstOperand = null;
        _operator = null;
        _waitingForSecond = false;

      } else if (val == '⌫') {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }

      } else if (['+', '-', '×', '÷'].contains(val)) {
        final current = double.tryParse(_display) ?? 0;

        if (_firstOperand == null) {
          _firstOperand = current;
        } else if (_operator != null && !_waitingForSecond) {
          // ✅ AUTO CALCULATE (chain operations)
          _firstOperand = _applyOp(_firstOperand!, _operator!, current);
          _display = _format(_firstOperand!);
        }

        _operator = val;
        _expression = '${_format(_firstOperand!)} $val';
        _waitingForSecond = true;

      } else if (val == '=') {
        if (_firstOperand != null && _operator != null) {
          final second = double.tryParse(_display) ?? 0;

          final result = _applyOp(_firstOperand!, _operator!, second);

          _expression = '$_expression $_display =';
          _display = _format(result);

          _firstOperand = null;
          _operator = null;
          _waitingForSecond = false;
        }

      } else if (val == '%') {
        final num = double.tryParse(_display) ?? 0;
        _display = _format(num / 100);

      } else if (val == '+/-') {
        final num = double.tryParse(_display) ?? 0;
        _display = _format(num * -1);

      } else if (val == '.') {
        if (!_display.contains('.')) {
          _display = '$_display.';
        }

      } else {
        if (_waitingForSecond) {
          _display = val;
          _waitingForSecond = false;
        } else {
          _display = _display == '0' ? val : '$_display$val';
        }
      }
    });
  }

  // ✅ Operation handler
  double _applyOp(double a, String op, double b) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return b != 0 ? a / b : 0;
      default:
        return b;
    }
  }

  // ✅ Clean number formatting
  String _format(double result) {
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
          margin: EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: bg ?? Color(0xFF333333),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: fg ?? Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
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
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 80),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 5),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFF2C2C2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calculate, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Calculator',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.grey, size: 22),
                  ),
                ],
              ),
            ),

            // Display
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _expression.isEmpty ? ' ' : _expression,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Rs.$_display',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            Divider(color: Colors.grey[800], height: 1),

            // Buttons
            SizedBox(
              height: 300,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Expanded(child: Row(children: [
                      _btn('C', bg: Color(0xFF505050)),
                      _btn('+/-', bg: Color(0xFF505050)),
                      _btn('%', bg: Color(0xFF505050)),
                      _btn('÷', bg: Colors.orange),
                    ])),
                    Expanded(child: Row(children: [
                      _btn('7'),
                      _btn('8'),
                      _btn('9'),
                      _btn('×', bg: Colors.orange),
                    ])),
                    Expanded(child: Row(children: [
                      _btn('4'),
                      _btn('5'),
                      _btn('6'),
                      _btn('-', bg: Colors.orange),
                    ])),
                    Expanded(child: Row(children: [
                      _btn('1'),
                      _btn('2'),
                      _btn('3'),
                      _btn('+', bg: Colors.orange),
                    ])),
                    Expanded(child: Row(children: [
                      _btn('⌫', bg: Color(0xFF505050)),
                      _btn('0'),
                      _btn('.'),
                      _btn('=', bg: Colors.green),
                    ])),
                  ],
                ),
              ),
            ),

            // Use Amount
            Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    'Use Rs.$_display',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 14),
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
                            Icon(Icons.check_circle, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Amount set to Rs.$_display'),
                          ],
                        ),
                        backgroundColor: Colors.blue,
                        duration: Duration(seconds: 1),
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