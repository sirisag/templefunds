import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/theme/app_theme.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/auth/screens/login_screen.dart';
import 'package:templefunds/features/auth/screens/welcome_screen.dart';
import 'package:templefunds/features/auth/screens/pin_screen.dart';
import 'package:templefunds/features/home/screens/admin_home_screen.dart';
import 'package:templefunds/features/home/screens/master_home_screen.dart';
import 'package:templefunds/features/home/screens/member_home_screen.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';

// A global key for the navigator, allowing access from anywhere in the app.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Ensure that widgets are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize date formatting for all locales, especially for Thai ('th').
  await initializeDateFormatting('th');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColorName = ref.watch(themeSeedColorProvider).asData?.value;

    Color getSeedColor(String? colorName) {
      switch (colorName) {
        case 'blue':
          return Colors.blue;
        case 'green':
          return Colors.green;
        case 'purple':
          return Colors.purple;
        case 'teal':
          return Colors.teal;
        case 'brown':
          return Colors.brown;
        default:
          return Colors.deepOrange;
      }
    }

    return MaterialApp(
      navigatorKey: navigatorKey, // Assign the global key to the MaterialApp
      title: 'Temple Funds Management',
      theme: AppTheme.getTheme(getSeedColor(themeColorName)),
      // Add localization support for month_year_picker and general date formatting
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th'), // Your primary locale
      ],
      locale: const Locale('th', 'TH'),
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
        if (user?.role == UserRole.Admin) {
          // ผู้ดูแลระบบ
          return const AdminHomeScreen();
        } else if (user?.role == UserRole.Master) {
          // เจ้าอาวาส
          return const MasterHomeScreen();
        } else {
          // พระลูกวัด (Monk)
          return const MemberHomeScreen();
        }
      case AuthStatus.requiresPin:
      case AuthStatus.requiresPinSetup:
        return const PinScreen(); // This screen will handle both setup and verification
      case AuthStatus.requiresLogin: // สถานะใหม่
        return const LoginScreen();
      case AuthStatus.loggedOut:
      default:
        return const WelcomeScreen();
    }
  }
}
