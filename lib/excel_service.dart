import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart'; // 🚩 引入 CSV 套件
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

class ImportResult {
  final List<Map<String, dynamic>> data;
  final List<String> errors;
  ImportResult(this.data, this.errors);
}

class ExcelService {
  // ==========================================
  // 🟢 新增：CSV 匯入功能 (最穩定、防彈)
  // ==========================================
  static Future<ImportResult> importCsv(List<int> bytes) async {
    List<Map<String, dynamic>> importedData = [];
    List<String> errorLogs = [];

    try {
      if (bytes.isEmpty) throw '檔案內容是空的';

      // 1. 將 Bytes 解碼為字串 (允許畸形字元防止當機)
      final String csvString = utf8.decode(bytes, allowMalformed: true);

      // 2. 解析 CSV 字串為二維陣列
      final List<List<dynamic>> rows = const CsvToListConverter().convert(
        csvString,
      );

      if (rows.isEmpty) throw 'CSV 內無資料';

      // 3. 逐行讀取 (從 index 1 開始，跳過標題)
      for (int i = 1; i < rows.length; i++) {
        var row = rows[i];
        int rowNum = i + 1;

        // 若整行都是空的則跳過
        if (row.isEmpty || row.join('').trim().isEmpty) continue;

        String caseNo = _safeCsvGet(row, 0);
        if (caseNo.isEmpty) {
          errorLogs.add('第 $rowNum 行：案號缺失，已略過此列');
          continue;
        }

        try {
          importedData.add({
            'caseNo': caseNo,
            'issueDate': _safeCsvGet(row, 1),
            'plateNo': _safeCsvGet(row, 2),
            'result': _safeCsvGet(row, 3),
            'fine': int.tryParse(_safeCsvGet(row, 4)) ?? 0,
            'vehicleType': _safeCsvGet(row, 5),
            'city': _safeCsvGet(row, 6),
            'district': _safeCsvGet(row, 7),
            'violationDate': _safeCsvGet(row, 8),
            'violationTime': _safeCsvGet(row, 9),
            'location': _safeCsvGet(row, 10),
            'facts': _safeCsvGet(row, 11),
            'handlingUnit': _safeCsvGet(row, 12),
            'unissuedReason': _safeCsvGet(row, 13),
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          errorLogs.add('第 $rowNum 行：資料解析異常 ($e)');
        }
      }
    } catch (e, stackTrace) {
      errorLogs.add('CSV 解析嚴重錯誤: $e');
      errorLogs.add('錯誤位置: ${stackTrace.toString().split('\n').first}');
    }

    return ImportResult(importedData, errorLogs);
  }

  // ==========================================
  // 🔵 原本的 XLSX 匯入功能 (維持原樣)
  // ==========================================
  static Future<ImportResult> importExcel(List<int> bytes) async {
    List<Map<String, dynamic>> importedData = [];
    List<String> errorLogs = [];

    try {
      if (bytes.isEmpty) throw '檔案內容是空的';
      if (bytes.length < 4 || bytes[0] != 80 || bytes[1] != 75) {
        throw '檔案格式異常！請確認這是否真的是 XLSX 檔案。';
      }

      final safeBytes = List<int>.from(bytes);
      var excel = Excel.decodeBytes(safeBytes);

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        var rows = sheet.rows;
        for (int i = 1; i < rows.length; i++) {
          var row = rows[i];
          int rowNum = i + 1;

          if (row.isEmpty) continue;

          String caseNo = _safeGet(row, 0);
          if (caseNo.isEmpty) {
            errorLogs.add('第 $rowNum 行：案號缺失，已略過此列');
            continue;
          }

          try {
            importedData.add({
              'caseNo': caseNo,
              'issueDate': _safeGet(row, 1),
              'plateNo': _safeGet(row, 2),
              'result': _safeGet(row, 3),
              'fine': int.tryParse(_safeGet(row, 4)) ?? 0,
              'vehicleType': _safeGet(row, 5),
              'city': _safeGet(row, 6),
              'district': _safeGet(row, 7),
              'violationDate': _safeGet(row, 8),
              'violationTime': _safeGet(row, 9),
              'location': _safeGet(row, 10),
              'facts': _safeGet(row, 11),
              'handlingUnit': _safeGet(row, 12),
              'unissuedReason': _safeGet(row, 13),
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            errorLogs.add('第 $rowNum 行：資料解析異常 ($e)');
          }
        }
      }
    } catch (e, stackTrace) {
      errorLogs.add('XLSX 讀取嚴重錯誤: $e');
      errorLogs.add('錯誤位置: ${stackTrace.toString().split('\n').first}');
    }

    return ImportResult(importedData, errorLogs);
  }

  // ==========================================
  // 🟡 匯出功能與輔助方法
  // ==========================================
  static Future<void> exportToExcel(List<QueryDocumentSnapshot> docs) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    List<String> headers = [
      '案號',
      '舉發日期',
      '車牌號碼',
      '結果',
      '罰鍰',
      '車種',
      '縣市',
      '區域',
      '違規日期',
      '違規時間',
      '違規地點',
      '違規事實',
      '承辦單位',
      '不舉發原因',
    ];
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      sheetObject.appendRow([
        TextCellValue(data['caseNo']?.toString() ?? ''),
        TextCellValue(data['issueDate']?.toString().split('T')[0] ?? ''),
        TextCellValue(data['plateNo']?.toString() ?? ''),
        TextCellValue(data['result']?.toString() ?? ''),
        IntCellValue(int.tryParse(data['fine']?.toString() ?? '0') ?? 0),
        TextCellValue(data['vehicleType']?.toString() ?? ''),
        TextCellValue(data['city']?.toString() ?? ''),
        TextCellValue(data['district']?.toString() ?? ''),
        TextCellValue(data['violationDate']?.toString().split('T')[0] ?? ''),
        TextCellValue(data['violationTime']?.toString() ?? ''),
        TextCellValue(data['location']?.toString() ?? ''),
        TextCellValue(data['facts']?.toString() ?? ''),
        TextCellValue(data['handlingUnit']?.toString() ?? ''),
        TextCellValue(data['unissuedReason']?.toString() ?? ''),
      ]);
    }

    var fileBytes = excel.encode();
    if (fileBytes != null) {
      final content = base64Encode(fileBytes);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = "data:application/octet-stream;base64,$content";
      anchor.download = "交通違規紀錄_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      anchor.style.display = 'none';
      web.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    }
  }

  // 給 XLSX 用的安全讀取
  static String _safeGet(List<Data?> row, int index) {
    if (index >= row.length || row[index] == null) return '';
    return row[index]?.value?.toString().trim() ?? '';
  }

  // 給 CSV 用的安全讀取
  static String _safeCsvGet(List<dynamic> row, int index) {
    if (index >= row.length || row[index] == null) return '';
    return row[index].toString().trim();
  }
}
