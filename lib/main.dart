import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الاتصال بقاعدة بيانات Supabase بدلاً من SQLite
  await Supabase.initialize(
    url: 'https://fxfjuspajexuswenluuu.supabase.co',
    anonKey: 'sb_publishable_WE6y9VaRNCKXy2ORYax4pw_zXD57MHF', // تم التصحيح من publishableKey إلى anonKey
  );

  runApp(const ElsayedAccountsApp());
}

class ElsayedAccountsApp extends StatelessWidget {
  const ElsayedAccountsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابات السيد النماس',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
