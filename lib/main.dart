import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart' as ap;
import 'providers/transaction_provider.dart';
import 'providers/account_provider.dart';
import 'home_page.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ── Enable Firestore offline persistence ──────
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => ap.AuthProvider()),
        ChangeNotifierProvider(
            create: (_) => AccountProvider()),
        ChangeNotifierProvider(
            create: (_) => TransactionProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                  color: Colors.green),
            ),
          );
        }

        // Logged in
        if (snapshot.hasData) {
          return _LoadAccountWrapper();
        }

        // Not logged in
        return LoginPage();
      },
    );
  }
}

// Loads saved account then shows HomePage
class _LoadAccountWrapper extends StatefulWidget {
  @override
  State<_LoadAccountWrapper> createState() =>
      _LoadAccountWrapperState();
}

class _LoadAccountWrapperState
    extends State<_LoadAccountWrapper> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await context
        .read<AccountProvider>()
        .loadSavedAccount();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
              color: Colors.green),
        ),
      );
    }
    return HomePage();
  }
}