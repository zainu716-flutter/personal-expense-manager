import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers/transaction_provider.dart';
import 'providers/account_provider.dart';
import 'providers/auth_provider.dart' as ap;
import 'add_transaction.dart';
import 'account_page.dart';
import 'mono_style.dart';
import 'indian_format.dart';
import 'calculator_widget.dart';
import 'transaction_dialogs.dart';
import 'pdf_export.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with IndianFormatMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _showCalculator = false;

  // ── Connectivity / refresh state ─────────────
  bool _isReconnecting = false;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  // ── Helpers ───────────────────────────────────
  final _dialogs = TransactionDialogs();
  final _pdfHelper = PdfExportHelper();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Pull-to-refresh ───────────────────────────
  Future<void> _onRefresh() async {
    setState(() => _isReconnecting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .get(const GetOptions(source: Source.server));
      }
    } catch (_) {
      // Silently fail — stream will still show cached data
    } finally {
      if (mounted) setState(() => _isReconnecting = false);
    }
  }

  // ── Account Selector ──────────────────────────
  void _openAccountSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, __) => AccountSelectorSheet(
          selectedAccountId: context.read<AccountProvider>().selectedAccountId,
          onAccountSelected: (id, name) {
            context.read<AccountProvider>().selectAccount(id, name);
          },
        ),
      ),
    );
  }

  // ── Export PDF ────────────────────────────────
  Future<void> _exportToPdf(
    BuildContext context,
    List<DocumentSnapshot> docs,
    double totalIn,
    double totalOut,
    double balance,
  ) async {
    final accountName = context.read<AccountProvider>().selectedAccountName;
    await _pdfHelper.exportToPdf(
      context,
      docs,
      totalIn,
      totalOut,
      balance,
      accountName,
    );
  }

  // ── Logout Confirmation ───────────────────────
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to logout?',
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
              Navigator.pop(context);
              context.read<AccountProvider>().resetSelection();
              context.read<ap.AuthProvider>().logout();
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final txnProvider = context.watch<TransactionProvider>();
    final authProvider = context.watch<ap.AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _openAccountSelector(context),
        ),
        title: txnProvider.isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search title or amount...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
                onChanged: (val) =>
                    context.read<TransactionProvider>().updateSearchQuery(val),
              )
            : Text(
                accountProvider.selectedAccountName,
                style: monoStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
        actions: [
          // ── Reconnecting spinner ──────
          if (_isReconnecting)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.green,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              txnProvider.isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              context.read<TransactionProvider>().toggleSearch();
              if (!txnProvider.isSearching) {
                _searchController.clear();
              }
            },
          ),
          if (!txnProvider.isSearching)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: const Color(0xFF2C2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) async {
                if (value == 'calculator') {
                  setState(() => _showCalculator = true);
                } else if (value == 'export_pdf') {
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final accountId = accountProvider.selectedAccountId;
                  final snapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('transactions')
                      .orderBy('date', descending: true)
                      .get();
                  final docs = accountId == null
                      ? snapshot.docs
                      : snapshot.docs
                            .where((d) => d['accountId'] == accountId)
                            .toList();
                  final totals = context
                      .read<TransactionProvider>()
                      .calculateTotals(docs);
                  if (context.mounted) {
                    _exportToPdf(
                      context,
                      docs,
                      totals['totalIn']!,
                      totals['totalOut']!,
                      totals['balance']!,
                    );
                  }
                } else if (value == 'logout') {
                  _confirmLogout(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'calculator',
                  child: Row(
                    children: const [
                      Icon(Icons.calculate, color: Colors.green, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Calculator',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'export_pdf',
                  child: Row(
                    children: const [
                      Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Export PDF',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: const [
                      Icon(Icons.logout, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Reconnecting banner ─────────
              if (_isReconnecting)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.orange.withValues(alpha: 0.15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.orange,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Syncing with server...',
                        style: monoStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              // ── User email bar ──────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.grey[900],
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.grey, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      authProvider.userEmail ?? '',
                      style: monoStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: txnProvider.getTransactionStream(
                    accountProvider.selectedAccountId,
                  ),
                  builder: (context, snapshot) {
                    // ── Loading ────────────────
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.green),
                            SizedBox(height: 16),
                            Text(
                              'Loading transactions...',
                              style: TextStyle(
                                color: Colors.grey,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // ── Empty / Error ──────────
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return Column(
                        children: [
                          _subheading(accountProvider, txnProvider),
                          _columnHeader(),
                          Expanded(
                            child: RefreshIndicator(
                              key: _refreshKey,
                              onRefresh: _onRefresh,
                              color: Colors.green,
                              backgroundColor: const Color(0xFF2C2C2C),
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.4,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.receipt_long_outlined,
                                            color: Colors.grey[700],
                                            size: 64,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No transactions yet',
                                            style: monoStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Pull down to refresh',
                                            style: monoStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _addButtons(context, accountProvider),
                          _summaryBar(0, 0, 0),
                        ],
                      );
                    }

                    final allDocs = snapshot.data!.docs;
                    final filteredDocs = txnProvider.filterDocs(allDocs);
                    final totals = txnProvider.calculateTotals(allDocs);

                    // ── Running balance map ────
                    final sortedAll = List<DocumentSnapshot>.from(allDocs)
                      ..sort((a, b) {
                        final aDate = (a['date'] as Timestamp).toDate();
                        final bDate = (b['date'] as Timestamp).toDate();
                        return aDate.compareTo(bDate);
                      });

                    double running = 0;
                    final Map<String, double> runningBalanceMap = {};
                    for (final doc in sortedAll) {
                      final amt = (doc['amount'] as num).toDouble();
                      if (doc['type'] == 'cash_in') {
                        running += amt;
                      } else {
                        running -= amt;
                      }
                      runningBalanceMap[doc.id] = running;
                    }

                    // ── Group by date ──────────
                    final Map<String, List<DocumentSnapshot>> grouped = {};
                    for (final doc in filteredDocs) {
                      final date = (doc['date'] as Timestamp).toDate();
                      final key = DateFormat('EEE, dd MMM yyyy').format(date);
                      grouped.putIfAbsent(key, () => []).add(doc);
                    }

                    final List<dynamic> items = [];
                    grouped.forEach((date, docs) {
                      items.add(date);
                      items.addAll(docs);
                    });

                    return Column(
                      children: [
                        _subheading(accountProvider, txnProvider),
                        _columnHeader(),
                        if (txnProvider.isSearching &&
                            txnProvider.searchQuery.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            color: Colors.grey[850],
                            child: Text(
                              '${filteredDocs.length} result${filteredDocs.length != 1 ? 's' : ''} found',
                              style: monoStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        Expanded(
                          child: filteredDocs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        color: Colors.grey[700],
                                        size: 56,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No results for "${txnProvider.searchQuery}"',
                                        style: monoStyle(
                                          fontSize: 15,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  key: _refreshKey,
                                  onRefresh: _onRefresh,
                                  color: Colors.green,
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  child: ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: items.length,
                                    itemBuilder: (context, index) {
                                      final item = items[index];

                                      // ── Date group header ──
                                      if (item is String) {
                                        return Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          color: const Color(0xFF2A2A2A),
                                          child: Text(
                                            item,
                                            style: monoStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade300,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }

                                      // ── Transaction row ────
                                      final doc = item as DocumentSnapshot;
                                      final date = (doc['date'] as Timestamp)
                                          .toDate();
                                      final isCashIn = doc['type'] == 'cash_in';
                                      final amt =
                                          (doc['amount'] as num).toDouble();
                                      final runBal =
                                          runningBalanceMap[doc.id] ?? 0.0;

                                      return InkWell(
                                        onTap: () =>
                                            _dialogs.showTransactionOptions(
                                              context,
                                              doc,
                                            ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey[850]!,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Row 1: Title | CashIn | CashOut
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      doc['title'],
                                                      style: monoStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      softWrap: true,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 85,
                                                    child: Text(
                                                      isCashIn
                                                          ? formatIndian(amt)
                                                          : '',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: monoStyle(
                                                        fontSize: 16,
                                                        color: Colors.green,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 85,
                                                    child: Text(
                                                      !isCashIn
                                                          ? formatIndian(amt)
                                                          : '',
                                                      textAlign:
                                                          TextAlign.right,
                                                      style: monoStyle(
                                                        fontSize: 16,
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              // Row 2: Time + Account tag | Balance
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        DateFormat(
                                                          'hh:mm a',
                                                        ).format(date),
                                                        style: monoStyle(
                                                          fontSize: 13,
                                                          color: Colors
                                                              .grey
                                                              .shade500,
                                                        ),
                                                      ),
                                                      if (accountProvider
                                                              .selectedAccountId ==
                                                          null) ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 7,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue
                                                                .withValues(
                                                                  alpha: 0.12,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  5,
                                                                ),
                                                            border: Border.all(
                                                              color: Colors.blue
                                                                  .withValues(
                                                                    alpha: 0.3,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            (doc.data()
                                                                            as Map<
                                                                              String,
                                                                              dynamic
                                                                            >)
                                                                        .containsKey(
                                                                          'accountName',
                                                                        ) &&
                                                                    doc['accountName'] !=
                                                                        null &&
                                                                    (doc['accountName']
                                                                            as String)
                                                                        .isNotEmpty
                                                                ? doc['accountName']
                                                                : 'No Account',
                                                            style: monoStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .blue
                                                                  .shade300,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  Text(
                                                    'Balance ${formatIndian(runBal)}',
                                                    style: monoStyle(
                                                      fontSize: 13,
                                                      color: runBal >= 0
                                                          ? Colors.grey.shade500
                                                          : Colors.orange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                        _addButtons(context, accountProvider),
                        _summaryBar(
                          totals['totalIn']!,
                          totals['totalOut']!,
                          totals['balance']!,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (_showCalculator)
            DraggableCalculator(
              onClose: () => setState(() => _showCalculator = false),
            ),
        ],
      ),
    );
  }

  // ── Column Header ─────────────────────────────
  Widget _columnHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Date',
              style: monoStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              'Cash In',
              textAlign: TextAlign.right,
              style: monoStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 85,
            child: Text(
              'Cash Out',
              textAlign: TextAlign.right,
              style: monoStyle(
                fontSize: 14,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subheading ────────────────────────────────
  Widget _subheading(
    AccountProvider accountProvider,
    TransactionProvider txnProvider,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey[900],
      child: Text(
        txnProvider.isSearching && txnProvider.searchQuery.isNotEmpty
            ? 'Searching: "${txnProvider.searchQuery}"'
            : accountProvider.selectedAccountId == null
            ? 'All Transactions'
            : '${accountProvider.selectedAccountName} — History',
        style: monoStyle(
          fontSize: 13,
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── Cash In / Cash Out Buttons ────────────────
  Widget _addButtons(BuildContext context, AccountProvider accountProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransaction(
                    accountId: accountProvider.selectedAccountId,
                    accountName: accountProvider.selectedAccountName,
                    initialType: 'cash_in',
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Cash In',
                style: monoStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransaction(
                    accountId: accountProvider.selectedAccountId,
                    accountName: accountProvider.selectedAccountName,
                    initialType: 'cash_out',
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Cash Out',
                style: monoStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Bar ───────────────────────────────
  Widget _summaryBar(double totalIn, double totalOut, double balance) {
    return Container(
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey[800]!, width: 1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Cash In',
                    textAlign: TextAlign.center,
                    style: monoStyle(fontSize: 13, color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatIndian(totalIn),
                    textAlign: TextAlign.center,
                    style: monoStyle(
                      fontSize: 18,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey[800]!, width: 1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Cash Out',
                    textAlign: TextAlign.center,
                    style: monoStyle(fontSize: 13, color: Colors.red),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatIndian(totalOut),
                    textAlign: TextAlign.center,
                    style: monoStyle(
                      fontSize: 18,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Text(
                    'Balance',
                    textAlign: TextAlign.center,
                    style: monoStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatIndian(balance),
                    textAlign: TextAlign.center,
                    style: monoStyle(
                      fontSize: 18,
                      color: balance >= 0 ? Colors.white : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}