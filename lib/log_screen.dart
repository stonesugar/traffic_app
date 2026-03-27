import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OperationLogScreen extends StatelessWidget {
  const OperationLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('操作紀錄查詢'), centerTitle: true),
      body: SelectionArea(
        // 🚩 讓頁面所有文字可被複製
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('operation_logs')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final logs = snapshot.data!.docs;

            return ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (ctx, i) =>
                  Divider(height: 1, indent: 70, color: Colors.grey[200]),
              itemBuilder: (ctx, i) {
                final log = logs[i].data() as Map<String, dynamic>;
                final bool isSuccess = log['status'] == '成功';
                final List errors = log['errorList'] ?? [];
                final DateTime? time = (log['timestamp'] as Timestamp?)
                    ?.toDate();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSuccess
                        ? Colors.green[50]
                        : Colors.red[50],
                    child: Icon(
                      log['type'] == '匯入'
                          ? Icons.upload_file_rounded
                          : Icons.download_done_rounded,
                      color: isSuccess ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  title: Text(
                    '${log['type']} - ${log['status']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${log['details']}\n時間: ${time?.toString().split('.')[0] ?? '紀錄中...'}',
                  ),
                  trailing: errors.isNotEmpty
                      ? const Icon(Icons.error_outline, color: Colors.orange)
                      : null,
                  isThreeLine: true,
                  onTap: () {
                    // 🚩 點擊顯示詳細錯誤清單
                    if (errors.isNotEmpty) {
                      _showErrorDialog(context, errors);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // 錯誤清單彈出視窗
  void _showErrorDialog(BuildContext context, List errors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('詳細錯誤清單'),
        content: SizedBox(
          width: double.maxFinite,
          // 🚩 關鍵修正：在這裡加上 SelectionArea，讓彈出視窗內的文字可選取複製
          child: SelectionArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: errors.length,
              itemBuilder: (c, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '• ${errors[i]}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}
