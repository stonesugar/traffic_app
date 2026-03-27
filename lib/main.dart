import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'form_screen.dart'; // 確保路徑正確
import 'list_screen.dart'; // 確保路徑正確

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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
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
  int _currentIndex = 0;

  // 【關鍵 1】用於暫存從清單頁傳回來的修改資料
  Map<String, dynamic>? _dataToEdit;

  // 【關鍵 2】定義跳轉並修改的方法
  void _jumpToEdit(Map<String, dynamic> data) {
    setState(() {
      _dataToEdit = data; // 設定要修改的資料
      _currentIndex = 0; // 強制跳回第一個分頁 (錄入頁)
    });
  }

  @override
  Widget build(BuildContext context) {
    // 【關鍵 3】在建立頁面時，把參數傳進去
    final List<Widget> pages = [
      ViolationFormScreen(
        initialData: _dataToEdit, // 傳入初始資料 (新增時為 null)
        onSaveComplete: () {
          // 當表單儲存成功後，執行這個回呼
          setState(() => _dataToEdit = null); // 清空修改狀態，變回新增模式
        },
      ),
      ViolationListScreen(
        onEditTriggered: _jumpToEdit, // 把跳轉方法傳給清單頁
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // 如果使用者手動切換分頁，通常建議清空修改狀態
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
