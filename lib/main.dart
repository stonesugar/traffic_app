import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'form_screen.dart';
import 'list_screen.dart';

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
  // 🚩 關鍵修改：將初始值設為 1，App 一進來就是「案件檢索」
  int _currentIndex = 1;

  // 用於暫存從清單頁傳回來的修改資料
  Map<String, dynamic>? _dataToEdit;

  // 定義跳轉並修改的方法
  void _jumpToEdit(Map<String, dynamic> data) {
    setState(() {
      _dataToEdit = data; // 設定要修改的資料
      _currentIndex = 0; // 跳回第一個分頁 (資料錄入) 進行編輯
    });
  }

  @override
  Widget build(BuildContext context) {
    // 定義分頁內容
    final List<Widget> pages = [
      ViolationFormScreen(
        initialData: _dataToEdit,
        onSaveComplete: () {
          setState(() {
            _dataToEdit = null;
            _currentIndex = 1; // 儲存完自動跳回檢索頁，體驗更好
          });
        },
      ),
      ViolationListScreen(onEditTriggered: _jumpToEdit),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // 如果使用者是手動切換到檢索頁，清空編輯暫存
            if (index == 1) _dataToEdit = null;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_task),
            activeIcon: Icon(Icons.playlist_add_check_circle_rounded),
            label: '資料錄入',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.manage_search_rounded),
            label: '案件檢索',
          ),
        ],
      ),
    );
  }
}
