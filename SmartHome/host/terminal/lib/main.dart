import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/terminal_state.dart';
import 'ui/theme/terminal_theme.dart';
import 'ui/terminal_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化中文日期语言包
  await initializeDateFormatting('zh_CN', null);

  // 2. 启用 Android 沉浸式 Kiosk 模式 (隐藏顶部状态栏与底部虚拟三键)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  // 3. 锁定横屏壁挂方向 (横向 2160x1080 宽画幅体验)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const TerminalApp());
}

class TerminalApp extends StatefulWidget {
  const TerminalApp({super.key});

  @override
  State<TerminalApp> createState() => _TerminalAppState();
}

class _TerminalAppState extends State<TerminalApp> {
  late final TerminalState _terminalState;

  @override
  void initState() {
    super.initState();
    _terminalState = TerminalState();
  }

  @override
  void dispose() {
    _terminalState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智慧家庭壁挂终端',
      debugShowCheckedModeBanner: false,
      theme: TerminalTheme.darkTheme,
      home: TerminalMainScreen(state: _terminalState),
    );
  }
}
