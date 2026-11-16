import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/main_dashboard.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    try {
      ImagePickerPlatform.instance = ImagePickerPlugin();
    } catch (e) {
      debugPrint('Registration of ImagePickerPlugin failed: $e');
    }
  }
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCaAfkg8zLlK8gU42rDJ4zeieZ4xXtXp-k',
      appId: '1:809394357365:web:60927b7eb4a158e23f643c',
      messagingSenderId: '809394357365',
      projectId: 'open-food-app-819c2',
      authDomain: 'open-food-app-819c2.firebaseapp.com',
      storageBucket: 'open-food-app-819c2.firebasestorage.app',
    ),
  );
  runApp(const OpenFoodRestaurateurApp());
}

class OpenFoodRestaurateurApp extends StatelessWidget {
  const OpenFoodRestaurateurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Open Food Restaurateur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.darkBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.emeraldGreen),
            ),
          );
        }

        if (snapshot.hasData) {
          return const RestaurateurVerificationScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

class RestaurateurVerificationScreen extends StatefulWidget {
  const RestaurateurVerificationScreen({super.key});

  @override
  State<RestaurateurVerificationScreen> createState() => _RestaurateurVerificationScreenState();
}

class _RestaurateurVerificationScreenState extends State<RestaurateurVerificationScreen> {
  bool _isLoading = true;
  String? _error;
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _verifyRole();
  }

  Future<void> _verifyRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Non connecté");
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        throw Exception("Compte introuvable");
      }

      final data = doc.data()!;
      
      int role = 0;
      if (data['role'] is int) {
        role = data['role'] as int;
      } else if (data['role'] is String) {
        final rStr = data['role'] as String;
        if (rStr == '1' || rStr == 'restaurant_owner' || rStr == 'restaurateur') {
          role = 1;
        }
      }

      final restaurantId = data['restaurantId'] as String?;

      if (role != 1 || restaurantId == null || restaurantId.isEmpty) {
        throw Exception("Accès refusé. Ce compte n'est pas un compte restaurateur ou n'est lié à aucun restaurant.");
      }

      setState(() {
        _restaurantId = restaurantId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.emeraldGreen),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldGreen,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                  },
                  child: const Text('Retour à la connexion'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MainDashboard(restaurantId: _restaurantId!);
  }
}
