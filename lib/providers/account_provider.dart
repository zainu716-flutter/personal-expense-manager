import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _accounts =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('accounts');

  CollectionReference get _transactions =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('transactions');

  String? _selectedAccountId;
  String _selectedAccountName = 'All Transactions';

  String? get selectedAccountId => _selectedAccountId;
  String get selectedAccountName => _selectedAccountName;

  // ── Load saved account on app start ──────────────────────────────────────
  Future<void> loadSavedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selectedAccountId');
    final savedName = prefs.getString('selectedAccountName');

    if (savedId != null && savedName != null) {
      _selectedAccountId = savedId;
      _selectedAccountName = savedName;
    } else {
      _selectedAccountId = null;
      _selectedAccountName = 'All Transactions';
    }
    notifyListeners();
  }

  // ── Select account and save ───────────────────────────────────────────────
  Future<void> selectAccount(String? id, String name) async {
    _selectedAccountId = id;
    _selectedAccountName = name;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove('selectedAccountId');
      await prefs.remove('selectedAccountName');
    } else {
      await prefs.setString('selectedAccountId', id);
      await prefs.setString('selectedAccountName', name);
    }
  }

  // ── Reset selection (on logout) ───────────────────────────────────────────
  Future<void> resetSelection() async {
    _selectedAccountId = null;
    _selectedAccountName = 'All Transactions';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedAccountId');
    await prefs.remove('selectedAccountName');
  }

  // ── Accounts stream ───────────────────────────────────────────────────────
  Stream<QuerySnapshot> get accountsStream =>
      _accounts.orderBy('name').snapshots();

  // ── Add account — fire & forget ───────────────────────────────────────────
  void addAccount(String name) {
    _accounts.add({
      'name': name,
      'createdAt': Timestamp.now(),
    });
  }

  // ── Rename account — fire & forget ────────────────────────────────────────
  void renameAccount(String docId, String newName) {
    // Update local state immediately if this is the selected account
    if (_selectedAccountId == docId) {
      _selectedAccountName = newName;
      notifyListeners();

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('selectedAccountName', newName);
      });
    }

    // Rename the account doc
    _accounts.doc(docId).update({'name': newName});

    // Update accountName on all transactions belonging to this account
    _transactions
        .where('accountId', isEqualTo: docId)
        .get()
        .then((txns) {
      for (var txn in txns.docs) {
        txn.reference.update({'accountName': newName});
      }
    });
  }

  // ── Delete account — also deletes all its transactions ───────────────────
  void deleteAccount(String docId) {
    // Update local state immediately
    if (_selectedAccountId == docId) {
      _selectedAccountId = null;
      _selectedAccountName = 'All Transactions';
      notifyListeners();

      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('selectedAccountId');
        prefs.remove('selectedAccountName');
      });
    }

    // Delete the account doc
    _accounts.doc(docId).delete();

    // ── Delete ALL transactions belonging to this account ──
    _transactions
        .where('accountId', isEqualTo: docId)
        .get()
        .then((txns) {
      // Firestore batch delete for efficiency
      final batch = FirebaseFirestore.instance.batch();
      for (var txn in txns.docs) {
        batch.delete(txn.reference);
      }
      batch.commit();
    });
  }
}