import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';
import 'indian_format.dart';
import 'calculator_widget.dart';

// ── Transaction Dialogs ───────────────────────
// Contains: options dialog, edit dialog, history dialog,
//           copy dialog, copy success dialog, delete confirm.
// ─────────────────────────────────────────────

class TransactionDialogs with IndianFormatMixin {
  // ── Transaction Options ───────────────────────
  void showTransactionOptions(BuildContext context, DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              doc['type'] == 'cash_in'
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: doc['type'] == 'cash_in' ? Colors.green : Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                doc['title'],
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.blue, size: 20),
              tooltip: 'Copy to another account',
              onPressed: () {
                Navigator.pop(context);
                Future.delayed(
                  const Duration(milliseconds: 200),
                  () => copyTransactionToAccount(context, doc),
                );
              },
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rs.${formatIndian((doc['amount'] as num).toDouble())}',
                    style: TextStyle(
                      color: doc['type'] == 'cash_in'
                          ? Colors.green
                          : Colors.red,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'dd MMM yyyy\nhh:mm a',
                    ).format((doc['date'] as Timestamp).toDate()),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _dialogButton('Edit Transaction', Icons.edit, Colors.blue, () {
              Navigator.pop(context);
              Future.delayed(
                const Duration(milliseconds: 200),
                () => showEditDialog(context, doc),
              );
            }),
            const SizedBox(height: 10),
            _dialogButton(
              'Move to Another Account',
              Icons.copy,
              const Color(0xFF6A0DAD),
              () {
                Navigator.pop(context);
                Future.delayed(
                  const Duration(milliseconds: 200),
                  () => moveTransactionToAccount(context, doc),
                );
              },
            ),
            const SizedBox(height: 10),
            _dialogButton(
              'Delete Transaction',
              Icons.delete_outline,
              Colors.red,
              () {
                Navigator.pop(context);
                Future.delayed(
                  const Duration(milliseconds: 200),
                  () => confirmDelete(context, doc.id),
                );
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }


  // ── Move Transaction to Account ───────────────
  void moveTransactionToAccount(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .orderBy('createdAt')
        .get();

    if (!context.mounted) return;

    String? selectedAccountId;
    String selectedAccountName = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.drive_file_move, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Move Transaction',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),

          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Preview ───────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['title'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rs.${formatIndian((doc['amount'] as num).toDouble())}',
                        style: TextStyle(
                          color: doc['type'] == 'cash_in'
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Move to Account',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),

                // ── Account list ───────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: snap.docs.map((a) {
                      final isSelected = selectedAccountId == a.id;
                      final isCurrentAccount = doc['accountId'] == a.id;

                      return InkWell(
                        onTap: isCurrentAccount
                            ? null
                            : () => setStateDialog(() {
                                selectedAccountId = a.id;
                                selectedAccountName = a['name'];
                              }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.orange.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder,
                                color: isCurrentAccount
                                    ? Colors.grey
                                    : isSelected
                                    ? Colors.orange
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  a['name'],
                                  style: TextStyle(
                                    color: isCurrentAccount
                                        ? Colors.grey
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              if (isCurrentAccount)
                                const Text(
                                  'Current',
                                  style: TextStyle(color: Colors.grey),
                                )
                              else if (isSelected)
                                const Icon(Icons.check, color: Colors.orange),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),

            ElevatedButton.icon(
              icon: const Icon(Icons.drive_file_move, size: 16),
              label: const Text('Move'),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedAccountId != null
                    ? Colors.orange
                    : Colors.grey[700],
              ),
              onPressed: selectedAccountId == null
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);

                      // 🔥 MAIN DIFFERENCE: UPDATE instead of ADD
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('transactions')
                          .doc(doc.id)
                          .update({
                            'accountId': selectedAccountId,
                            'accountName': selectedAccountName,
                          });

                      navigator.pop();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Moved to $selectedAccountName successfully',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ── Copy Transaction to Account ───────────────
  void copyTransactionToAccount(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .orderBy('createdAt')
        .get();
    if (!context.mounted) return;
    String? selectedAccountId;
    String selectedAccountName = '';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.copy, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Copy Transaction',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Transaction preview ───────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: doc['type'] == 'cash_in'
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rs.${formatIndian((doc['amount'] as num).toDouble())}',
                            style: TextStyle(
                              color: doc['type'] == 'cash_in'
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: doc['type'] == 'cash_in'
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              doc['type'] == 'cash_in'
                                  ? '⬆ Cash In'
                                  : '⬇ Cash Out',
                              style: TextStyle(
                                color: doc['type'] == 'cash_in'
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'dd MMM yyyy  hh:mm a',
                        ).format((doc['date'] as Timestamp).toDate()),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Copy to Account',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                // ── Account list ───────────────
                if (snap.docs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'No accounts found.\nCreate an account first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: snap.docs.map((a) {
                        final isSelected = selectedAccountId == a.id;
                        final isCurrentAccount = doc['accountId'] == a.id;
                        return InkWell(
                          onTap: isCurrentAccount
                              ? null
                              : () => setStateDialog(() {
                                  selectedAccountId = a.id;
                                  selectedAccountName = a['name'];
                                }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.blue.withValues(alpha: 0.5),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder,
                                  color: isCurrentAccount
                                      ? Colors.grey[700]
                                      : isSelected
                                      ? Colors.blue
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    a['name'],
                                    style: TextStyle(
                                      color: isCurrentAccount
                                          ? Colors.grey[600]
                                          : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isCurrentAccount)
                                  Text(
                                    'Current',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  )
                                else if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, color: Colors.white, size: 16),
              label: const Text('Copy', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedAccountId != null
                    ? Colors.blue
                    : Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: selectedAccountId == null
                  ? null
                  : () {
                      final navigator = Navigator.of(context);
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('transactions')
                          .add({
                            'title': doc['title'],
                            'amount': doc['amount'],
                            'type': doc['type'],
                            'date': doc['date'],
                            'accountId': selectedAccountId,
                            'accountName': selectedAccountName,
                          });
                      navigator.pop();
                      if (context.mounted) {
                        _showCopySuccessDialog(
                          context,
                          doc,
                          selectedAccountName,
                          navigator,
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ── Copy Success Dialog ───────────────────────
  void _showCopySuccessDialog(
    BuildContext context,
    DocumentSnapshot originalDoc,
    String toAccountName,
    NavigatorState navigator,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transaction Copied!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Successfully copied to',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder, color: Colors.blue, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    toAccountName,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    originalDoc['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs.${formatIndian((originalDoc['amount'] as num).toDouble())}',
                        style: TextStyle(
                          color: originalDoc['type'] == 'cash_in'
                              ? Colors.green
                              : Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'dd MMM yyyy',
                        ).format((originalDoc['date'] as Timestamp).toDate()),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => navigator.pop(),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── History Dialog ────────────────────────────
  void showHistoryDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List history = data.containsKey('history')
        ? List.from(data['history'])
        : [];
    final reversed = history.reversed.toList();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.history, color: Colors.blue, size: 20),
            SizedBox(width: 8),
            Text('Edit History', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: reversed.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        color: Colors.grey,
                        size: 48,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No edit history yet',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: reversed.length,
                  itemBuilder: (_, i) {
                    final item = reversed[i];
                    final isCashIn = item['type'] == 'cash_in';
                    final editedAt = item['editedAt'] != null
                        ? (item['editedAt'] as Timestamp).toDate()
                        : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCashIn
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isCashIn
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isCashIn ? '⬆ In' : '⬇ Out',
                                  style: TextStyle(
                                    color: isCashIn ? Colors.green : Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Rs.${formatIndian((item['amount'] as num).toDouble())}',
                            style: TextStyle(
                              color: isCashIn ? Colors.green : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (editedAt != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.edit_calendar,
                                  color: Colors.blue,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Edited on ${DateFormat('dd MMM yyyy  hh:mm a').format(editedAt)}',
                                  style: TextStyle(
                                    color: Colors.blue[300],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'Edit time unavailable',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ── Edit Transaction Dialog ───────────────────
  void showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final titleController = TextEditingController(text: doc['title']);
    final rawAmount = (doc['amount'] as num).toDouble();
    final amountController = TextEditingController(
      text: rawAmount == rawAmount.truncateToDouble()
          ? rawAmount.toInt().toString()
          : rawAmount.toString(),
    );

    String selectedType = doc['type'];
    String? selectedAccountId = doc['accountId'];
    String selectedAccountName = doc['accountName'] ?? 'All';
    DateTime selectedDate = (doc['date'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Edit Transaction',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.blue),
                tooltip: 'History',
                onPressed: () => showHistoryDialog(context, doc),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ─────────────────────
                const Text(
                  'Title',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Amount ─────────────────────
                const Text(
                  'Amount',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixText: 'Rs. ',
                    prefixStyle: const TextStyle(color: Colors.white),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.calculate_outlined,
                        color: Colors.blue,
                      ),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => CalculatorDialog(
                          initialAmount:
                              double.tryParse(amountController.text) ?? 0,
                          onResult: (result) {
                            setStateDialog(() {
                              amountController.text = result;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Date & Time ─────────────────
                const Text(
                  'Date & Time',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              selectedDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                selectedDate.hour,
                                selectedDate.minute,
                              );
                            });
                          }
                        },
                        child: _dateTimeBox(
                          Icons.calendar_today,
                          DateFormat('dd MMM yyyy').format(selectedDate),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              selectedDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                picked.hour,
                                picked.minute,
                              );
                            });
                          }
                        },
                        child: _dateTimeBox(
                          Icons.access_time,
                          DateFormat('hh:mm a').format(selectedDate),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // ── Type ───────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setStateDialog(() => selectedType = 'cash_in'),
                        child: _typeBox(
                          '⬆ Cash In',
                          selectedType == 'cash_in',
                          Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setStateDialog(() => selectedType = 'cash_out'),
                        child: _typeBox(
                          '⬇ Cash Out',
                          selectedType == 'cash_out',
                          Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () {
                final newTitle = titleController.text.trim();
                final newAmount = double.tryParse(amountController.text.trim());
                if (newTitle.isEmpty || newAmount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields correctly'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                context.read<TransactionProvider>().updateTransaction(
                  docId: doc.id,
                  title: newTitle,
                  amount: newAmount,
                  type: selectedType,
                  accountId: selectedAccountId,
                  accountName: selectedAccountName,
                  date: selectedDate,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction updated!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeBox(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBox(String label, bool selected, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? color : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? color : Colors.grey[800]!),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Delete Confirmation ───────────────────────
  void confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          'Delete Transaction',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this transaction?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<TransactionProvider>().deleteTransaction(docId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Transaction deleted!'),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
