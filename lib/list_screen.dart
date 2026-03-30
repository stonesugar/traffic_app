import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'excel_service.dart';
import 'log_screen.dart';

class ViolationListScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onEditTriggered;
  const ViolationListScreen({super.key, required this.onEditTriggered});

  @override
  State<ViolationListScreen> createState() => _ViolationListScreenState();
}

class _ViolationListScreenState extends State<ViolationListScreen> {
  // --- 狀態控制變數 ---
  String _searchQuery = ""; // 搜尋關鍵字
  String _selectedStatus = "全部"; // 篩選狀態 (全部/尚未定案)
  bool _isExporting = false; // 是否正在匯出中 (控制按鈕狀態)
  bool _isLoggedIn = false; // 管理員登入狀態

  final TextEditingController _searchCtrl = TextEditingController();

  // --- 分頁控制 ---
  int _currentPage = 1; // 當前頁碼
  final int _itemsPerPage = 25; // 每頁顯示筆數 (配合精簡卡片調高至 25)

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- 🔐 管理員登入驗證 (stone / 661222) ---
  void _showLoginDialog() {
    final TextEditingController userCtrl = TextEditingController();
    final TextEditingController passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('管理員登入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: '帳號'),
            ),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密碼'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (userCtrl.text == 'stone' && passCtrl.text == '661222') {
                setState(() => _isLoggedIn = true);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🔓 登入成功，管理權限已開啟')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ 帳號或密碼錯誤'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('登入'),
          ),
        ],
      ),
    );
  }

  // --- 🧠 核心過濾邏輯：處理搜尋與「尚未定案」篩選 ---
  List<QueryDocumentSnapshot> _getFilteredDocs(
    List<QueryDocumentSnapshot> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // 1. 關鍵字過濾 (不分大小寫，掃描多個欄位)
      final query = _searchQuery.trim().toLowerCase();
      final searchableText = [
        data['caseNo'],
        data['plateNo'],
        data['location'],
        data['facts'],
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' ');

      bool matchesSearch = searchableText.contains(query);

      // 2. 狀態篩選：判斷 result 欄位是否為空白/null
      bool matchesStatus = true;
      if (_selectedStatus == "尚未定案") {
        final res = data['result'];
        // 判定為尚未定案的條件：null、空字串、或是只有空格
        matchesStatus = (res == null || res.toString().trim().isEmpty);
      }

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '案件檢索',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // 權限控管：未登入顯示鎖頭，已登入顯示管理工具
          if (!_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded),
              onPressed: _showLoginDialog,
            ),
          if (_isLoggedIn) ...[
            IconButton(
              icon: const Icon(Icons.file_upload_rounded),
              onPressed: _handleImport,
              tooltip: '匯入',
            ),
            _isExporting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.file_download_rounded),
                    onPressed: _handleExport,
                    tooltip: '匯出',
                  ),
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OperationLogScreen(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              onPressed: () => setState(() => _isLoggedIn = false),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(), // 頂部搜尋與篩選列
          Expanded(child: _buildMainList()), // 資料清單主體
        ],
      ),
    );
  }

  // --- 🔍 搜尋列 UI：搜尋框與篩選選單並排 ---
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜尋車牌/案號/地點...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 1;
              }),
            ),
          ),
          const SizedBox(width: 10),
          // 狀態篩選下拉選單
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                isDense: true,
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                items: ['全部', '尚未定案']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedStatus = v!;
                  _currentPage = 1;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 📄 清單主體：結合 Firebase 與 分頁邏輯 ---
  Widget _buildMainList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('violations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('連線錯誤: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        // 1. 套用搜尋與篩選邏輯
        final filteredDocs = _getFilteredDocs(snapshot.data!.docs);
        if (filteredDocs.isEmpty) return _buildEmptyState();

        // 2. 計算分頁
        int totalItems = filteredDocs.length;
        int totalPages = (totalItems / _itemsPerPage).ceil();
        if (_currentPage > totalPages) _currentPage = totalPages;
        int startIndex = (_currentPage - 1) * _itemsPerPage;
        int endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);
        final paginatedDocs = filteredDocs.sublist(startIndex, endIndex);

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: paginatedDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      paginatedDocs[index].data() as Map<String, dynamic>;
                  return _buildSlidableCard(data);
                },
              ),
            ),
            _buildPaginationControls(totalPages, totalItems), // 分頁控制列
          ],
        );
      },
    );
  }

  // --- 🃏 高密度卡片 UI ---
  Widget _buildViolationCard(BuildContext context, Map<String, dynamic> data) {
    final bool isUnfinished =
        data['result'] == null || data['result'].toString().trim().isEmpty;
    final bool isSuccess = data['result'] == '舉發';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        // 如果尚未定案，邊框顏色加深
        side: BorderSide(
          color: isUnfinished ? Colors.orange[200]! : Colors.grey[200]!,
        ),
      ),
      // 尚未定案的卡片給予淡淡的背景色
      color: isUnfinished
          ? Colors.orange[50]?.withValues(alpha: 0.3)
          : Colors.white,
      child: ListTile(
        dense: true, // 高密度模式，減少高度
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isUnfinished
                ? Colors.orange[50]
                : (isSuccess ? Colors.green[50] : Colors.red[50]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isUnfinished
                ? Icons.pending_actions_rounded
                : (isSuccess
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded),
            color: isUnfinished
                ? Colors.orange[700]
                : (isSuccess ? Colors.green[700] : Colors.red[700]),
            size: 20,
          ),
        ),
        title: Text(
          '車牌: ${data['plateNo'] ?? "未知"}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '案號: ${data['caseNo']}\n日期: ${_formatDate(data['violationDate'])}',
          style: const TextStyle(fontSize: 12, height: 1.2),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () => _showDetailDialog(context, data),
      ),
    );
  }

  // --- 📭 空狀態 UI ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('查無相關案件紀錄', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- 🔢 分頁控制列 UI ---
  Widget _buildPaginationControls(int totalPages, int totalItems) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '共 $totalItems 筆',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Text(
                '$_currentPage / $totalPages',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 🛠 其他功能性方法 (Slidable, 刪除, 匯入匯出, 彈窗) ---

  Widget _buildSlidableCard(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(data['caseNo']),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.5,
          children: [
            SlidableAction(
              onPressed: (_) => widget.onEditTriggered(data),
              backgroundColor: Colors.blue,
              icon: Icons.edit_rounded,
              label: '修改',
            ),
            SlidableAction(
              onPressed: (context) => _confirmDelete(context, data['caseNo']),
              backgroundColor: Colors.red,
              icon: Icons.delete_rounded,
              label: '刪除',
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: _buildViolationCard(context, data),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String caseNo) async {
    final bool? res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除案號 $caseNo 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (res == true) {
      await FirebaseFirestore.instance
          .collection('violations')
          .doc(caseNo)
          .delete();
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('violations')
          .get();
      await ExcelService.exportToExcel(snapshot.docs);
      await _addDetailedLog(
        type: '匯出',
        status: '成功',
        details: '匯出 ${snapshot.docs.length} 筆',
      );
    } catch (e) {
      debugPrint('匯出失敗: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (result == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final file = result.files.first;
      ImportResult importResult = (file.extension == 'csv')
          ? await ExcelService.importCsv(file.bytes!)
          : await ExcelService.importExcel(file.bytes!);

      final firestore = FirebaseFirestore.instance;
      for (final item in importResult.data) {
        await firestore
            .collection('violations')
            .doc(item['caseNo'])
            .set(item, SetOptions(merge: true));
      }
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 成功匯入 ${importResult.data.length} 筆！')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 匯入失敗: $e')));
    }
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('案件詳細資訊'),
        content: SelectionArea(
          // 🚩 支援長按文字複製
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('案號', data['caseNo']),
                _infoRow('車牌', data['plateNo']),
                _infoRow(
                  '結果',
                  data['result'],
                  color: data['result'] == '成功' ? Colors.green : Colors.red,
                ),
                _infoRow(
                  '違規地點',
                  '${data['city'] ?? ''}${data['district'] ?? ''}${data['location'] ?? ''}',
                ),
                _infoRow('違規事實', data['facts']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, dynamic value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text('${value ?? "無"}', style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  Future<void> _addDetailedLog({
    required String type,
    required String status,
    required String details,
  }) async {
    await FirebaseFirestore.instance.collection('operation_logs').add({
      'type': type,
      'status': status,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _formatDate(dynamic date) {
    if (date == null) return '無';
    return date.toString().split('T')[0].replaceAll('-', '/');
  }
}
