import 'package:flutter/material.dart';
import 'dashboard/dashboard_screen.dart';
import 'persons/persons_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // تم إزالة TripsScreen من هنا لتتطابق الواجهة مع الصورة التي تحتوي على 3 تبويبات فقط
    _pages = [
      DashboardScreen(onNavigateTab: (index) => setState(() => _currentIndex = index)),
      const PersonsScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) async {
            // التحقق إذا كان المستخدم يضغط على تبويب "الإعدادات" (التبويب رقم 2)
            if (idx == 2) {
              final isAuthorized = await SettingsScreen.verifyPassword(context);
              // لن يتم تغيير الصفحة إلا إذا كانت كلمة المرور صحيحة
              if (isAuthorized) {
                setState(() => _currentIndex = idx);
              }
            } else {
              // التنقل الطبيعي لباقي التبويبات (الرئيسية والأطراف)
              setState(() => _currentIndex = idx);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'الأطراف',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}
