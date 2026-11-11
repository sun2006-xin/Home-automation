import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/discover_tab.dart';
import 'screens/home_tab.dart';
import 'screens/profile_tab.dart';
import 'screens/scenes_tab.dart';
import 'services/mi_cloud_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const SmartHomeMiApp());
}

class SmartHomeMiApp extends StatefulWidget {
  final bool autoConnect;

  const SmartHomeMiApp({super.key, this.autoConnect = true});

  @override
  State<SmartHomeMiApp> createState() => _SmartHomeMiAppState();
}

class _SmartHomeMiAppState extends State<SmartHomeMiApp> {
  final MiCloudService _cloud = MiCloudService();
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoConnect) {
      _cloud.initialize();
    } else {
      _cloud.isLoadingInitial = false;
    }
  }

  @override
  void dispose() {
    _cloud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智慧家庭 App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B589),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentTab,
            children: [
              HomeTab(cloud: _cloud),
              ScenesTab(cloud: _cloud),
              DiscoverTab(cloud: _cloud),
              ProfileTab(cloud: _cloud),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.8)),
          ),
          child: NavigationBar(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF00B589).withOpacity(0.14),
            selectedIndex: _currentTab,
            onDestinationSelected: (idx) => setState(() => _currentTab = idx),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF00B589)),
                label: '米家',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded, color: Color(0xFF00B589)),
                label: '智能',
              ),
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF00B589)),
                label: '空间',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF00B589)),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
