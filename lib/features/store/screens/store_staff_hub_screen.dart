import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class StoreStaffHubScreen extends StatefulWidget {
  final int initialTab;

  const StoreStaffHubScreen({super.key, this.initialTab = 0});

  @override
  State<StoreStaffHubScreen> createState() => _StoreStaffHubScreenState();
}

class _StoreStaffHubScreenState extends State<StoreStaffHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Tab 1: Orders State ---
  bool _isLoadingOrders = true;
  List<Map<String, dynamic>> _orders = [];
  String _selectedOrderStatus = "ALL";

  // --- Tab 2 & 3: Shipments State ---
  bool _isLoadingShipments = true;
  List<Map<String, dynamic>> _shipments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadOrders();
    _loadShipments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Loading Logic ---

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _isLoadingOrders = true);

    try {
      final list = await ApiService.fetchMyOrders(status: _selectedOrderStatus);

      if (mounted) {
        setState(() {
          _orders = list;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi tải đơn hàng: $e", Colors.redAccent);
    }
  }

  Future<void> _loadShipments() async {
    if (!mounted) return;
    setState(() => _isLoadingShipments = true);

    try {
      final list = await ApiService.fetchShipments();
      final storeId = ApiService.currentUser?.storeId;

      if (mounted) {
        setState(() {
          if (storeId != null) {
            _shipments = list.where((s) => s['storeId'] == storeId).toList();
          } else {
            _shipments = list;
          }
          _isLoadingShipments = false;
        });
      }
    } catch (e) {
      _showSnackBar("Lỗi tải chuyến giao hàng: $e", Colors.redAccent);
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

  Future<void> _submitOrderAction(int orderId) async {
    try {
      final ok = await ApiService.submitStoreOrder(orderId);
      if (ok) {
        _showSnackBar("Đã gửi đơn hàng #$orderId thành công lên Bếp trung tâm!", Colors.green);
        _loadOrders();
      }
    } catch (e) {
      _showSnackBar("Lỗi: $e", Colors.redAccent);
    }
  }

  Future<void> _confirmReceiptAction(int shipmentId, int stopId) async {
    try {
      final ok = await ApiService.confirmShipmentDelivery(shipmentId, stopId: stopId);
      if (ok) {
        _showSnackBar("Xác nhận nhận hàng thành công cho chuyến TRK-$shipmentId!", Colors.green);
        _loadShipments();
        _loadOrders();
      }
    } catch (e) {
      _showSnackBar("Lỗi: $e", Colors.redAccent);
    }
  }

  void _openPlaceOrderBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return PlaceOrderBottomSheet(
          onSaved: () {
            _loadOrders();
          },
        );
      },
    );
  }

  // --- Formatting Helpers ---

  String _formatCurrency(dynamic amount) {
    if (amount == null) return "0 đ";
    try {
      final int parsed = int.parse(amount.toString());
      final String str = parsed.toString();
      if (str.length <= 3) return "$str đ";
      
      final buffer = StringBuffer();
      int count = 0;
      for (int i = str.length - 1; i >= 0; i--) {
        buffer.write(str[i]);
        count++;
        if (count == 3 && i != 0) {
          buffer.write('.');
          count = 0;
        }
      }
      return "${buffer.toString().split('').reversed.join('')} đ";
    } catch (_) {
      return "$amount đ";
    }
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED': return Colors.greenAccent;
      case 'APPROVED': return Colors.blueAccent;
      case 'SUBMITTED': return Colors.orangeAccent;
      case 'DRAFT': return Colors.grey;
      case 'REJECTED': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  String _getOrderStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED': return 'Đã nhận hàng';
      case 'APPROVED': return 'Đã duyệt';
      case 'SUBMITTED': return 'Chờ duyệt';
      case 'DRAFT': return 'Bản nháp';
      case 'REJECTED': return 'Bị từ chối';
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
      case 'DELIVERED': return 'Đã nhận hàng';
      case 'IN_TRANSIT': return 'Đang đi giao';
      case 'PREPARED': return 'Sẵn sàng giao';
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
          "CỬA HÀNG NHƯỢNG QUYỀN",
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.1),
          tabs: const [
            Tab(text: "ĐƠN HÀNG", icon: Icon(Icons.assignment_rounded, size: 18)),
            Tab(text: "ĐANG GIAO", icon: Icon(Icons.location_on_rounded, size: 18)),
            Tab(text: "NHẬN HÀNG", icon: Icon(Icons.check_circle_outline_rounded, size: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOrdersTab(),
            _buildDeliveringTab(),
            _buildConfirmReceiptTab(),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: ORDERS (Đặt đơn nhượng quyền) ---
  Widget _buildOrdersTab() {
    final statusFilters = [
      {'val': 'ALL', 'label': 'Tất cả'},
      {'val': 'DRAFT', 'label': 'Bản nháp'},
      {'val': 'SUBMITTED', 'label': 'Chờ duyệt'},
      {'val': 'APPROVED', 'label': 'Đã duyệt'},
      {'val': 'DELIVERED', 'label': 'Đã nhận'},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _openPlaceOrderBottomSheet,
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Status filters
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: statusFilters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = statusFilters[index];
                  final isSelected = _selectedOrderStatus == filter['val'];
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedOrderStatus = filter['val']!);
                      _loadOrders();
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

            // Orders list
            Expanded(
              child: _isLoadingOrders
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : _orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, color: Colors.grey.shade800, size: 60),
                              const SizedBox(height: 12),
                              Text("Không có đơn hàng nhượng quyền nào", style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _orders.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final o = _orders[index];
                            final id = o['orderId'] ?? 0;
                            final status = o['status'] ?? 'DRAFT';
                            final total = o['totalAmount'] ?? 0;
                            final date = o['orderDate'] ?? '';
                            final List itemsList = o['items'] ?? [];

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
                                              "MÃ ĐƠN: #$id",
                                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            Text("Ngày tạo: ${date.split('T')[0]}", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _getOrderStatusColor(status).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _getOrderStatusColor(status).withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          _getOrderStatusLabel(status),
                                          style: TextStyle(color: _getOrderStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    ],
                                  ),
                                  const Divider(color: Colors.white10, height: 20),

                                  // List Items
                                  const Text("CHI TIẾT MÓN ĐẶT:", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                  const SizedBox(height: 6),
                                  ...itemsList.map((item) {
                                    final pName = item['name'] ?? 'Món';
                                    final qty = item['quantity'] ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(pName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                          Text("x$qty", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  }),

                                  const Divider(color: Colors.white10, height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Tổng số tiền:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      Text(
                                        _formatCurrency(total),
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),

                                  // Action (Send order)
                                  if (status == 'DRAFT') ...[
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 45,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () => _submitOrderAction(id),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.send_rounded, color: Colors.black, size: 16),
                                            SizedBox(width: 6),
                                            Text("GỬI ĐƠN HÀNG DUYỆT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
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
            )
          ],
        ),
      ),
    );
  }

  // --- TAB 2: DELIVERING (Đang giao & Theo dõi hành trình AhaMove) ---
  Widget _buildDeliveringTab() {
    final deliveringShipments = _shipments.where((s) => s['status'] == 'IN_TRANSIT').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _isLoadingShipments
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : deliveringShipments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.near_me_outlined, color: Colors.grey.shade800, size: 60),
                      const SizedBox(height: 12),
                      Text("Không có đơn hàng nào đang đi giao", style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: deliveringShipments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final s = deliveringShipments[index];
                    final id = s['shipmentId'] ?? 0;
                    final date = s['createdAt'] ?? '';
                    final serviceId = s['ahamoveServiceId'] ?? 'SGN-BIKE';
                    final driver = s['driverName'] ?? 'Tài xế AhaMove';
                    final phone = s['driverPhone'] ?? '';
                    final vehicle = s['vehicleInfo'] ?? '';
                    final ahaOrder = s['ahamoveOrderId'] ?? '';
                    final ahaStatus = s['ahamoveStatus'] ?? 'Đang giao';

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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Chuyến giao: TRK-$id",
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text("Khởi hành: ${date.split('T')[0]}", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                                ),
                                child: const Text(
                                  "Đang vận chuyển",
                                  style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 20),

                          Row(
                            children: [
                              const Icon(Icons.delivery_dining_rounded, color: Colors.orange, size: 16),
                              const SizedBox(width: 6),
                              Text("Phương thức: AhaMove ($serviceId)", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Driver Details Card
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
                                    Text("TÀI XẾ PHỤ TRÁCH GIAO HÀNG", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Divider(color: Colors.white10, height: 16),
                                _buildDetailRow("Họ tên tài xế:", driver),
                                const SizedBox(height: 4),
                                _buildDetailRow("Số điện thoại:", phone),
                                const SizedBox(height: 4),
                                _buildDetailRow("Phương tiện:", vehicle),
                                const SizedBox(height: 4),
                                _buildDetailRow("Mã vận đơn Aha:", ahaOrder),
                                const SizedBox(height: 4),
                                _buildDetailRow("Trạng thái Aha:", ahaStatus, valColor: Colors.orangeAccent),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orange, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xff1A1A1A),
                                    title: const Text("Theo Dõi Hành Trình AhaMove", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Mã vận đơn AhaMove: ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(ahaOrder.isNotEmpty ? ahaOrder : 'AHA-KITCHEN-104', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        const Text("Trạng thái từ đối tác:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                                            const SizedBox(width: 6),
                                            Text(ahaStatus, style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Text("Đối tác AhaMove đang cập nhật định vị GPS thời gian thực của tài xế trên bản đồ vệ tinh.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("ĐỒNG Ý", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                      )
                                    ],
                                  ),
                                );
                              },
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map_rounded, color: Colors.orange, size: 16),
                                  SizedBox(width: 6),
                                  Text("THEO DÕI HÀNH TRÌNH AHAMOVE", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  // --- TAB 3: RECEIVE SHIPMENT (Nhận hàng - Chỉ có nút xác nhận là đã nhận) ---
  Widget _buildConfirmReceiptTab() {
    final receiptShipments = _shipments.where((s) => s['status'] == 'IN_TRANSIT').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _isLoadingShipments
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : receiptShipments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Colors.grey.shade800, size: 60),
                      const SizedBox(height: 12),
                      Text(
                        "Không có chuyến hàng nào cần nhận",
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: receiptShipments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final s = receiptShipments[index];
                    final id = s['shipmentId'] ?? 0;
                    final status = s['status'] ?? 'PENDING';
                    final date = s['createdAt'] ?? '';
                    final serviceId = s['ahamoveServiceId'] ?? 'SGN-BIKE';
                    final List stopsList = s['stops'] ?? [];
                    final myStop = stopsList.firstWhere(
                      (stop) => stop['storeId'] == ApiService.currentUser?.storeId,
                      orElse: () => null,
                    );
                    final stopId = myStop != null ? (myStop['stopId'] ?? 0) : 0;
                    final List<int> orderIds = [];
                    for (var stop in stopsList) {
                      final List oIds = stop['storeOrderIds'] ?? [];
                      orderIds.addAll(oIds.cast<int>());
                    }

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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Mã Vận Chuyển: TRK-$id",
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text("Khởi hành: ${date.split('T')[0]}", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                ],
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

                          Text("Đối tác giao hàng: AhaMove ($serviceId)", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text("Đơn hàng đi kèm: #${orderIds.join(', #')}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),

                          // Confirm action (Single clean button, no driver details)
                          if (status == 'IN_TRANSIT') ...[
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _confirmReceiptAction(id, stopId),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text("XÁC NHẬN Đstyle NHẬN Đstyle HÀNG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
    );
  }

  Widget _buildDetailRow(String label, String val, {Color valColor = Colors.white70}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        Text(val, style: TextStyle(color: valColor, fontSize: 12)),
      ],
    );
  }
}

// --- Place franchise order bottom sheet ---
class PlaceOrderBottomSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const PlaceOrderBottomSheet({super.key, required this.onSaved});

  @override
  State<PlaceOrderBottomSheet> createState() => _PlaceOrderBottomSheetState();
}

class _PlaceOrderBottomSheetState extends State<PlaceOrderBottomSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _menuProducts = [];
  final Map<int, int> _selectedQuantities = {}; // productId -> quantity
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final products = await ApiService.fetchProducts();
      if (mounted) {
        setState(() {
          _menuProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  Future<void> _saveOrder() async {
    final List<Map<String, dynamic>> itemsPayload = [];
    _selectedQuantities.forEach((prodId, qty) {
      if (qty > 0) {
        itemsPayload.add({
          'productId': prodId,
          'quantity': qty,
        });
      }
    });

    if (itemsPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn ít nhất 1 món ăn!")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'items': itemsPayload,
        'deliveryDate': DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0],
      };

      await ApiService.createStoreOrder(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đặt đơn hàng Bản nháp thành công!"), backgroundColor: Colors.green));
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi đặt đơn: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: _isLoading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.orange)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.add_shopping_cart_rounded, color: Colors.orange, size: 22),
                    SizedBox(width: 8),
                    Text("ĐẶT ĐƠN HÀNG NHƯỢNG QUYỀN", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text("Chọn món ăn & số lượng cần đặt từ Bếp trung tâm:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView.separated(
                    itemCount: _menuProducts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = _menuProducts[index];
                      final id = p['id'] as int;
                      final name = p['name'] ?? '';
                      final price = p['price'] ?? 0;
                      final unit = p['unit'] ?? 'PIECE';
                      final currentQty = _selectedQuantities[id] ?? 0;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff0F0F0F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${price.toString()} đ / $unit",
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  )
                                ],
                              ),
                            ),
                            
                            // Quantity selector
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.grey, size: 22),
                                  onPressed: () {
                                    if (currentQty > 0) {
                                      setState(() => _selectedQuantities[id] = currentQty - 1);
                                    }
                                  },
                                ),
                                SizedBox(
                                  width: 28,
                                  child: Center(
                                    child: Text(
                                      "$currentQty",
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.orange, size: 22),
                                  onPressed: () {
                                    setState(() => _selectedQuantities[id] = currentQty + 1);
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isSaving ? null : _saveOrder,
                    child: _isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                        : const Text("LƯU ĐƠN BẢN NHÁP", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}
