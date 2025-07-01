import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/auth/screens/welcome_screen.dart';
import 'package:templefunds/features/auth/screens/admin_registration_screen.dart';
import 'package:templefunds/features/auth/screens/id2_verification_screen.dart';
import 'package:templefunds/features/auth/screens/pin_screen.dart';
import 'package:templefunds/features/home/screens/admin_home_screen.dart';
import 'package:templefunds/features/home/screens/master_home_screen.dart';
import 'package:templefunds/features/home/screens/member_home_screen.dart';

void main() async {
  // Ensure that widgets are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize date formatting for all locales, especially for Thai ('th').
  await initializeDateFormatting();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'แอปบันทึกปัจจัยวัด',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Add localization support for month_year_picker and general date formatting
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        MonthYearPickerLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th'), // Your primary locale
      ],
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // This widget will rebuild whenever the authState changes,
    // and show the correct screen.
    switch (authState.status) {
      case AuthStatus.initializing:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthStatus.loggedIn:
        final user = authState.user;
        if (user?.role == 'Admin') { // ผู้ดูแลระบบ
          return const AdminHomeScreen();
        } else if (user?.role == 'Master') { // เจ้าอาวาส
          return const MasterHomeScreen();
        } else { // พระลูกวัด (Monk)
          return const MemberHomeScreen();
        }
      case AuthStatus.requiresPin:
      case AuthStatus.requiresPinSetup:
        return const PinScreen(); // This screen will handle both setup and verification
      case AuthStatus.requiresId2:
        return const Id2VerificationScreen();
      case AuthStatus.requiresAdminRegistration:
        return const AdminRegistrationScreen();
      case AuthStatus.loggedOut:
      default:
        return const WelcomeScreen();
    }
  }
}
