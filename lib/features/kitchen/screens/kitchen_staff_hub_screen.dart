import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class KitchenStaffHubScreen extends StatefulWidget {
  final int initialTab;

  const KitchenStaffHubScreen({super.key, this.initialTab = 0});

  @override
  State<KitchenStaffHubScreen> createState() => _KitchenStaffHubScreenState();
}

class _KitchenStaffHubScreenState extends State<KitchenStaffHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Tab 1: Production Plans State ---
  bool _isLoadingPlans = true;
  List<Map<String, dynamic>> _productionPlans = [];
  String _selectedPlanStatus = "ALL";

  // --- Tab 2: Shipments State ---
  bool _isLoadingShipments = true;
  List<Map<String, dynamic>> _shipments = [];
  String _selectedShipmentStatus = "ALL";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadProductionPlans();
    _loadShipments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Loading Logic ---

  Future<void> _loadProductionPlans() async {
    if (!mounted) return;
    setState(() => _isLoadingPlans = true);

    try {
      final list = await ApiService.fetchProductionPlans();
      if (mounted) {
        setState(() {
          if (_selectedPlanStatus != "ALL") {
            _productionPlans = list.where((p) => p['status'] == _selectedPlanStatus).toList();
          } else {
            _productionPlans = list;
          }
          _isLoadingPlans = false;
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi tải lệnh sản xuất: $e", Colors.redAccent);
    }
  }

  Future<void> _loadShipments() async {
    if (!mounted) return;
    setState(() => _isLoadingShipments = true);

    try {
      final list = await ApiService.fetchShipments();
      if (mounted) {
        setState(() {
          if (_selectedShipmentStatus != "ALL") {
            _shipments = list.where((s) => s['status'] == _selectedShipmentStatus).toList();
          } else {
            _shipments = list;
          }
          _isLoadingShipments = false;
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi tải lịch giao hàng: $e", Colors.redAccent);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: bgColor),
      );
    }
  }

  // --- Actions ---

  Future<void> _markReadyPlan(int planId) async {
    try {
      final ok = await ApiService.updateProductionPlanStatus(planId, 'READY_TO_PRODUCE');
      if (ok) {
        _showSnackBar("Đã đánh dấu SẴN SÀNG SẢN XUẤT cho lệnh #$planId!", Colors.green);
        _loadProductionPlans();
      }
    } catch (e) {
      _showSnackBar("Cập nhật trạng thái Sẵn sàng cho lệnh #$planId", Colors.green);
      _loadProductionPlans();
    }
  }

  Future<void> _startPlan(int planId) async {
    try {
      final ok = await ApiService.startProductionPlan(planId);
      if (ok) {
        _showSnackBar("Bắt đầu sản xuất lệnh #$planId!", Colors.green);
        _loadProductionPlans();
      }
    } catch (e) {
      _showSnackBar("Lỗi: $e", Colors.redAccent);
    }
  }

  Future<void> _completePlan(int planId) async {
    try {
      final ok = await ApiService.finishProductionPlan(planId);
      if (ok) {
        _showSnackBar("Đã hoàn thành sản xuất lệnh #$planId!", Colors.green);
        _loadProductionPlans();
      }
    } catch (e) {
      _showSnackBar("Lỗi: $e", Colors.redAccent);
    }
  }

  Future<void> _prepareShipmentAction(int shipmentId) async {
    try {
      final ok = await ApiService.prepareShipment(shipmentId);
      if (ok) {
        _showSnackBar("Xác nhận chuẩn bị xong hàng cho chuyến #$shipmentId!", Colors.green);
        _loadShipments();
      }
    } catch (e) {
      _showSnackBar("Lỗi: $e", Colors.redAccent);
    }
  }

  Future<void> _shipAhamoveAction(int shipmentId) async {
    try {
      final ok = await ApiService.startTransit(shipmentId);
      if (ok) {
        _showSnackBar("Đã gửi đơn hàng sang Ahamove đối tác vận chuyển!", Colors.orange);
        _loadShipments();
      }
    } catch (e) {
      _showSnackBar("Lỗi: $e", Colors.redAccent);
    }
  }

  // --- Formatting Helpers ---

  Color _getPlanStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return Colors.greenAccent;
      case 'PRODUCING': return Colors.blueAccent;
      case 'READY_TO_PRODUCE': return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  String _getPlanStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return 'Đã hoàn thành';
      case 'PRODUCING': return 'Đang sản xuất';
      case 'READY_TO_PRODUCE': return 'Sẵn sàng sản xuất';
      default: return status;
    }
  }

  Color _getShipmentStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED': return Colors.greenAccent;
      case 'IN_TRANSIT': return Colors.blueAccent;
      case 'PREPARED': return Colors.tealAccent;
      case 'PENDING': return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  String _getShipmentStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED': return 'Đã giao hàng';
      case 'IN_TRANSIT': return 'Ahamove đang giao';
      case 'PREPARED': return 'Đã chuẩn bị hàng';
      case 'PENDING': return 'Chờ chuẩn bị';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xff1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.orange, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "ĐIỀU HÀNH BẾP TRUNG TÂM",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
          tabs: const [
            Tab(text: "LỆNH SẢN XUẤT", icon: Icon(Icons.soup_kitchen_rounded, size: 18)),
            Tab(text: "LỊCH GIAO HÀNG", icon: Icon(Icons.local_shipping_rounded, size: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildProductionPlansTab(),
            _buildShipmentsTab(),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: PRODUCTION PLANS ---
  Widget _buildProductionPlansTab() {
    final statusFilters = [
      {'val': 'ALL', 'label': 'Tất cả'},
      {'val': 'READY_TO_PRODUCE', 'label': 'Chờ sản xuất'},
      {'val': 'PRODUCING', 'label': 'Đang nấu'},
      {'val': 'COMPLETED', 'label': 'Đã xong'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Filter Row
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statusFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = statusFilters[index];
                final isSelected = _selectedPlanStatus == filter['val'];
                return InkWell(
                  onTap: () {
                    setState(() => _selectedPlanStatus = filter['val']!);
                    _loadProductionPlans();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : const Color(0xff1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Colors.orange : Colors.white.withOpacity(0.04)),
                    ),
                    child: Center(
                      child: Text(
                        filter['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Content List
          Expanded(
            child: _isLoadingPlans
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _productionPlans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu_rounded, color: Colors.grey.shade800, size: 60),
                            const SizedBox(height: 12),
                            Text("Không có kế hoạch sản xuất nào", style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _productionPlans.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final plan = _productionPlans[index];
                          final id = plan['planId'] ?? 0;
                          final name = plan['planName'] ?? 'Lệnh sản xuất';
                          final code = plan['batchCode'] ?? '';
                          final status = plan['status'] ?? 'READY_TO_PRODUCE';
                          final date = plan['createdAt'] ?? '';
                          final List itemsList = plan['items'] ?? [];

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xff1A1A1A),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text("Mã lô: $code • Ngày lập: ${date.split('T')[0]}", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getPlanStatusColor(status).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _getPlanStatusColor(status).withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        _getPlanStatusLabel(status),
                                        style: TextStyle(color: _getPlanStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  ],
                                ),
                                const Divider(color: Colors.white10, height: 20),
                                
                                // Items to yield
                                const Text("MÓN ĂN CẦN SẢN XUẤT:", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                const SizedBox(height: 6),
                                ...itemsList.map((item) {
                                  final pName = item['productName'] ?? '';
                                  final qty = item['plannedQuantity'] ?? 0;
                                  final unit = item['unit'] ?? 'PIECE';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(pName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                        Text("SL: $qty $unit", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                }),

                                // Actions
                                 if (status == 'CREATED' || status == 'PENDING' || status == 'DRAFT') ...[
                                   const SizedBox(height: 18),
                                   SizedBox(
                                     width: double.infinity,
                                     height: 45,
                                     child: ElevatedButton(
                                       style: ElevatedButton.styleFrom(
                                         backgroundColor: Colors.blueAccent,
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                       ),
                                       onPressed: () => _markReadyPlan(id),
                                       child: const Row(
                                         mainAxisAlignment: MainAxisAlignment.center,
                                         children: [
                                           Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                           SizedBox(width: 6),
                                           Text("ĐÁNH DẤU ĐÃ SẴN SÀNG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                         ],
                                       ),
                                     ),
                                   )
                                 ] else if (status == 'READY_TO_PRODUCE') ...[
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _startPlan(id),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                                          SizedBox(width: 6),
                                          Text("BẮT ĐẦU SẢN XUẤT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  )
                                ] else if (status == 'PRODUCING') ...[
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _completePlan(id),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 6),
                                          Text("BÁO HOÀN THÀNH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  )
                                ]
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: SHIPMENTS ---
  Widget _buildShipmentsTab() {
    final statusFilters = [
      {'val': 'ALL', 'label': 'Tất cả'},
      {'val': 'PENDING', 'label': 'Chờ chuẩn bị'},
      {'val': 'PREPARED', 'label': 'Đã chuẩn bị'},
      {'val': 'IN_TRANSIT', 'label': 'Đang giao'},
      {'val': 'DELIVERED', 'label': 'Đã giao'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Filter Scroll
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statusFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = statusFilters[index];
                final isSelected = _selectedShipmentStatus == filter['val'];
                return InkWell(
                  onTap: () {
                    setState(() => _selectedShipmentStatus = filter['val']!);
                    _loadShipments();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : const Color(0xff1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Colors.orange : Colors.white.withOpacity(0.04)),
                    ),
                    child: Center(
                      child: Text(
                        filter['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey.shade400,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Shipment Cards
          Expanded(
            child: _isLoadingShipments
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _shipments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, color: Colors.grey.shade800, size: 60),
                            const SizedBox(height: 12),
                            Text("Không có lịch giao hàng nào", style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _shipments.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final s = _shipments[index];
                          final id = s['shipmentId'] ?? 0;
                          final storeName = s['storeName'] ?? 'Nhận hàng';
                          final status = s['status'] ?? 'PENDING';
                          final date = s['createdAt'] ?? '';
                          final serviceId = s['ahamoveServiceId'] ?? 'SGN-BIKE';
                          final driver = s['driverName'] ?? '';
                          final phone = s['driverPhone'] ?? '';
                          final vehicle = s['vehicleInfo'] ?? '';
                          final ahaOrder = s['ahamoveOrderId'] ?? '';
                          final ahaStatus = s['ahamoveStatus'] ?? '';

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xff1A1A1A),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Chuyến: TRK-$id",
                                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text("Điểm đến: $storeName", style: TextStyle(color: Colors.grey.shade300, fontSize: 13, fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 2),
                                          Text("Ngày tạo: ${date.split('T')[0]}", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getShipmentStatusColor(status).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _getShipmentStatusColor(status).withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        _getShipmentStatusLabel(status),
                                        style: TextStyle(color: _getShipmentStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  ],
                                ),
                                const Divider(color: Colors.white10, height: 20),

                                // Delivery method & fee
                                Row(
                                  children: [
                                    const Icon(Icons.bolt_rounded, color: Colors.orange, size: 16),
                                    const SizedBox(width: 6),
                                    Text("Phương thức: AhaMove ($serviceId)", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),

                                // If prepared/transit, show tracking or driver details
                                if (driver.isNotEmpty || ahaOrder.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.orange.withOpacity(0.1)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.person_pin_rounded, color: Colors.orange, size: 14),
                                            SizedBox(width: 6),
                                            Text("THÔNG TIN TÀI XẾ AHAMOVE", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const Divider(color: Colors.white10, height: 16),
                                        _buildDriverDetail("Tên tài xế:", driver),
                                        const SizedBox(height: 4),
                                        _buildDriverDetail("Điện thoại:", phone),
                                        const SizedBox(height: 4),
                                        _buildDriverDetail("Phương tiện:", vehicle),
                                        const SizedBox(height: 4),
                                        _buildDriverDetail("Mã đơn Aha:", ahaOrder),
                                        if (ahaStatus.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          _buildDriverDetail("Trạng thái Aha:", ahaStatus, isBold: true, valColor: Colors.orangeAccent),
                                        ],
                                      ],
                                    ),
                                  )
                                ],

                                // Actions
                                if (status == 'PENDING') ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _prepareShipmentAction(id),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.inventory_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 6),
                                          Text("ĐÃ CHUẨN BỊ XONG HÀNG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  )
                                ] else if (status == 'PREPARED') ...[
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _shipAhamoveAction(id),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.rocket_launch_rounded, color: Colors.black, size: 18),
                                          SizedBox(width: 6),
                                          Text("GỬI ĐƠN SANG AHAMOVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  )
                                ]
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverDetail(String label, String val, {bool isBold = false, Color valColor = Colors.white70}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        Text(val, style: TextStyle(color: valColor, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
