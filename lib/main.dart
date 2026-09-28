import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'services/firebase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/medicine_provider.dart';
import 'providers/device_provider.dart';
import 'providers/log_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(const SmartMedicineApp());
}

class SmartMedicineApp extends StatelessWidget {
  const SmartMedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(firebaseService)),
        ChangeNotifierProvider(create: (_) => MedicineProvider(firebaseService)),
        ChangeNotifierProvider(create: (_) => DeviceProvider(firebaseService)),
        ChangeNotifierProvider(create: (_) => LogProvider(firebaseService)),
      ],
      child: MaterialApp(
        title: 'Smart Medicine Companion',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isAuthenticated) {
      return const DashboardScreen();
    } else {
      return const AuthScreen();
    }
  }
}
