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
  String _searchQuery = "";
  bool _isExporting = false;
  final TextEditingController _searchCtrl = TextEditingController();

  // --- 分頁控制變數 ---
  int _currentPage = 1;
  final int _itemsPerPage = 20;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- 詳細日誌紀錄方法 ---
  Future<void> _addDetailedLog({
    required String type,
    required String status,
    required String details,
    List<String>? errorList,
    String? fileName,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('operation_logs').add({
        'type': type,
        'status': status,
        'details': details,
        'errorList': errorList ?? [],
        'fileName': fileName ?? '未知檔案',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('日誌寫入失敗: $e');
    }
  }

  // --- 刪除確認 ---
  Future<void> _confirmDelete(BuildContext context, String caseNo) async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('確認刪除'),
          ],
        ),
        content: Text('您確定要刪除案號：$caseNo 嗎？\n此動作將無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('確認刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (isConfirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('violations')
            .doc(caseNo)
            .delete();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑 案件已成功刪除'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ 刪除失敗: $e')));
      }
    }
  }

  // --- 匯出 Excel ---
  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('violations')
          .orderBy('createdAt', descending: true)
          .get();

      await ExcelService.exportToExcel(snapshot.docs);
      await _addDetailedLog(
        type: '匯出',
        status: '成功',
        details: '匯出 ${snapshot.docs.length} 筆案件資料',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Excel 下載已觸發'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 匯出失敗: $e')));
      await _addDetailedLog(type: '匯出', status: '失敗', details: '系統錯誤: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // --- 匯入 Excel 或 CSV (雙引擎防彈版) ---
  Future<void> _handleImport() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );

    final file = result?.files.first;
    final bytes = file?.bytes;
    final fileName = file?.name ?? '未知檔案';
    final extension = file?.extension?.toLowerCase();

    if (bytes == null) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      ImportResult importResult;
      if (extension == 'csv') {
        importResult = await ExcelService.importCsv(bytes);
      } else {
        importResult = await ExcelService.importExcel(bytes);
      }

      final List<Map<String, dynamic>> importedData = importResult.data;
      final List<String> errorLogs = importResult.errors;

      if (importedData.isEmpty && errorLogs.isEmpty) throw '檔案內查無有效資料';

      final firestore = FirebaseFirestore.instance;
      int count = 0;

      if (importedData.isNotEmpty) {
        for (var i = 0; i < importedData.length; i += 500) {
          final batch = firestore.batch();
          final chunk = importedData.sublist(
            i,
            i + 500 > importedData.length ? importedData.length : i + 500,
          );

          for (final item in chunk) {
            final docRef = firestore
                .collection('violations')
                .doc(item['caseNo']);
            batch.set(docRef, item, SetOptions(merge: true));
          }
          await batch.commit();
          count += chunk.length;
        }
      }

      String finalStatus = errorLogs.isEmpty ? '成功' : '部分成功';
      await _addDetailedLog(
        type: '匯入 ($extension)',
        status: finalStatus,
        fileName: fileName,
        details: '成功匯入: $count 筆\n錯誤/略過: ${errorLogs.length} 筆',
        errorList: errorLogs,
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 成功匯入 $count 筆資料！'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      await _addDetailedLog(
        type: '匯入',
        status: '失敗',
        fileName: fileName,
        details: '系統解析崩潰: $e',
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ 匯入失敗: $e'), backgroundColor: Colors.red),
      );
    }
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
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OperationLogScreen(),
              ),
            ),
            tooltip: '查看操作日誌',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildMainList()), // 列表區域
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: '輸入關鍵字搜尋...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = "";
                      _currentPage = 1; // 清除時回到第一頁
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _currentPage = 1; // 搜尋時回到第一頁
        }),
      ),
    );
  }

  // --- 分頁版列表渲染 ---
  Widget _buildMainList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('violations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('連線錯誤: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

        // 🚩 1. 終極全欄位搜尋過濾
        final filteredDocs = docs.where((doc) {
          if (_searchQuery.trim().isEmpty) return true; // 沒輸入關鍵字就全顯示

          final data = doc.data() as Map<String, dynamic>;
          final query = _searchQuery.toLowerCase();

          // 💡 秘訣：把所有欄位(包含轉換過的時間)串成一個字串，一次性比對！
          final searchableText = [
            data['caseNo'],
            data['result'],
            data['plateNo'],
            data['vehicleType'],
            data['fine'],
            _formatDate(data['issueDate']),
            _formatDate(data['violationDate']),
            _formatTime(data['violationTime']),
            data['city'],
            data['district'],
            data['location'],
            data['facts'],
            data['handlingUnit'],
            data['unissuedReason'],
          ].map((e) => (e ?? '').toString().toLowerCase()).join(' | ');

          return searchableText.contains(query);
        }).toList();

        if (filteredDocs.isEmpty) return _buildEmptyState();

        // 2. 分頁計算
        int totalItems = filteredDocs.length;
        int totalPages = (totalItems / _itemsPerPage).ceil();

        if (_currentPage > totalPages) _currentPage = totalPages;
        if (_currentPage < 1) _currentPage = 1;

        int startIndex = (_currentPage - 1) * _itemsPerPage;
        int endIndex = startIndex + _itemsPerPage;
        if (endIndex > totalItems) endIndex = totalItems;

        final paginatedDocs = filteredDocs.sublist(startIndex, endIndex);

        // 3. 渲染
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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

  // --- 分頁控制列 UI ---
  Widget _buildPaginationControls(int totalPages, int totalItems) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
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
                color: Colors.blue[700],
                disabledColor: Colors.grey[300],
              ),
              Text(
                '$_currentPage / $totalPages',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                color: Colors.blue[700],
                disabledColor: Colors.grey[300],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidableCard(Map<String, dynamic> data) {
    final String caseNo = data['caseNo'] ?? "N/A";
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(caseNo),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.5,
          children: [
            SlidableAction(
              onPressed: (_) => widget.onEditTriggered(data),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: '修改',
            ),
            SlidableAction(
              onPressed: (context) => _confirmDelete(context, caseNo),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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

  Widget _buildViolationCard(BuildContext context, Map<String, dynamic> data) {
    final bool isSuccess = data['result'] == '成功';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSuccess ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: isSuccess ? Colors.green[700] : Colors.red[700],
          ),
        ),
        title: Text(
          '車牌: ${data['plateNo'] ?? "未知"}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '案號: ${data['caseNo']}\n日期: ${_formatDate(data['violationDate'])}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          if (!context.mounted) return;
          _showDetailDialog(context, data);
        },
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isExporting ? null : _handleImport,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('匯入檔案'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _handleExport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_isExporting ? '處理中...' : '匯出 Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('查無相關案件紀錄', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- 完整 14 欄位詳細資訊彈窗 (支援文字複製版) ---
  void _showDetailDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '案件詳細資訊',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // 🚩 關鍵修改：用 SelectionArea 包住整個內容區域，讓裡面的文字都可以被反白複製
        content: SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow('案號', data['caseNo']),
                _infoRow(
                  '結果',
                  data['result'],
                  color: data['result'] == '舉法' ? Colors.green : Colors.red,
                  isBold: true,
                ),
                const Divider(),
                _infoRow('車牌', data['plateNo']),
                _infoRow('車種', data['vehicleType']),
                _infoRow('罰鍰', '${data['fine'] ?? 0} 元'),
                const Divider(),
                _infoRow('舉發日期', _formatDate(data['issueDate'])),
                _infoRow('違規日期', _formatDate(data['violationDate'])),
                _infoRow('違規時間', _formatTime(data['violationTime'])),
                _infoRow(
                  '違規地點',
                  '${data['city'] ?? ''}${data['district'] ?? ''}${data['location'] ?? ''}',
                ),
                const Divider(),
                _infoRow('違規事實', data['facts']),
                _infoRow('承辦單位', data['handlingUnit']),
                if (data['result'] == '失敗' &&
                    (data['unissuedReason'] != null &&
                        data['unissuedReason'].toString().isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _infoRow(
                      '不舉發原因',
                      data['unissuedReason'],
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    dynamic value, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
            child: Text(
              '${value ?? "無"}',
              style: TextStyle(
                color: color,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 日期格式過濾器 ---
  String _formatDate(dynamic dateString) {
    if (dateString == null || dateString.toString().trim().isEmpty) return '無';
    return dateString.toString().split('T')[0];
  }

  // --- 時間格式過濾器 (防彈進化版) ---
  String _formatTime(dynamic timeData) {
    if (timeData == null || timeData.toString().trim().isEmpty) return '無';
    String str = timeData.toString().trim();

    if (str.contains(' ')) str = str.split(' ').last;
    if (str.contains('.')) str = str.split('.')[0];

    String digitsOnly = str.replaceAll(':', '');
    if (RegExp(r'^\d{3,4}$').hasMatch(digitsOnly)) {
      String hours = digitsOnly.substring(0, digitsOnly.length - 2);
      String minutes = digitsOnly.substring(digitsOnly.length - 2);
      return '$hours:$minutes';
    }
    return str;
  }
}
