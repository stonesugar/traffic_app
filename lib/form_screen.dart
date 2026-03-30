import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // 🚩 記得要匯入這個才能用 TextInputFormatter

class ViolationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData; // 修改模式的初始資料
  final VoidCallback onSaveComplete; // 儲存成功回呼
  final VoidCallback onCancel; // 取消修改回呼
  final bool isLoggedIn; // 全域登入狀態
  final VoidCallback onLoginSuccess; // 登入成功回呼

  const ViolationFormScreen({
    super.key,
    this.initialData,
    required this.onSaveComplete,
    required this.onCancel,
    required this.isLoggedIn,
    required this.onLoginSuccess,
  });

  @override
  State<ViolationFormScreen> createState() => _ViolationFormScreenState();
}

class _ViolationFormScreenState extends State<ViolationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- 文字輸入控制器 ---
  final _caseNoCtrl = TextEditingController();
  final _plateNoCtrl = TextEditingController();
  final _fineCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _factsCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _officerCtrl = TextEditingController();

  // --- 狀態變數 ---
  DateTime? _issueDate;
  DateTime? _violationDate;
  TimeOfDay? _violationTime;
  String? _selectedResult;
  String? _selectedVehicleType;
  String? _selectedCity;
  String? _selectedDistrict;

  final List<String> _results = ['舉發', '失敗'];
  final List<String> _vehicleTypes = ['汽車', '機車'];
  final List<String> _cities = ['臺北市', '新北市', '基隆市', '桃園市', '臺中市', '高雄市'];
  final Map<String, List<String>> _districtsMap = {
    '臺北市': ['中正區', '大同區', '中山區', '文山區', '內湖區', '大安區', '松山區'],
    '新北市': ['板橋區', '三重區', '中和區', '永和區', '新店區'],
  };

  @override
  void initState() {
    super.initState();
    // 初始化時若有資料，則填充表單
    if (widget.initialData != null) {
      _fillData(widget.initialData!);
    }
  }

  @override
  void didUpdateWidget(ViolationFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當外部傳入的 initialData 改變時（例如從修改切換回新增），同步更新 UI
    if (widget.initialData != oldWidget.initialData) {
      if (widget.initialData != null) {
        _fillData(widget.initialData!);
      } else {
        _resetForm();
      }
    }
  }

  // --- 填充資料邏輯 (支援修改模式) ---
  void _fillData(Map<String, dynamic> data) {
    _caseNoCtrl.text = (data['caseNo'] ?? "").toString();
    _plateNoCtrl.text = (data['plateNo'] ?? "").toString();
    _fineCtrl.text = data['fine']?.toString() ?? '';
    _locationCtrl.text = (data['location'] ?? "").toString();
    _factsCtrl.text = (data['facts'] ?? "").toString();
    _reasonCtrl.text = (data['unissuedReason'] ?? "").toString();
    _unitCtrl.text = (data['handlingUnit'] ?? "").toString();
    _officerCtrl.text = (data['caseofficer'] ?? "").toString();

    setState(() {
      _selectedResult = data['result'];
      _selectedVehicleType = data['vehicleType'];
      _selectedCity = data['city'];
      _selectedDistrict = data['district'];

      // 解析日期：處理斜線與橫線相容性
      if (data['issueDate'] != null) {
        String dateStr = data['issueDate'].toString().replaceAll('/', '-');
        _issueDate = DateTime.tryParse(dateStr);
      }
      if (data['violationDate'] != null) {
        String dateStr = data['violationDate'].toString().replaceAll('/', '-');
        _violationDate = DateTime.tryParse(dateStr);
      }
      // 時間格式通常為字串，顯示處會處理
    });
  }

  // --- 重置表單 ---
  void _resetForm() {
    _formKey.currentState?.reset();
    _caseNoCtrl.clear();
    _plateNoCtrl.clear();
    _fineCtrl.clear();
    _locationCtrl.clear();
    _factsCtrl.clear();
    _reasonCtrl.clear();
    _unitCtrl.clear();
    _officerCtrl.clear();
    setState(() {
      _issueDate = null;
      _violationDate = null;
      _violationTime = null;
      _selectedResult = null;
      _selectedVehicleType = null;
      _selectedCity = null;
      _selectedDistrict = null;
    });
  }

  // --- 儲存資料到 Firebase ---
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = {
        'caseNo': _caseNoCtrl.text,
        'issueDate': _issueDate?.toIso8601String(),
        'plateNo': _plateNoCtrl.text,
        'handlingUnit': _unitCtrl.text,
        'caseofficer': _officerCtrl.text,
        'result': _selectedResult,
        'fine': int.tryParse(_fineCtrl.text) ?? 0,
        'vehicleType': _selectedVehicleType,
        'city': _selectedCity,
        'district': _selectedDistrict,
        'violationDate': _violationDate?.toIso8601String(),
        'violationTime': _violationTime?.format(context),
        'location': _locationCtrl.text,
        'facts': _factsCtrl.text,
        'unissuedReason': _selectedResult == '失敗' ? _reasonCtrl.text : '',
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.initialData == null)
          'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('violations')
          .doc(_caseNoCtrl.text)
          .set(data, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context); // 關閉進度條
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('🎉 儲存成功！')));
      _resetForm();
      widget.onSaveComplete();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 儲存失敗: $e')));
    }
  }

  // --- 🔐 驗證彈窗 ---
  void _showLoginDialog() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('管理員權限驗證'),
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
                widget.onLoginSuccess();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('❌ 驗證失敗')));
              }
            },
            child: const Text('驗證'),
          ),
        ],
      ),
    );
  }

  // --- 🔏 鎖定畫面 UI ---
  Widget _buildLockedUI() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_person_rounded, size: 80, color: Colors.blue[200]),
            const SizedBox(height: 20),
            const Text(
              '受限區域：資料錄入功能',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('請先驗證管理員身份後再進行操作', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _showLoginDialog,
              icon: const Icon(Icons.verified_user_rounded),
              label: const Text('立即驗證身份', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚩 檢查權限
    if (!widget.isLoggedIn) return _buildLockedUI();

    bool isEditMode = widget.initialData != null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          isEditMode ? '修改交通案件' : '新增交通案件',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildCardSection('基本資訊', [
                TextFormField(
                  controller: _caseNoCtrl,
                  readOnly: isEditMode,
                  decoration: InputDecoration(
                    labelText: '案號*',
                    helperText: isEditMode ? '修改模式下案號不可更改' : '請輸入案件編號',
                    fillColor: isEditMode ? Colors.grey[200] : Colors.white,
                    filled: true,
                  ),
                  validator: (v) => v!.isEmpty ? '請輸入案號' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedResult,
                        decoration: const InputDecoration(
                          labelText: '結果',
                          helperText: '',
                        ),
                        items: _results
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedResult = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _fineCtrl,
                        decoration: const InputDecoration(
                          labelText: '罰鍰',
                          helperText: '',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                _buildDatePicker(
                  '舉發日期*',
                  _issueDate,
                  (d) => setState(() => _issueDate = d),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _unitCtrl,
                        decoration: const InputDecoration(
                          labelText: '承辦單位',
                          helperText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _officerCtrl,
                        decoration: const InputDecoration(
                          labelText: '承辦人員',
                          helperText: '',
                        ),
                      ),
                    ),
                  ],
                ),
              ]),

              _buildCardSection('車輛與地點', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _plateNoCtrl,
                        decoration: const InputDecoration(
                          labelText: '車牌*',
                          helperText: '',
                        ),
                        validator: (v) => v!.isEmpty ? '請輸入車牌' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedVehicleType,
                        decoration: const InputDecoration(
                          labelText: '車種',
                          helperText: '',
                        ),
                        items: _vehicleTypes
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedVehicleType = v),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: const InputDecoration(
                          labelText: '縣市*',
                          helperText: '',
                        ),
                        items: _cities
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          _selectedCity = v;
                          _selectedDistrict = null;
                        }),
                        validator: (v) => v == null ? '必填' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: Key(_selectedCity ?? 'none'),
                        value: _selectedDistrict,
                        decoration: const InputDecoration(
                          labelText: '區域*',
                          helperText: '',
                        ),
                        items:
                            (_selectedCity != null &&
                                _districtsMap.containsKey(_selectedCity))
                            ? _districtsMap[_selectedCity]!
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList()
                            : [],
                        onChanged: (v) => setState(() => _selectedDistrict = v),
                        validator: (v) => v == null ? '必填' : null,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: '詳細地點',
                    helperText: '',
                  ),
                ),
              ]),

              _buildCardSection('違規詳情', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDatePicker(
                        '違規日期*',
                        _violationDate,
                        (d) => setState(() => _violationDate = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _violationTime ?? TimeOfDay.now(),
                          );
                          if (t != null) setState(() => _violationTime = t);
                        },
                        decoration: const InputDecoration(
                          labelText: '違規時間',
                          suffixIcon: Icon(Icons.access_time),
                          helperText: '',
                        ),
                        controller: TextEditingController(
                          text: _violationTime?.format(context) ?? '',
                        ),
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _factsCtrl,
                  decoration: const InputDecoration(
                    labelText: '違規事實',
                    helperText: '',
                  ),
                  maxLines: 2,
                ),
                Visibility(
                  visible: _selectedResult == '失敗',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: _reasonCtrl,
                      decoration: InputDecoration(
                        labelText: '不舉發原因*',
                        helperText: '結果為失敗時必填',
                        fillColor: Colors.red[50],
                        filled: true,
                      ),
                      validator: (v) =>
                          (_selectedResult == '失敗' && (v == null || v.isEmpty))
                          ? '請輸入原因'
                          : null,
                    ),
                  ),
                ),
              ]),

              // --- 按鈕區塊 ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: isEditMode
                    ? Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 45,
                              child: OutlinedButton(
                                onPressed: widget.onCancel,
                                child: const Text('取消修改'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed: _saveData,
                                icon: const Icon(Icons.check),
                                label: const Text('儲存修改'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[800],
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _saveData,
                          icon: const Icon(Icons.cloud_upload),
                          label: const Text(
                            '提交至 Firebase',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // --- 小工具：卡片區塊 ---
  Widget _buildCardSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  // --- 小工具：日期選取器 ---
  Widget _buildDatePicker(
    String label,
    DateTime? date,
    Function(DateTime) onPicked,
  ) {
    // 🚩 這裡要動態產生日期的文字顯示 (YYYY/MM/DD)
    final String dateString = date != null
        ? "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}"
        : "";

    return TextFormField(
      // 🚩 這裡關鍵：每次重建時將正確的日期文字塞入
      controller: TextEditingController(text: dateString)
        ..selection = TextSelection.collapsed(offset: dateString.length),
      readOnly: false, // 🚩 開啟打字功能
      keyboardType: TextInputType.number, // 🚩 強制跳出數字鍵盤
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly, // 只許數字
        DateInputFormatter(), // 🚩 掛上自動斜線工具
        LengthLimitingTextInputFormatter(10), // 限制長度
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: '可直接輸入或點選右側圖示',
        suffixIcon: IconButton(
          icon: const Icon(Icons.event),
          onPressed: () async {
            // 🚩 將彈窗功能移到圖示上，這樣點格子打字才不會一直跳彈窗
            final d = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              locale: const Locale('zh', 'TW'),
            );
            if (d != null) onPicked(d);
          },
        ),
      ),
      // 🚩 當使用者「手動打字」完畢時，即時更新日期物件
      onChanged: (value) {
        if (value.length == 10) {
          // 將 YYYY/MM/DD 轉回 YYYY-MM-DD 讓 DateTime 解析
          final parsed = DateTime.tryParse(value.replaceAll('/', '-'));
          if (parsed != null) {
            onPicked(parsed);
          }
        }
      },
      validator: (v) => date == null ? '請輸入日期' : null,
    );
  }

  @override
  void dispose() {
    _caseNoCtrl.dispose();
    _plateNoCtrl.dispose();
    _fineCtrl.dispose();
    _locationCtrl.dispose();
    _factsCtrl.dispose();
    _reasonCtrl.dispose();
    _unitCtrl.dispose();
    _officerCtrl.dispose();
    super.dispose();
  }
}

// 🚩 請把這段 class 貼在 form_screen.dart 的最下方（類別外面）
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // 如果是刪除文字，不進行自動補位
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) {
      return newValue;
    }

    String newText = text;
    // 當輸入到第 4 碼 (年) 自動加斜線
    if (text.length == 4) {
      newText = '$text/';
    }
    // 當輸入到第 7 碼 (月) 自動加斜線 (因為含第一條斜線，所以是第7位)
    else if (text.length == 7) {
      newText = '$text/';
    }

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
