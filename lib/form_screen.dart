import 'package:flutter/material.dart'; // 匯入 Flutter 核心 UI 元件庫
import 'package:cloud_firestore/cloud_firestore.dart'; // 匯入 Firebase 資料庫套件

class ViolationFormScreen extends StatefulWidget {
  // 定義一個可變狀態的頁面元件
  final Map<String, dynamic>? initialData; // 接收外部傳入的初始資料（用於修改模式）
  final VoidCallback onSaveComplete; // 儲存成功後要執行的高層級回呼函式

  const ViolationFormScreen({
    // 建構子
    super.key, // 傳遞 key 給父類別
    this.initialData, // 初始化初始資料
    required this.onSaveComplete, // 強制要求傳入儲存完成的回呼
  });

  @override
  State<ViolationFormScreen> createState() => _ViolationFormScreenState(); // 建立對應的狀態類別
}

class _ViolationFormScreenState extends State<ViolationFormScreen> {
  // 狀態類別的具體實作
  final _formKey = GlobalKey<FormState>(); // 建立一個唯一的 Key 用來控制和驗證整個表單

  // --- 定義文字輸入控制器 (用來讀取或寫入輸入框的文字) ---
  final _caseNoCtrl = TextEditingController(); // 案號輸入控制器
  final _plateNoCtrl = TextEditingController(); // 車牌輸入控制器
  final _fineCtrl = TextEditingController(); // 罰鍰金額輸入控制器
  final _locationCtrl = TextEditingController(); // 違規地點輸入控制器
  final _factsCtrl = TextEditingController(); // 違規事實輸入控制器
  final _reasonCtrl = TextEditingController(); // 不舉發原因輸入控制器
  final _unitCtrl = TextEditingController(); // 承辦單位輸入控制器
  final _officerCtrl = TextEditingController(); // 承辦人員輸入控制器

  // --- 定義狀態變數 (儲存日期、時間與下拉選單的選擇) ---
  DateTime? _issueDate; // 儲存選取的舉發日期
  DateTime? _violationDate; // 儲存選取的違規日期
  TimeOfDay? _violationTime; // 儲存選取的違規時間
  String? _selectedResult; // 儲存下拉選單選中的結果 (舉發/失敗)
  String? _selectedVehicleType; // 儲存下拉選單選中的車種 (汽車/機車)
  String? _selectedCity; // 儲存選中的縣市
  String? _selectedDistrict; // 儲存選中的區域

  // --- 定義選單的選項內容 ---
  final List<String> _results = ['舉發', '失敗']; // 結果的選項清單
  final List<String> _vehicleTypes = ['汽車', '機車']; // 車種的選項清單
  final List<String> _cities = [
    '臺北市',
    '新北市',
    '基隆市',
    '桃園市',
    '臺中市',
    '高雄市',
  ]; // 縣市選項
  final Map<String, List<String>> _districtsMap = {
    // 縣市與行政區的對應地圖
    '臺北市': ['中正區', '大同區', '中山區', '文山區', '內湖區', '大安區', '松山區'], // 台北市區域
    '新北市': ['板橋區', '三重區', '中和區', '永和區', '新店區'], // 新北市區域
  };

  @override
  void initState() {
    // 元件初始化生命週期
    super.initState(); // 執行父類別初始化
    if (widget.initialData != null) {
      // 如果傳入的 initialData 不為空
      _fillData(widget.initialData!); // 呼叫填充方法將資料填入表單（進入修改模式）
    }
  }

  @override
  void didUpdateWidget(ViolationFormScreen oldWidget) {
    // 當元件屬性更新時觸發
    super.didUpdateWidget(oldWidget); // 執行父類別更新
    if (widget.initialData != oldWidget.initialData) {
      // 如果傳入的資料與舊的不同
      if (widget.initialData != null) {
        // 如果新資料不是空的
        _fillData(widget.initialData!); // 重新填充表單
      } else {
        // 如果新資料是空的
        _resetForm(); // 代表切換回新增模式，清空表單
      }
    }
  }

  void _fillData(Map<String, dynamic> data) {
    // 將 Map 資料對應到 UI 控制器的邏輯
    _caseNoCtrl.text = data['caseNo'] ?? ''; // 填入案號
    _plateNoCtrl.text = data['plateNo'] ?? ''; // 填入車牌
    _fineCtrl.text = data['fine']?.toString() ?? ''; // 填入罰鍰並轉為字串
    _locationCtrl.text = data['location'] ?? ''; // 填入地點
    _factsCtrl.text = data['facts'] ?? ''; // 填入事實
    _reasonCtrl.text = data['unissuedReason'] ?? ''; // 填入失敗原因
    _unitCtrl.text = data['handlingUnit'] ?? ''; // 填入承辦單位
    _officerCtrl.text = data['caseofficer'] ?? ''; // 填入承辦人員
    setState(() {
      // 通知框架狀態已變更，重新渲染 UI
      _selectedResult = data['result']; // 設定結果選單值
      _selectedVehicleType = data['vehicleType']; // 設定車種選單值
      _selectedCity = data['city']; // 設定縣市選單值
      _selectedDistrict = data['district']; // 設定區域選單值
      if (data['issueDate'] != null) {
        _issueDate = DateTime.parse(data['issueDate']); // 解析字串為日期物件
      }
      if (data['violationDate'] != null) {
        _violationDate = DateTime.parse(data['violationDate']); // 解析違規日期
      }
    });
  }

  void _resetForm() {
    // 重置表單為空白狀態
    _formKey.currentState?.reset(); // 重置表單狀態
    _caseNoCtrl.clear(); // 清空案號
    _plateNoCtrl.clear(); // 清空車牌
    _fineCtrl.clear(); // 清空罰鍰
    _locationCtrl.clear(); // 清空地點
    _factsCtrl.clear(); // 清空事實
    _reasonCtrl.clear(); // 清空原因
    _unitCtrl.clear(); // 清空承辦單位
    _officerCtrl.clear(); // 清空承辦人
    setState(() {
      // 更新狀態清空變數
      _issueDate = null; // 清空日期
      _violationDate = null; // 清空違規日期
      _violationTime = null; // 清空時間
      _selectedResult = null; // 清空結果選擇
      _selectedVehicleType = null; // 清空車種選擇
      _selectedCity = null; // 清空縣市
      _selectedDistrict = null; // 清空區域
    });
  }

  Future<void> _saveData() async {
    // 儲存資料的非同步方法
    if (!_formKey.currentState!.validate()) return; // 若表單驗證不通過，直接結束
    showDialog(
      // 彈出對話框
      context: context, // 當前上下文
      barrierDismissible: false, // 禁止點擊外部關閉
      builder: (c) =>
          const Center(child: CircularProgressIndicator()), // 顯示轉圈圈進度條
    );

    try {
      // 嘗試執行資料儲存
      final data = {
        // 準備要送到 Firebase 的資料 Map
        'caseNo': _caseNoCtrl.text, // 案號文字
        'issueDate': _issueDate?.toIso8601String(), // 舉發日期轉標準字串
        'plateNo': _plateNoCtrl.text, // 車牌文字
        'handlingUnit': _unitCtrl.text, // 承辦單位文字
        'caseofficer': _officerCtrl.text, // 承辦員文字
        'result': _selectedResult, // 結果選擇
        'fine': int.tryParse(_fineCtrl.text) ?? 0, // 罰鍰轉整數，失敗則給 0
        'vehicleType': _selectedVehicleType, // 車種選擇
        'city': _selectedCity, // 縣市選擇
        'district': _selectedDistrict, // 區域選擇
        'violationDate': _violationDate?.toIso8601String(), // 違規日期轉字串
        'violationTime': _violationTime?.format(context), // 違規時間格式化文字
        'location': _locationCtrl.text, // 地點文字
        'facts': _factsCtrl.text, // 事實文字
        'unissuedReason': _selectedResult == '失敗'
            ? _reasonCtrl.text
            : '', // 若失敗才存原因
        'updatedAt': FieldValue.serverTimestamp(), // 標註資料更新伺服器時間
        if (widget.initialData == null)
          'createdAt': FieldValue.serverTimestamp(), // 新增模式才加入建立時間
      };

      await FirebaseFirestore
          .instance // 呼叫 Firestore 實例
          .collection('violations') // 指向違規紀錄集合
          .doc(_caseNoCtrl.text) // 以案號作為文件 ID
          .set(data, SetOptions(merge: true)); // 寫入資料，並使用合併模式 (防止覆蓋其他可能欄位)

      if (!mounted) return; // 檢查頁面是否還在，不在則返回
      Navigator.pop(context); // 關閉讀取進度對話框
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('🎉 儲存成功！'))); // 顯示底部成功訊息
      _resetForm(); // 清空表單
      widget.onSaveComplete(); // 執行回呼，讓中控台知道處理完了
    } catch (e) {
      // 若發生錯誤
      if (!mounted) return; // 檢查頁面狀態
      Navigator.pop(context); // 關閉讀取進度條
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ 儲存失敗: $e'))); // 顯示失敗錯誤訊息
    }
  }

  @override
  Widget build(BuildContext context) {
    // 建立 UI 的核心方法
    bool isEditMode = widget.initialData != null; // 定義變數判斷是否為修改模式

    return Scaffold(
      // 使用 Scaffold 佈局
      backgroundColor: Colors.grey[100], // 設定背景為淡淡的灰色
      appBar: AppBar(
        // 設定頂部導覽列
        title: Text(
          // 設定標題文字
          isEditMode ? '修改交通案件' : '新增交通案件', // 根據模式顯示不同標題
          style: const TextStyle(fontWeight: FontWeight.bold), // 字體加粗
        ),
        centerTitle: true, // 標題置中
      ),
      body: Form(
        // 包裹表單驗證器
        key: _formKey, // 綁定 key
        child: SingleChildScrollView(
          // 讓內容超出螢幕時可以滾動
          padding: const EdgeInsets.all(16.0), // 設定四周邊距
          child: Column(
            // 垂直排列內容
            children: [
              _buildCardSection('基本資訊', [
                // 呼叫自定義小工具：基本資訊卡片
                TextFormField(
                  // 案號輸入框
                  controller: _caseNoCtrl, // 綁定控制器
                  readOnly: isEditMode, // 修改模式時，案號唯讀不可動
                  decoration: InputDecoration(
                    // 設定輸入框外觀
                    labelText: '案號*', // 標籤文字
                    helperText: isEditMode ? '修改模式下案號不可更改' : '請輸入案件編號', // 提示說明
                    fillColor: isEditMode
                        ? Colors.grey[200]
                        : Colors.white, // 根據模式切換背景色
                    filled: true, // 開啟背景填充
                  ),
                  validator: (v) => v!.isEmpty ? '請輸入案號' : null, // 驗證：不可為空
                ),
                const SizedBox(height: 12), // 間距
                Row(
                  // 橫向排列結果與罰鍰
                  crossAxisAlignment: CrossAxisAlignment.start, // 頂部對齊
                  children: [
                    Expanded(
                      // 填滿寬度
                      child: DropdownButtonFormField<String>(
                        // 結果下拉選單
                        initialValue: _selectedResult, // 初始值
                        decoration: const InputDecoration(
                          labelText: '結果',
                          helperText: '',
                        ), // 設定標籤
                        items: _results
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(), // 建立選單清單
                        onChanged: (v) =>
                            setState(() => _selectedResult = v), // 選擇改變時更新狀態
                        // validator: (v) => v == null ? '必填' : null, // 驗證
                      ),
                    ),
                    const SizedBox(width: 12), // 間距
                    Expanded(
                      // 填滿寬度
                      child: TextFormField(
                        // 罰鍰輸入框
                        controller: _fineCtrl, // 綁定控制器
                        decoration: const InputDecoration(
                          labelText: '罰鍰',
                          helperText: '',
                        ), // 設定標籤
                        keyboardType: TextInputType.number, // 設定鍵盤為數字模式
                      ),
                    ),
                  ],
                ),
                _buildDatePicker(
                  '舉發日期*',
                  _issueDate,
                  (d) => setState(() => _issueDate = d),
                ), // 呼叫日期選擇器小工具
                const SizedBox(height: 12), // 間距
                // --- 🚩 修正點：將承辦單位與承辦人放在同一個 Row 裡面 ---
                Row(
                  // 建立橫向排列
                  crossAxisAlignment: CrossAxisAlignment.start, // 頂部對齊
                  children: [
                    // 子元件清單
                    Expanded(
                      // 使用 Expanded 讓左邊元件佔用一半空間
                      child: TextFormField(
                        // 承辦單位輸入框
                        controller: _unitCtrl, // 綁定單位控制器
                        decoration: const InputDecoration(
                          // 設定外觀
                          labelText: '承辦單位', // 標籤文字
                          helperText: '', // 保持下方空白高度一致
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // 兩個欄位中間的固定間距
                    Expanded(
                      // 使用 Expanded 讓右邊元件佔用另一半空間
                      child: TextFormField(
                        // 承辦人員輸入框
                        controller: _officerCtrl, // 綁定人員控制器
                        decoration: const InputDecoration(
                          // 設定外觀
                          labelText: '承辦人員', // 標籤文字
                          helperText: '', // 保持下方空白高度一致
                        ),
                      ),
                    ),
                  ],
                ),
              ]),

              _buildCardSection('車輛與地點', [
                // 車輛與地點卡片區塊
                Row(
                  // 橫向排列車牌與車種
                  crossAxisAlignment: CrossAxisAlignment.start, // 頂部對齊
                  children: [
                    Expanded(
                      // 填滿車牌
                      child: TextFormField(
                        // 車牌輸入框
                        controller: _plateNoCtrl, // 綁定控制器
                        decoration: const InputDecoration(
                          labelText: '車牌*',
                          helperText: '',
                        ), // 設定標籤
                        validator: (v) => v!.isEmpty ? '請輸入車牌' : null, // 驗證
                      ),
                    ),
                    const SizedBox(width: 12), // 間距
                    Expanded(
                      // 填滿車種
                      child: DropdownButtonFormField<String>(
                        // 車種下拉選單
                        initialValue: _selectedVehicleType, // 初始值
                        decoration: const InputDecoration(
                          labelText: '車種*',
                          helperText: '',
                        ), // 設定標籤
                        items: _vehicleTypes
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(), // 建立選項
                        onChanged: (v) =>
                            setState(() => _selectedVehicleType = v), // 更新狀態
                        validator: (v) => v == null ? '必填' : null, // 驗證
                      ),
                    ),
                  ],
                ),
                Row(
                  // 橫向排列縣市與區域
                  crossAxisAlignment: CrossAxisAlignment.start, // 頂部對齊
                  children: [
                    Expanded(
                      // 填滿縣市
                      child: DropdownButtonFormField<String>(
                        // 縣市下拉選單
                        initialValue: _selectedCity, // 初始值
                        decoration: const InputDecoration(
                          labelText: '縣市*',
                          helperText: '',
                        ), // 設定標籤
                        items: _cities
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(), // 建立選項
                        onChanged: (v) => setState(() {
                          _selectedCity = v;
                          _selectedDistrict = null;
                        }), // 改變時連動清空區域
                        validator: (v) => v == null ? '必填' : null, // 驗證
                      ),
                    ),
                    const SizedBox(width: 12), // 間距
                    Expanded(
                      // 填滿區域
                      child: DropdownButtonFormField<String>(
                        // 區域下拉選單
                        key: Key(_selectedCity ?? 'none'), // 當縣市變動時，強制刷新此選單
                        initialValue: _selectedDistrict, // 初始值
                        decoration: const InputDecoration(
                          labelText: '區域*',
                          helperText: '',
                        ), // 設定標籤
                        items:
                            (_selectedCity != null &&
                                _districtsMap.containsKey(
                                  _selectedCity,
                                )) // 判斷是否選了縣市
                            ? _districtsMap[_selectedCity]!
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList() // 建立對應區域選項
                            : [], // 否則為空
                        onChanged: (v) =>
                            setState(() => _selectedDistrict = v), // 更新狀態
                        validator: (v) => v == null ? '必填' : null, // 驗證
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  // 詳細地點輸入框
                  controller: _locationCtrl, // 綁定控制器
                  decoration: const InputDecoration(
                    labelText: '詳細地點',
                    helperText: '',
                  ), // 設定標籤
                ),
              ]),

              _buildCardSection('違規詳情', [
                // 違規詳情卡片區塊
                Row(
                  // 橫向排列違規日期與時間
                  crossAxisAlignment: CrossAxisAlignment.start, // 頂部對齊
                  children: [
                    Expanded(
                      child: _buildDatePicker(
                        '違規日期*',
                        _violationDate,
                        (d) => setState(() => _violationDate = d),
                      ),
                    ), // 違規日期
                    const SizedBox(width: 12), // 間距
                    Expanded(
                      // 填滿時間選擇
                      child: TextFormField(
                        // 違規時間輸入框 (點擊觸發)
                        readOnly: true, // 唯讀
                        onTap: () async {
                          // 點擊時彈出時間選取器
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          ); // 獲取時間
                          if (t != null) {
                            setState(() => _violationTime = t); // 更新狀態
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: '違規時間',
                          suffixIcon: Icon(Icons.access_time),
                          helperText: '',
                        ), // 外觀
                        controller: TextEditingController(
                          text: _violationTime?.format(context) ?? '',
                        ), // 顯示格式化時間
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  // 違規事實輸入框
                  controller: _factsCtrl, // 綁定控制器
                  decoration: const InputDecoration(
                    labelText: '違規事實',
                    helperText: '',
                  ), // 設定標籤
                  maxLines: 2, // 最多顯示兩行
                ),
                Visibility(
                  // 根據條件隱藏/顯示
                  visible: _selectedResult == '失敗', // 當結果為「失敗」時顯示
                  child: Padding(
                    // 設定間距
                    padding: const EdgeInsets.only(top: 12), // 上邊距
                    child: TextFormField(
                      // 不舉發原因輸入框
                      controller: _reasonCtrl, // 綁定控制器
                      decoration: InputDecoration(
                        // 外觀設定
                        labelText: '不舉發原因*', // 標籤
                        helperText: '結果為失敗時必填', // 提示
                        fillColor: _selectedResult == '失敗'
                            ? Colors.red[50]
                            : Colors.white, // 設定警告色背景
                        filled: true, // 開啟填充
                      ),
                      validator: (v) =>
                          (_selectedResult == '失敗' && (v == null || v.isEmpty))
                          ? '請輸入原因'
                          : null, // 驗證：失敗時必填
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 24), // 區塊底部間距
              SizedBox(
                // 按鈕寬度容器
                width: double.infinity, // 佔滿全寬
                height: 55, // 高度 55
                child: ElevatedButton.icon(
                  // 建立附有圖示的按鈕
                  onPressed: _saveData, // 點擊執行儲存
                  icon: Icon(
                    isEditMode ? Icons.save : Icons.cloud_upload,
                  ), // 根據模式切換圖示
                  label: Text(
                    // 按鈕文字
                    isEditMode ? '儲存修改' : '提交至 Firebase', // 切換標題
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ), // 字體設定
                  ),
                  style: ElevatedButton.styleFrom(
                    // 按鈕樣式
                    backgroundColor: isEditMode
                        ? Colors.orange[800]
                        : Colors.blue[700], // 模式切換顏色
                    foregroundColor: Colors.white, // 文字顏色
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ), // 設定圓角
                  ),
                ),
              ),
              const SizedBox(height: 50), // 頁面最底部緩衝間距
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection(String title, List<Widget> children) {
    // 卡片區塊小工具方法
    return Card(
      // 返回卡片元件
      margin: const EdgeInsets.only(bottom: 20), // 卡片下邊距
      elevation: 0, // 無陰影
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ), // 外框圓角
      child: Padding(
        // 內部間距
        padding: const EdgeInsets.all(16.0), // 四周 16
        child: Column(
          // 垂直排標題與內容
          crossAxisAlignment: CrossAxisAlignment.start, // 靠左
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ), // 標題樣式
            const Divider(), // 分隔線
            const SizedBox(height: 8), // 間距
            ...children, // 展開傳入的所有子元件
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
    // 日期選擇器小工具方法
    return TextFormField(
      // 使用文字輸入框模擬
      readOnly: true, // 禁止手動打字
      onTap: () async {
        // 點擊觸發選取器
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        ); // 彈出日期選取框
        if (d != null) onPicked(d); // 若有點選，執行回呼
      },
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.event),
        helperText: '',
      ), // 外觀設定
      controller: TextEditingController(
        text: date?.toString().split(' ')[0] ?? '',
      ), // 將日期物件轉為 YYYY-MM-DD
      validator: (v) => date == null ? '必選' : null, // 驗證日期是否已選
    );
  }

  @override
  void dispose() {
    // 元件銷毀生命週期
    _caseNoCtrl.dispose(); // 銷毀案號控制器，釋放資源
    _plateNoCtrl.dispose(); // 銷毀車牌控制器
    _fineCtrl.dispose(); // 銷毀罰鍰控制器
    _locationCtrl.dispose(); // 銷毀地點控制器
    _factsCtrl.dispose(); // 銷毀事實控制器
    _reasonCtrl.dispose(); // 銷毀原因控制器
    _unitCtrl.dispose(); // 銷毀單位控制器
    _officerCtrl.dispose(); // 銷毀人員控制器
    super.dispose(); // 執行父類別銷毀
  }
}
