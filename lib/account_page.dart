import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'providers/account_provider.dart';

class AccountSelectorSheet extends StatefulWidget {
  final String? selectedAccountId;
  final Function(String? id, String name) onAccountSelected;

  const AccountSelectorSheet({
    Key? key,
    required this.selectedAccountId,
    required this.onAccountSelected,
  }) : super(key: key);

  @override
  State<AccountSelectorSheet> createState() => _AccountSelectorSheetState();
}

class _AccountSelectorSheetState extends State<AccountSelectorSheet> {
  bool _isEditMode = false;

  // ── User UID ──────────────────────────────────────────────────────────────
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // ── Firestore Reference ───────────────────────────────────────────────────
  CollectionReference get _accounts =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('accounts');

  // ── Add Account ───────────────────────────────────────────────────────────
  void _showAddAccountDialog(BuildContext sheetContext) {
    final controller = TextEditingController();

    showDialog(
      context: sheetContext,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('New Account',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. Personal, Business...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              // Close the dialog first
              Navigator.pop(sheetContext);

              // ── Create account & get the new doc ID ──
              final docRef = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_uid)
                  .collection('accounts')
                  .add({
                'name': name,
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (!sheetContext.mounted) return;

              // ── Auto-select the new account ──
              widget.onAccountSelected(docRef.id, name);

              // ── Close the bottom sheet ──
              Navigator.pop(sheetContext);

              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Account "$name" created!'),
                  ]),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Create',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Rename Account ────────────────────────────────────────────────────────
  void _showRenameDialog(
      BuildContext outerContext, String docId, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: outerContext,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Account',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'New account name',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(outerContext),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(outerContext);
                return;
              }

              // ✅ Fire & forget — pop immediately
              context.read<AccountProvider>().renameAccount(docId, newName);

              // If this account is currently selected, update the name in provider
              if (widget.selectedAccountId == docId) {
                widget.onAccountSelected(docId, newName);
              }

              Navigator.pop(outerContext);

              ScaffoldMessenger.of(outerContext).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Account renamed!'),
                  ]),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Rename',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Delete Account ────────────────────────────────────────────────────────
  void _showDeleteDialog(
      BuildContext outerContext, String docId, String name) {
    showDialog(
      context: outerContext,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete:',
              style: TextStyle(color: Colors.grey[300]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Note: Transactions in this account will not be deleted.',
              style:
                  TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(outerContext),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // ✅ Fire & forget — pop immediately
              context.read<AccountProvider>().deleteAccount(docId);

              // If deleted account was selected, fall back to All Transactions
              if (widget.selectedAccountId == docId) {
                widget.onAccountSelected(null, 'All Transactions');
              }

              Navigator.pop(outerContext);

              ScaffoldMessenger.of(outerContext).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Account deleted!'),
                  ]),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Accounts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(
                          () => _isEditMode = !_isEditMode),
                      icon: Icon(
                        _isEditMode ? Icons.check : Icons.edit,
                        color: _isEditMode
                            ? Colors.green
                            : Colors.blue,
                        size: 18,
                      ),
                      label: Text(
                        _isEditMode ? 'Done' : 'Edit',
                        style: TextStyle(
                          color: _isEditMode
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ),
                    if (!_isEditMode)
                      IconButton(
                        icon: const Icon(Icons.add,
                            color: Colors.green),
                        onPressed: () =>
                            _showAddAccountDialog(context),
                      ),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey[800], height: 1),

          // Account list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _accounts.orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Colors.green),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading accounts',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                return ListView(
                  children: [
                    _buildAccountTile(
                      context: context,
                      id: null,
                      name: 'All Transactions',
                      icon: Icons.all_inbox,
                      iconColor: Colors.blue,
                      isSelected:
                          widget.selectedAccountId == null,
                    ),

                    if (docs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          'MY ACCOUNTS',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    ...docs.map((doc) {
                      final name = doc['name'] as String;
                      final isSelected =
                          widget.selectedAccountId == doc.id;

                      return _buildAccountTile(
                        context: context,
                        id: doc.id,
                        name: name,
                        icon: Icons.account_balance_wallet,
                        iconColor: Colors.green,
                        isSelected: isSelected,
                        docId: doc.id,
                      );
                    }),

                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.folder_open,
                                  color: Colors.grey[700],
                                  size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'No accounts yet',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 15),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap + to create one',
                                style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Account Tile ──────────────────────────────────────────────────────────
  Widget _buildAccountTile({
    required BuildContext context,
    required String? id,
    required String name,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    String? docId,
  }) {
    return ListTile(
      tileColor: isSelected
          ? Colors.green.withOpacity(0.1)
          : Colors.transparent,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        name,
        style: TextStyle(
          color: Colors.white,
          fontWeight:
              isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: _isEditMode && docId != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit,
                      color: Colors.blue, size: 20),
                  onPressed: () =>
                      _showRenameDialog(context, docId, name),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () =>
                      _showDeleteDialog(context, docId, name),
                ),
              ],
            )
          : isSelected
              ? const Icon(Icons.check_circle,
                  color: Colors.green, size: 20)
              : null,
      onTap: _isEditMode
          ? null
          : () {
              widget.onAccountSelected(id, name);
              Navigator.pop(context);
            },
    );
  }
}