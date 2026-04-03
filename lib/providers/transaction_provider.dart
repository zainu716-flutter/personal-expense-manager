import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User-specific collection reference
  CollectionReference get _transactions =>
      _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('transactions');

  bool _isSearching = false;
  String _searchQuery = '';

  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;

  void toggleSearch() {
    _isSearching = !_isSearching;
    if (!_isSearching) _searchQuery = '';
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _isSearching = false;
    _searchQuery = '';
    notifyListeners();
  }

  Stream<QuerySnapshot> getTransactionStream(String? accountId) {
    if (accountId == null) {
      return _transactions
          .orderBy('date', descending: true)
          .snapshots();
    } else {
      return _transactions
          .where('accountId', isEqualTo: accountId)
          .orderBy('date', descending: true)
          .snapshots();
    }
  }

  List<DocumentSnapshot> filterDocs(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    return docs.where((doc) {
      final title = (doc['title'] as String).toLowerCase();
      final amount = doc['amount'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || amount.contains(query);
    }).toList();
  }

  // ── Fire & forget — UI never waits for Firebase ──
  void addTransaction({
    required String title,
    required double amount,
    required String type,
    String? accountId,
    String? accountName,
    DateTime? date,
  }) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Run in background — no await, no blocking
    _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .add({
      'title': title,
      'amount': amount,
      'type': type,
      'accountId': accountId,
      'accountName': accountName ?? '',
      'date': Timestamp.fromDate(date ?? DateTime.now()),
      'history': [], // initialize empty history on creation
    });
    // Firestore offline cache handles this instantly,
    // syncs to server when connection is available.
  }

  // ── Async update — reads old values first, saves to history ──
  Future<void> updateTransaction({
    required String docId,
    required String title,
    required double amount,
    required String type,
    String? accountId,
    String? accountName,
    DateTime? date,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(docId);

    try {
      // ── Fetch current doc to snapshot into history ──
      final currentDoc = await docRef.get();
      final currentData = currentDoc.data() as Map<String, dynamic>?;

      // ── Build history list ──
      List<dynamic> history = [];
      if (currentData != null) {
        // Carry forward any existing history entries
        if (currentData.containsKey('history') &&
            currentData['history'] is List) {
          history = List.from(currentData['history']);
        }

        // Append the OLD values as a new history entry
        history.add({
          'title': currentData['title'],
          'amount': currentData['amount'],
          'type': currentData['type'],
          'date': currentData['date'],       // already a Timestamp
          'editedAt': Timestamp.now(),       // when this edit happened
        });
      }

      // ── Build updated fields ──
      final updateData = <String, dynamic>{
        'title': title,
        'amount': amount,
        'type': type,
        'accountId': accountId,
        'accountName': accountName ?? '',
        'history': history,
      };

      if (date != null) {
        updateData['date'] = Timestamp.fromDate(date);
      }

      // ── Write to Firestore ──
      await docRef.update(updateData);
    } catch (_) {
      // Silently fail — Firestore offline cache will retry
    }
  }

  // ── Fire & forget — delete runs in background ──
  void deleteTransaction(String docId) {
    // Run in background — no await, no blocking
    _transactions.doc(docId).delete();
  }

  Map<String, double> calculateTotals(List<DocumentSnapshot> docs) {
    double totalIn = 0;
    double totalOut = 0;

    for (var doc in docs) {
      if (doc['type'] == 'cash_in') {
        totalIn += (doc['amount'] as num).toDouble();
      } else {
        totalOut += (doc['amount'] as num).toDouble();
      }
    }

    return {
      'totalIn': totalIn,
      'totalOut': totalOut,
      'balance': totalIn - totalOut,
    };
  }
}