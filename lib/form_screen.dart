import 'package:flutter/material.dart'; // 匯入 Flutter 核心 UI 元件庫
import 'package:cloud_firestore/cloud_firestore.dart'; // 匯入 Firebase 資料庫套件

class ViolationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData; // 接收外部傳入的初始資料（用於修改模式）
  final VoidCallback onSaveComplete; // 儲存成功後要執行的高層級回呼函式
  final VoidCallback onCancel;

  const ViolationFormScreen({
    super.key,
    this.initialData,
    required this.onSaveComplete,
    required this.onCancel,
  });

  @override
  State<ViolationFormScreen> createState() => _ViolationFormScreenState();
}

class _ViolationFormScreenState extends State<ViolationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- 定義文字輸入控制器 ---
  final _caseNoCtrl = TextEditingController();
  final _plateNoCtrl = TextEditingController();
  final _fineCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _factsCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _officerCtrl = TextEditingController();

  // --- 定義狀態變數 ---
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
    // 🚩 修改點 1：如果一進來就有初始資料，直接呼叫填充方法
    if (widget.initialData != null) {
      _fillData(widget.initialData!);
    }
  }

  @override
  void didUpdateWidget(ViolationFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData) {
      if (widget.initialData != null) {
        _fillData(widget.initialData!);
      } else {
        _resetForm();
      }
    }
  }

  // --- 🚩 修改點 2：加強版填充邏輯，解決日期斜線崩潰問題 ---
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

      // 處理舉發日期 (斜線轉橫線防噴)
      if (data['issueDate'] != null) {
        String dateStr = data['issueDate'].toString().replaceAll('/', '-');
        _issueDate = DateTime.tryParse(dateStr);
      }
      // 處理違規日期 (斜線轉橫線防噴)
      if (data['violationDate'] != null) {
        String dateStr = data['violationDate'].toString().replaceAll('/', '-');
        _violationDate = DateTime.tryParse(dateStr);
      }

      // 處理違規時間 (如果是 2036 這種格式的防彈處理已在後續顯示處處理)
    });
  }

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
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
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
                        value:
                            _selectedResult, // 🚩 注意：Dropdown 的屬性是 value，不是 initialValue
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
                          labelText: '車種*',
                          helperText: '',
                        ),
                        items: _vehicleTypes
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedVehicleType = v),
                        validator: (v) => v == null ? '必填' : null,
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

              // 🚩 替換原本最下方的提交按鈕區塊
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: isEditMode
                    ? Row(
                        children: [
                          // --- 取消按鈕 ---
                          Expanded(
                            child: SizedBox(
                              height: 45, // 高度調小一點，比較精緻
                              child: OutlinedButton(
                                onPressed: widget.onCancel,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  side: BorderSide(color: Colors.grey[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  '取消修改',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // --- 儲存按鈕 ---
                          Expanded(
                            child: SizedBox(
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed: _saveData,
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: const Text(
                                  '儲存修改',
                                  style: TextStyle(fontSize: 15),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[800],
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        // --- 原本的新增模式按鈕 (維持全寬) ---
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    Function(DateTime) onPicked,
  ) {
    return TextFormField(
      readOnly: true,
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onPicked(d);
      },
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.event),
        helperText: '',
      ),
      controller: TextEditingController(
        text: date?.toString().split(' ')[0] ?? '',
      ),
      validator: (v) => date == null ? '必選' : null,
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
