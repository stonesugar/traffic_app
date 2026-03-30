import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'form_screen.dart';
import 'list_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCyT4bj1ERI46PTFMyyneLVY1lM_mVG_y8",
      appId: "1:184154590084:web:0c45b588fe55f7b03fabd1",
      messagingSenderId: "184154590084",
      projectId: "traffic-violation-app-b806d",
      authDomain: "traffic-violation-app-b806d.firebaseapp.com",
      storageBucket: "traffic-violation-app-b806d.firebasestorage.app",
    ),
  );
  runApp(const TrafficViolationApp());
}

class TrafficViolationApp extends StatelessWidget {
  const TrafficViolationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'TW'), // 繁體中文
      ],
      locale: const Locale('zh', 'TW'), // 強制設定為中文

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        // 設定全域的字體，讓 Web 版中文更清晰
        fontFamily: 'PingFang TC',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1; // 預設顯示「案件檢索」
  bool _isLoggedIn = false; // 🚩 全域登入狀態
  Map<String, dynamic>? _dataToEdit; // 儲存要修改的資料

  // 🔐 登入成功的回呼方法
  void _onLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  // 🔓 登出的回呼方法
  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  // 🔄 處理「修改」按鈕點擊
  void _jumpToEdit(Map<String, dynamic> data) {
    setState(() {
      _dataToEdit = data;
      _currentIndex = 0; // 切換到「資料錄入」分頁
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🚩 在這裡定義頁面清單，並將狀態傳進去
    final List<Widget> pages = [
      // 1. 資料錄入頁
      ViolationFormScreen(
        initialData: _dataToEdit,
        isLoggedIn: _isLoggedIn, // 傳入登入狀態
        onLoginSuccess: _onLoginSuccess, // 傳入登入方法
        onSaveComplete: () {
          setState(() {
            _dataToEdit = null;
            _currentIndex = 1; // 儲存完跳回清單
          });
        },
        onCancel: () {
          setState(() {
            _dataToEdit = null;
            _currentIndex = 1; // 取消後跳回清單
          });
        },
      ),
      // 2. 案件檢索頁
      ViolationListScreen(
        onEditTriggered: _jumpToEdit,
        isLoggedIn: _isLoggedIn, // 傳入登入狀態
        onLoginSuccess: _onLoginSuccess, // 傳入登入方法
        onLogout: _onLogout, // 傳入登出方法
      ),
    ];

    return Scaffold(
      // 使用 IndexedStack 凍結頁面狀態，切換時不會重置
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // 如果從錄入頁主動切換走，清空編輯資料，恢復為「新增模式」
            if (index == 1) _dataToEdit = null;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_task), label: '資料錄入'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '案件檢索'),
        ],
      ),
    );
  }
}
