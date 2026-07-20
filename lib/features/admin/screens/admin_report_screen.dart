import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../widgets/ai_briefing_bottom_sheet.dart';
import '../widgets/ai_chat_modal.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  bool _isLoading = true;
  bool _hasError = false;

  // Raw data
  List<Map<String, dynamic>> _billingStatements = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _shipments = [];
  List<Map<String, dynamic>> _productionPlans = [];
  List<Map<String, dynamic>> _users = [];

  // GROUP 1
  int _totalActiveStores = 0;
  double _totalRevenuePaid = 0;
  double _totalDebt = 0;
  int _overdueCount = 0;
  int _pendingOrdersCount = 0;
  int _deliveryFailedCount = 0;
  int _activeShipmentsCount = 0;

  // GROUP 2
  Map<int, double> _storeDebtMap = {};
  Map<int, double> _storeRevenueMap = {};
  Map<int, String> _storeNameMap = {};

  // GROUP 3
  Map<String, int> _orderStatusCount = {};

  // GROUP 4
  Map<String, int> _shipmentStatusCount = {};
  double _totalShippingFee = 0;
  double _totalDistance = 0;
  double _avgDeliveryMinutes = 0;
  int _shipmentsWithTime = 0;

  // GROUP 5
  Map<String, int> _productionStatusCount = {};
  int _totalProductionPlans = 0;

  // GROUP 6
  Map<int, Map<String, dynamic>> _storeStats = {};

  // GROUP 7
  Map<String, int> _roleCount = {};
  int _inactiveUsers = 0;
  int _suspendedUsers = 0;
  int _newUsersThisMonth = 0;

  // GROUP 8
  List<Map<String, dynamic>> _overdueStatements = [];
  List<Map<String, dynamic>> _failedShipments = [];
  List<Map<String, dynamic>> _longPendingOrders = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final results = await Future.wait([
        ApiService.fetchBillingStatements(size: 200),
        ApiService.fetchStores(size: 100),
        ApiService.fetchOrdersList(size: 200),
        ApiService.fetchShipmentsList(size: 200),
        ApiService.fetchProductionPlans(size: 200),
        ApiService.fetchUsers(size: 200),
      ]);

      final billings = results[0] as List<Map<String, dynamic>>;
      final stores = results[1] as List<Map<String, dynamic>>;
      final orders = results[2] as List<Map<String, dynamic>>;
      final shipments = results[3] as List<Map<String, dynamic>>;
      final plans = results[4] as List<Map<String, dynamic>>;
      final users = results[5] as List<Map<String, dynamic>>;

      // Store name map
      final Map<int, String> storeName = {};
      for (final s in stores) {
        final id = (s['storeId'] ?? s['id']) as int?;
        if (id != null) storeName[id] = s['name']?.toString() ?? 'CH #$id';
      }

      // GROUP 1 & 2: Billing
      double revenuePaid = 0;
      double totalDebt = 0;
      int overdueCount = 0;
      final Map<int, double> storeDebt = {};
      final Map<int, double> storeRevenue = {};

      for (final b in billings) {
        final amt = _toDouble(b['totalAmount']);
        final status = (b['status'] ?? 'UNKNOWN').toString().toUpperCase();
        final storeId = b['storeId'] as int?;
        final sName = b['storeName']?.toString();
        if (storeId != null && sName != null) storeName[storeId] = sName;

        if (status == 'PAID') {
          revenuePaid += amt;
          if (storeId != null) storeRevenue[storeId] = (storeRevenue[storeId] ?? 0) + amt;
        }
        if (status == 'ISSUED' || status == 'OVERDUE') {
          totalDebt += amt;
          if (storeId != null) storeDebt[storeId] = (storeDebt[storeId] ?? 0) + amt;
        }
        if (status == 'OVERDUE') overdueCount++;
      }

      // GROUP 3: Orders
      final Map<String, int> orderStatus = {};
      int pendingCount = 0;
      final List<Map<String, dynamic>> longPending = [];
      final Map<int, Map<String, dynamic>> storeStatsMap = {};

      for (final o in orders) {
        final st = (o['status'] ?? 'UNKNOWN').toString().toUpperCase();
        orderStatus[st] = (orderStatus[st] ?? 0) + 1;
        final storeId = o['storeId'] as int?;
        final amt = _toDouble(o['totalAmount']);

        if (storeId != null) {
          final sName = o['storeName']?.toString();
          if (sName != null) storeName[storeId] = sName;
          storeStatsMap.putIfAbsent(storeId, () => {
            'orders': 0,
            'totalValue': 0.0,
            'delivered': 0,
          });
          storeStatsMap[storeId]!['orders'] =
              (storeStatsMap[storeId]!['orders'] as int) + 1;
          storeStatsMap[storeId]!['totalValue'] =
              (storeStatsMap[storeId]!['totalValue'] as double) + amt;
          if (st == 'DELIVERED' || st == 'CONFIRMED') {
            storeStatsMap[storeId]!['delivered'] =
                (storeStatsMap[storeId]!['delivered'] as int) + 1;
          }
        }

        if (st == 'SUBMITTED') {
          pendingCount++;
          final dateStr = o['orderDate']?.toString();
          if (dateStr != null) {
            try {
              if (DateTime.now()
                      .difference(DateTime.parse(dateStr))
                      .inHours >=
                  4) longPending.add(o);
            } catch (_) {}
          }
        }
      }

      // Merge debt into storeStats
      for (final entry in storeDebt.entries) {
        storeStatsMap.putIfAbsent(
            entry.key, () => {'orders': 0, 'totalValue': 0.0, 'delivered': 0});
        storeStatsMap[entry.key]!['debt'] = entry.value;
      }

      // GROUP 4: Shipments
      final Map<String, int> shipmentStatus = {};
      int inTransit = 0;
      int deliveryFailed = 0;
      double totalShipFee = 0;
      double totalDist = 0;
      double totalDeliveryMins = 0;
      int shipsWithTime = 0;
      final List<Map<String, dynamic>> failedShips = [];

      for (final s in shipments) {
        final st = (s['status'] ?? '').toString().toUpperCase();
        shipmentStatus[st] = (shipmentStatus[st] ?? 0) + 1;
        totalShipFee += _toDouble(s['shippingFee']);
        totalDist += _toDouble(s['distance']);
        if (st == 'IN_TRANSIT') inTransit++;
        if (st == 'DELIVERY_FAILED') {
          deliveryFailed++;
          failedShips.add(s);
        }
        final shippedStr = s['shippedAt']?.toString();
        final deliveredStr = s['deliveredAt']?.toString();
        if (shippedStr != null && deliveredStr != null) {
          try {
            final shipped = DateTime.parse(shippedStr);
            final delivered = DateTime.parse(deliveredStr);
            totalDeliveryMins += delivered.difference(shipped).inMinutes;
            shipsWithTime++;
          } catch (_) {}
        }
      }

      // GROUP 5: Production Plans
      final Map<String, int> planStatus = {};
      for (final p in plans) {
        final st = (p['status'] ?? 'UNKNOWN').toString().toUpperCase();
        planStatus[st] = (planStatus[st] ?? 0) + 1;
      }

      // GROUP 7: Personnel
      final Map<String, int> roleMap = {};
      int inactive = 0, suspended = 0, newThisMonth = 0;
      final now = DateTime.now();
      for (final u in users) {
        final roleName =
            (u['role']?.toString() ?? u['roleName']?.toString() ?? 'UNKNOWN')
                .toUpperCase()
                .replaceAll('ROLE_', '');
        roleMap[roleName] = (roleMap[roleName] ?? 0) + 1;
        final status = (u['status'] ?? '').toString().toUpperCase();
        if (status == 'INACTIVE') inactive++;
        if (status == 'SUSPENDED') suspended++;
        final createdStr = u['createdAt']?.toString();
        if (createdStr != null) {
          try {
            final created = DateTime.parse(createdStr);
            if (created.year == now.year && created.month == now.month) {
              newThisMonth++;
            }
          } catch (_) {}
        }
      }

      final overdueList = billings
          .where((b) =>
              (b['status'] ?? '').toString().toUpperCase() == 'OVERDUE')
          .take(5)
          .toList();
      final activeStores =
          stores.where((s) => s['isActive'] == true || s['active'] == true).length;

      if (mounted) {
        setState(() {
          _billingStatements = billings;
          _stores = stores;
          _orders = orders;
          _shipments = shipments;
          _productionPlans = plans;
          _users = users;

          _totalActiveStores = activeStores > 0 ? activeStores : stores.length;
          _totalRevenuePaid = revenuePaid;
          _totalDebt = totalDebt;
          _overdueCount = overdueCount;
          _pendingOrdersCount = pendingCount;
          _activeShipmentsCount = inTransit;
          _deliveryFailedCount = deliveryFailed;

          _storeDebtMap = storeDebt;
          _storeRevenueMap = storeRevenue;
          _storeNameMap = storeName;

          _orderStatusCount = orderStatus;

          _shipmentStatusCount = shipmentStatus;
          _totalShippingFee = totalShipFee;
          _totalDistance = totalDist;
          _avgDeliveryMinutes =
              shipsWithTime > 0 ? totalDeliveryMins / shipsWithTime : 0;
          _shipmentsWithTime = shipsWithTime;

          _productionStatusCount = planStatus;
          _totalProductionPlans = plans.length;

          _storeStats = storeStatsMap;

          _roleCount = roleMap;
          _inactiveUsers = inactive;
          _suspendedUsers = suspended;
          _newUsersThisMonth = newThisMonth;

          _overdueStatements = overdueList;
          _failedShipments = failedShips.take(5).toList();
          _longPendingOrders = longPending.take(5).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _formatCurrency(double amount) {
    if (amount >= 1e9) return '${(amount / 1e9).toStringAsFixed(1)} tỷ';
    if (amount >= 1e6) return '${(amount / 1e6).toStringAsFixed(1)} tr';
    if (amount >= 1e3) return '${(amount / 1e3).toStringAsFixed(0)}k';
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text('Đang tổng hợp báo cáo...',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 52),
            const SizedBox(height: 12),
            const Text('Không tải được dữ liệu',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadReportData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.amber,
      backgroundColor: const Color(0xff1A1A1A),
      onRefresh: _loadReportData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildAiCockpitBanner(),
          const SizedBox(height: 20),
          _buildGroup1KPI(),
          const SizedBox(height: 24),
          _buildGroup2Revenue(),
          const SizedBox(height: 24),
          _buildGroup3Orders(),
          const SizedBox(height: 24),
          _buildGroup4Shipments(),
          const SizedBox(height: 24),
          _buildGroup5Production(),
          const SizedBox(height: 24),
          _buildGroup6StoreComparison(),
          const SizedBox(height: 24),
          _buildGroup7Personnel(),
          const SizedBox(height: 24),
          _buildGroup8Alerts(),
        ],
      ),
    );
  }

  Widget _buildAiCockpitBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF31106A), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ AI Executive Cockpit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Phân tích & chuẩn đoán 8 Nhóm theo thời gian thực',
                      style: TextStyle(color: Color(0xFFDDD6FE), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => AiBriefingBottomSheet.show(context),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Chuẩn Đoán AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => AiChatModal.show(context),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Hỏi Đáp AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // GROUP 1: KPI
  // ===================================================================
  Widget _buildGroup1KPI() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('KPI TỔNG QUAN', Icons.dashboard_rounded),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _kpiCard(
                label: 'Doanh thu đã thu',
                value: _formatCurrency(_totalRevenuePaid),
                unit: 'đ',
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF4CAF50),
                bgColor: const Color(0xFF0D1F0D))),
        const SizedBox(width: 10),
        Expanded(
            child: _kpiCard(
                label: 'Công nợ chưa thu',
                value: _formatCurrency(_totalDebt),
                unit: 'đ',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFFFF9800),
                bgColor: const Color(0xFF1F150A))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _kpiCard(
                label: 'Cửa hàng HĐ',
                value: '$_totalActiveStores',
                unit: 'store',
                icon: Icons.storefront_rounded,
                color: const Color(0xFF2196F3),
                bgColor: const Color(0xFF0A1929))),
        const SizedBox(width: 10),
        Expanded(
            child: _kpiCard(
                label: 'Đang vận chuyển',
                value: '$_activeShipmentsCount',
                unit: 'chuyến',
                icon: Icons.local_shipping_rounded,
                color: const Color(0xFF9C27B0),
                bgColor: const Color(0xFF1A0A2A))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _kpiCard(
                label: 'Đơn chờ duyệt',
                value: '$_pendingOrdersCount',
                unit: 'đơn',
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFFFAB40),
                bgColor: const Color(0xFF1F160A),
                badge: _pendingOrdersCount > 0)),
        const SizedBox(width: 10),
        Expanded(
            child: _kpiCard(
                label: 'HĐ quá hạn',
                value: '$_overdueCount',
                unit: 'hóa đơn',
                icon: Icons.warning_rounded,
                color: const Color(0xFFF44336),
                bgColor: const Color(0xFF1F0A0A),
                badge: _overdueCount > 0)),
      ]),
      if (_deliveryFailedCount > 0) ...[
        const SizedBox(height: 10),
        _kpiCard(
            label: 'Giao hàng thất bại',
            value: '$_deliveryFailedCount',
            unit: 'chuyến',
            icon: Icons.cancel_rounded,
            color: const Color(0xFFF44336),
            bgColor: const Color(0xFF1F0A0A),
            badge: true,
            fullWidth: true),
      ],
    ]);
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool badge = false,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
          if (badge)
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color:
                        const Color(0xFFF44336).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFF44336).withOpacity(0.3))),
                child: const Text('!',
                    style: TextStyle(
                        color: Color(0xFFF44336),
                        fontSize: 11,
                        fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(unit,
            style: TextStyle(
                color: color.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ===================================================================
  // GROUP 2: DOANH THU & CÔNG NỢ
  // ===================================================================
  Widget _buildGroup2Revenue() {
    final statusCounts = <String, int>{};
    final statusAmounts = <String, double>{};
    for (final b in _billingStatements) {
      final st = (b['status'] ?? 'UNKNOWN').toString().toUpperCase();
      statusCounts[st] = (statusCounts[st] ?? 0) + 1;
      statusAmounts[st] =
          (statusAmounts[st] ?? 0) + _toDouble(b['totalAmount']);
    }
    final debtors = _storeDebtMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRevenue = _storeRevenueMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('DOANH THU & CÔNG NỢ', Icons.payments_rounded),
      const SizedBox(height: 12),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Trạng thái hóa đơn hệ thống'),
            const SizedBox(height: 12),
            ...[
              ('PAID', 'Đã thanh toán', const Color(0xFF4CAF50)),
              ('ISSUED', 'Chờ thanh toán', const Color(0xFFFF9800)),
              ('OVERDUE', 'Quá hạn', const Color(0xFFF44336)),
              ('DRAFT', 'Bản nháp', Colors.grey),
              ('CANCELLED', 'Đã hủy', Colors.blueGrey),
            ].map((e) {
              final cnt = statusCounts[e.$1] ?? 0;
              if (cnt == 0) return const SizedBox.shrink();
              final pct = _billingStatements.isNotEmpty
                  ? cnt / _billingStatements.length
                  : 0.0;
              return _barRow(e.$2, cnt, statusAmounts[e.$1] ?? 0, pct, e.$3,
                  showAmount: true);
            }),
            if (statusCounts.isEmpty)
              const Center(
                  child: Text('Chưa có hóa đơn',
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
          ])),
      if (debtors.isNotEmpty) ...[
        const SizedBox(height: 14),
        _cardContainer(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _subTitle('Top cửa hàng nợ nhiều nhất'),
              const SizedBox(height: 12),
              ...debtors.take(5).toList().asMap().entries.map((e) => _rankRow(
                  e.key + 1,
                  _storeNameMap[e.value.key] ?? 'CH #${e.value.key}',
                  e.value.value,
                  isNegative: true)),
            ])),
      ],
      if (topRevenue.isNotEmpty) ...[
        const SizedBox(height: 14),
        _cardContainer(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _subTitle('Top cửa hàng doanh thu cao nhất'),
              const SizedBox(height: 12),
              ...topRevenue.take(5).toList().asMap().entries.map((e) => _rankRow(
                  e.key + 1,
                  _storeNameMap[e.value.key] ?? 'CH #${e.value.key}',
                  e.value.value,
                  isNegative: false)),
            ])),
      ],
    ]);
  }

  // ===================================================================
  // GROUP 3: ĐƠN HÀNG
  // ===================================================================
  Widget _buildGroup3Orders() {
    final total = _orders.length;
    final funnelStatuses = [
      ('SUBMITTED', 'Chờ duyệt', const Color(0xFFFFAB40)),
      ('APPROVED', 'Đã duyệt', const Color(0xFF42A5F5)),
      ('SCHEDULED', 'Đã lên KH sản xuất', const Color(0xFF7E57C2)),
      ('IN_TRANSIT', 'Đang giao', const Color(0xFF26C6DA)),
      ('DELIVERED', 'Đã giao', const Color(0xFF66BB6A)),
      ('CONFIRMED', 'Đã xác nhận', const Color(0xFF4CAF50)),
      ('REJECTED', 'Từ chối', const Color(0xFFEF5350)),
      ('DELIVERY_FAILED', 'Giao thất bại', const Color(0xFFF44336)),
      ('CANCELLED', 'Đã hủy', const Color(0xFF78909C)),
    ];
    final successCount = (_orderStatusCount['DELIVERED'] ?? 0) +
        (_orderStatusCount['CONFIRMED'] ?? 0);
    final failCount = (_orderStatusCount['DELIVERY_FAILED'] ?? 0) +
        (_orderStatusCount['REJECTED'] ?? 0) +
        (_orderStatusCount['CANCELLED'] ?? 0);
    final successRate = total > 0 ? successCount / total * 100 : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('ĐƠN HÀNG', Icons.receipt_long_rounded),
      const SizedBox(height: 12),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Tổng quan đơn hàng'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _summaryBadge('Tổng đơn', '$total', Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                  child: _summaryBadge(
                      'Thành công', '$successCount', const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(
                  child: _summaryBadge(
                      'Thất bại', '$failCount', const Color(0xFFF44336))),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Tỷ lệ thành công',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${successRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: successRate / 100,
                    backgroundColor:
                        const Color(0xFFF44336).withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50)),
                    minHeight: 8)),
          ])),
      const SizedBox(height: 14),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Phân bố trạng thái đơn hàng'),
            const SizedBox(height: 12),
            ...funnelStatuses.map((e) {
              final count = _orderStatusCount[e.$1] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return _simpleBarRow(
                  e.$2, count, total > 0 ? count / total : 0.0, e.$3);
            }),
            if (_orderStatusCount.isEmpty)
              const Center(
                  child: Text('Chưa có đơn hàng',
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
          ])),
    ]);
  }

  // ===================================================================
  // GROUP 4: VẬN CHUYỂN
  // ===================================================================
  Widget _buildGroup4Shipments() {
    final total = _shipments.length;
    final delivered = _shipmentStatusCount['DELIVERED'] ?? 0;
    final failed = _shipmentStatusCount['DELIVERY_FAILED'] ?? 0;
    final successRate = total > 0 ? delivered / total * 100 : 0.0;
    final avgMins = _avgDeliveryMinutes;
    final avgDisplay = _shipmentsWithTime > 0
        ? (avgMins >= 60
            ? '${(avgMins / 60).toStringAsFixed(1)}h'
            : '${avgMins.toStringAsFixed(0)} phút')
        : 'N/A';

    final shipStatusDefs = [
      ('DELIVERED', 'Đã giao thành công', const Color(0xFF4CAF50)),
      ('IN_TRANSIT', 'Đang vận chuyển', const Color(0xFF26C6DA)),
      ('ARRIVED', 'Đã đến, chờ xác nhận', const Color(0xFF42A5F5)),
      ('PREPARED', 'Đã chuẩn bị xong', const Color(0xFF7E57C2)),
      ('PENDING', 'Chờ chuẩn bị', const Color(0xFFFFAB40)),
      ('DELIVERY_FAILED', 'Giao thất bại', const Color(0xFFF44336)),
      ('RETURNED', 'Hàng đã hoàn trả', const Color(0xFFFF7043)),
      ('CANCELLED', 'Đã hủy', const Color(0xFF78909C)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('VẬN CHUYỂN (SHIPMENT)', Icons.local_shipping_rounded),
      const SizedBox(height: 12),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Chỉ số vận chuyển tổng hợp'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _metricTile(
                      label: 'Tổng chuyến',
                      value: '$total',
                      icon: Icons.route_rounded,
                      color: const Color(0xFF2196F3))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Thành công',
                      value: '$delivered',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Thất bại',
                      value: '$failed',
                      icon: Icons.cancel_rounded,
                      color: const Color(0xFFF44336))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _metricTile(
                      label: 'Chi phí ship',
                      value: _formatCurrency(_totalShippingFee),
                      icon: Icons.monetization_on_rounded,
                      color: const Color(0xFFFF9800))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Tổng km',
                      value: '${_totalDistance.toStringAsFixed(1)} km',
                      icon: Icons.map_rounded,
                      color: const Color(0xFF9C27B0))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'TG giao TB',
                      value: avgDisplay,
                      icon: Icons.timer_rounded,
                      color: const Color(0xFF26C6DA))),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Tỷ lệ giao thành công',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${successRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: successRate / 100,
                    backgroundColor:
                        const Color(0xFFF44336).withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50)),
                    minHeight: 8)),
          ])),
      const SizedBox(height: 14),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Phân bố trạng thái chuyến xe'),
            const SizedBox(height: 12),
            ...shipStatusDefs.map((e) {
              final count = _shipmentStatusCount[e.$1] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return _simpleBarRow(
                  e.$2, count, total > 0 ? count / total : 0.0, e.$3);
            }),
            if (_shipmentStatusCount.isEmpty)
              const Center(
                  child: Text('Chưa có chuyến xe',
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
          ])),
    ]);
  }

  // ===================================================================
  // GROUP 5: KẾ HOẠCH SẢN XUẤT
  // ===================================================================
  Widget _buildGroup5Production() {
    final total = _totalProductionPlans;
    final finished = (_productionStatusCount['FINISHED'] ?? 0) +
        (_productionStatusCount['PRODUCED'] ?? 0);
    final inProgress = _productionStatusCount['IN_PRODUCTION'] ?? 0;
    final successRate = total > 0 ? finished / total * 100 : 0.0;

    final planStatusDefs = [
      ('PLANNED', 'Đã lên kế hoạch', const Color(0xFF42A5F5)),
      ('READY_TO_PRODUCE', 'Sẵn sàng sản xuất', const Color(0xFF7E57C2)),
      ('IN_PRODUCTION', 'Đang sản xuất', const Color(0xFFFFAB40)),
      ('PRODUCED', 'Đã sản xuất xong', const Color(0xFF26C6DA)),
      ('FINISHED', 'Hoàn thành & Phân bổ', const Color(0xFF4CAF50)),
      ('CANCELLED', 'Đã hủy', const Color(0xFF78909C)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('KẾ HOẠCH SẢN XUẤT', Icons.restaurant_menu_rounded),
      const SizedBox(height: 12),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Tổng quan kế hoạch sản xuất'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _metricTile(
                      label: 'Tổng KH',
                      value: '$total',
                      icon: Icons.list_alt_rounded,
                      color: const Color(0xFF2196F3))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Hoàn thành',
                      value: '$finished',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Đang nấu',
                      value: '$inProgress',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFFF9800))),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Tỷ lệ hoàn thành',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${successRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: successRate / 100,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50)),
                    minHeight: 8)),
          ])),
      const SizedBox(height: 14),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Phân bố trạng thái kế hoạch'),
            const SizedBox(height: 12),
            ...planStatusDefs.map((e) {
              final count = _productionStatusCount[e.$1] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return _simpleBarRow(
                  e.$2, count, total > 0 ? count / total : 0.0, e.$3);
            }),
            if (_productionStatusCount.isEmpty)
              const Center(
                  child: Text('Chưa có kế hoạch sản xuất',
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
          ])),
    ]);
  }

  // ===================================================================
  // GROUP 6: SO SÁNH HIỆU QUẢ CỬA HÀNG
  // ===================================================================
  Widget _buildGroup6StoreComparison() {
    final storeEntries = _storeStats.entries.toList()
      ..sort((a, b) =>
          (b.value['orders'] as int).compareTo(a.value['orders'] as int));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('HIỆU QUẢ CỬA HÀNG', Icons.storefront_rounded),
      const SizedBox(height: 12),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Tổng số cửa hàng trong hệ thống'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _metricTile(
                      label: 'Tổng cửa hàng',
                      value: '${_stores.length}',
                      icon: Icons.store_rounded,
                      color: const Color(0xFF2196F3))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Đang hoạt động',
                      value: '$_totalActiveStores',
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Có đơn hàng',
                      value: '${_storeStats.length}',
                      icon: Icons.receipt_rounded,
                      color: const Color(0xFFFF9800))),
            ]),
          ])),
      const SizedBox(height: 14),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Chi tiết theo từng cửa hàng'),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Expanded(
                    flex: 3,
                    child: Text('Cửa hàng',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 1,
                    child: Text('Đơn',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Doanh số',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 2,
                    child: Text('Công nợ',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right)),
                Expanded(
                    flex: 1,
                    child: Text('TL%',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
              ]),
            ),
            const SizedBox(height: 4),
            ...storeEntries.take(10).map((entry) {
              final storeId = entry.key;
              final stats = entry.value;
              final name =
                  _storeNameMap[storeId] ?? 'CH #$storeId';
              final orders = stats['orders'] as int? ?? 0;
              final totalVal = stats['totalValue'] as double? ?? 0;
              final deliveredCount = stats['delivered'] as int? ?? 0;
              final debt =
                  stats['debt'] as double? ?? (_storeDebtMap[storeId] ?? 0);
              final sr =
                  orders > 0 ? (deliveredCount / orders * 100).round() : 0;
              final hasDebt = debt > 0;

              return Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: hasDebt
                      ? const Color(0xFFF44336).withOpacity(0.04)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: hasDebt
                          ? const Color(0xFFF44336).withOpacity(0.12)
                          : Colors.transparent),
                ),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: Text(name,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      flex: 1,
                      child: Text('$orders',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                  Expanded(
                      flex: 2,
                      child: Text(_formatCurrency(totalVal),
                          style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 2,
                      child: Text(
                          hasDebt ? _formatCurrency(debt) : '-',
                          style: TextStyle(
                              color: hasDebt
                                  ? const Color(0xFFF44336)
                                  : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 1,
                      child: Text('$sr%',
                          style: TextStyle(
                              color: sr >= 80
                                  ? const Color(0xFF4CAF50)
                                  : sr >= 50
                                      ? const Color(0xFFFFAB40)
                                      : const Color(0xFFF44336),
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                ]),
              );
            }),
            if (storeEntries.length > 10)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                      child: Text(
                          '... và ${storeEntries.length - 10} cửa hàng khác',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11)))),
            if (storeEntries.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Chưa có dữ liệu',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)))),
          ])),
    ]);
  }

  // ===================================================================
  // GROUP 7: NHÂN SỰ
  // ===================================================================
  Widget _buildGroup7Personnel() {
    final totalUsers = _users.length;
    final activeUsers = totalUsers - _inactiveUsers - _suspendedUsers;

    final roleDefs = [
      ('ADMIN', 'Quản trị viên', const Color(0xFFF44336)),
      ('MANAGER', 'Quản lý phân phối', const Color(0xFF9C27B0)),
      ('COORDINATOR', 'Điều phối viên', const Color(0xFF2196F3)),
      ('KITCHEN_STAFF', 'Nhân viên bếp', const Color(0xFFFF9800)),
      ('STORE_STAFF', 'Nhân viên cửa hàng', const Color(0xFF4CAF50)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('NHÂN SỰ', Icons.people_alt_rounded),
      const SizedBox(height: 12),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Tổng quan nhân sự'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _metricTile(
                      label: 'Tổng nhân sự',
                      value: '$totalUsers',
                      icon: Icons.group_rounded,
                      color: const Color(0xFF2196F3))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Đang hoạt động',
                      value: '$activeUsers',
                      icon: Icons.person_rounded,
                      color: const Color(0xFF4CAF50))),
              const SizedBox(width: 8),
              Expanded(
                  child: _metricTile(
                      label: 'Mới tháng này',
                      value: '$_newUsersThisMonth',
                      icon: Icons.person_add_rounded,
                      color: const Color(0xFFFF9800))),
            ]),
            if (_inactiveUsers > 0 || _suspendedUsers > 0) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (_inactiveUsers > 0)
                  Expanded(
                      child: _metricTile(
                          label: 'Không HĐ',
                          value: '$_inactiveUsers',
                          icon: Icons.person_off_rounded,
                          color: Colors.grey)),
                if (_inactiveUsers > 0) const SizedBox(width: 8),
                if (_suspendedUsers > 0)
                  Expanded(
                      child: _metricTile(
                          label: 'Bị đình chỉ',
                          value: '$_suspendedUsers',
                          icon: Icons.block_rounded,
                          color: const Color(0xFFF44336))),
                if (_suspendedUsers > 0) const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ]),
            ],
          ])),
      const SizedBox(height: 14),
      _cardContainer(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            _subTitle('Phân bố theo vai trò'),
            const SizedBox(height: 12),
            ...roleDefs.map((e) {
              final count = _roleCount[e.$1] ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return _simpleBarRow(
                  e.$2, count, totalUsers > 0 ? count / totalUsers : 0.0, e.$3);
            }),
            if (_roleCount.isEmpty)
              const Center(
                  child: Text('Chưa có dữ liệu nhân sự',
                      style: TextStyle(color: Colors.grey, fontSize: 12))),
          ])),
    ]);
  }

  // ===================================================================
  // GROUP 8: CẢNH BÁO
  // ===================================================================
  Widget _buildGroup8Alerts() {
    final hasAlerts = _overdueStatements.isNotEmpty ||
        _failedShipments.isNotEmpty ||
        _longPendingOrders.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('CẢNH BÁO & HÀNH ĐỘNG', Icons.notifications_active_rounded),
      const SizedBox(height: 12),
      if (!hasAlerts)
        _cardContainer(
            child: Center(
                child: Column(children: [
          const SizedBox(height: 8),
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4CAF50), size: 40),
          const SizedBox(height: 8),
          const Text('Tất cả đều ổn!',
              style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 4),
          Text('Không có cảnh báo nào cần xử lý',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 8),
        ]))),
      if (_overdueStatements.isNotEmpty) ...[
        _alertCard(
            icon: Icons.warning_rounded,
            color: const Color(0xFFF44336),
            title: 'Hóa đơn quá hạn (${_overdueStatements.length})',
            items: _overdueStatements.map((b) {
              final storeId = b['storeId'] as int?;
              final name = b['storeName']?.toString() ??
                  (storeId != null ? _storeNameMap[storeId] : null) ??
                  'Cửa hàng';
              return '$name — ${_formatCurrency(_toDouble(b["totalAmount"]))} đ';
            }).toList()),
        const SizedBox(height: 10),
      ],
      if (_failedShipments.isNotEmpty) ...[
        _alertCard(
            icon: Icons.cancel_rounded,
            color: const Color(0xFFFF5722),
            title:
                'Chuyến giao thất bại (${_failedShipments.length})',
            items: _failedShipments
                .map((s) =>
                    'Chuyến #${s["shipmentId"] ?? s["id"] ?? "?"}')
                .toList()),
        const SizedBox(height: 10),
      ],
      if (_longPendingOrders.isNotEmpty)
        _alertCard(
            icon: Icons.hourglass_bottom_rounded,
            color: const Color(0xFFFFAB40),
            title:
                'Đơn chờ duyệt > 4 giờ (${_longPendingOrders.length})',
            items: _longPendingOrders.map((o) {
              final id = o['orderId'] ?? o['id'] ?? '?';
              final store = o['storeName']?.toString() ?? '';
              return 'Đơn #$id${store.isNotEmpty ? " — $store" : ""}';
            }).toList()),
    ]);
  }

  // ===================================================================
  // SHARED WIDGETS
  // ===================================================================
  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.amber, size: 16)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(title,
            style: const TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
      ),
    ]);
  }

  Widget _subTitle(String text) => Text(text,
      style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: child,
    );
  }

  Widget _summaryBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 9),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 9),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _barRow(String label, int count, double amount, double pct,
      Color color, {bool showAmount = false}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(label,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$count',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              if (showAmount)
                Text('${_formatCurrency(amount)} đ',
                    style: TextStyle(
                        color: color.withOpacity(0.7), fontSize: 10)),
            ]),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4)),
        ]));
  }

  Widget _simpleBarRow(String label, int count, double pct, Color color) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11))),
          const SizedBox(width: 8),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6))),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ]));
  }

  Widget _rankRow(int rank, String name, double amount,
      {required bool isNegative}) {
    final color =
        isNegative ? const Color(0xFFF44336) : const Color(0xFF4CAF50);
    final medals = ['🥇', '🥈', '🥉'];
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 28,
              child: Text(rank <= 3 ? medals[rank - 1] : '#$rank',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
          Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${_formatCurrency(amount)} đ',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold))),
        ]));
  }

  Widget _alertCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13))),
        ]),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.arrow_right_rounded,
                  color: color.withOpacity(0.6), size: 16),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(item,
                      style: TextStyle(
                          color: Colors.grey.shade300, fontSize: 12))),
            ]))),
      ]),
    );
  }
}
