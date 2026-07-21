import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  int _currentPage = 0;
  final int _pageSize = 10;
  int _totalPages = 1;
  int _totalElements = 0;

  // --- Tab 2: Shipments State ---
  bool _isLoadingShipments = true;
  List<Map<String, dynamic>> _shipments = [];

  // --- Tab 3: Billing State ---
  bool _isLoadingBilling = true;
  List<Map<String, dynamic>> _billingStatements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _ensureUserFullName();
    _loadOrders();
    _loadShipments();
    _loadBilling();
  }

  Future<void> _ensureUserFullName() async {
    final user = ApiService.currentUser;
    if (user != null && (user.name.isEmpty || user.name == 'User')) {
      final uId = int.tryParse(user.id);
      if (uId != null && uId > 0) {
        final profile = await ApiService.fetchUserById(uId);
        if (profile != null) {
          final fn = profile['fullName'] ?? profile['name'] ?? profile['username'];
          if (fn != null && fn.toString().isNotEmpty && mounted) {
            setState(() {
              ApiService.currentUser = ApiService.currentUser?.copyWith(name: fn.toString());
            });
          }
        }
      }
    }
  }

  Future<void> _loadBilling() async {
    if (!mounted) return;
    setState(() => _isLoadingBilling = true);
    try {
      final list = await ApiService.fetchBillingStatements(storeId: ApiService.currentUser?.storeId);
      if (mounted) {
        setState(() {
          _billingStatements = list;
          _isLoadingBilling = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBilling = false);
    }
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
      final res = await ApiService.fetchMyOrdersPaginated(
        status: _selectedOrderStatus,
        page: _currentPage,
        size: _pageSize,
      );

      if (mounted) {
        setState(() {
          _orders = (res['content'] as List? ?? []).cast<Map<String, dynamic>>();
          _totalPages = res['totalPages'] ?? 1;
          _totalElements = res['totalElements'] ?? 0;
          _currentPage = res['number'] ?? 0;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Lỗi tải đơn hàng: $e", Colors.redAccent);
        setState(() => _isLoadingOrders = false);
      }
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
      final double val = double.parse(amount.toString());
      if (val % 1 == 0) {
        final int intVal = val.toInt();
        final String str = intVal.toString();
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
      } else {
        final int intPart = val.truncate();
        final String decimalPart = (val - intPart).toStringAsFixed(2).split('.')[1].replaceAll(RegExp(r'0+$'), '');
        final String str = intPart.toString();
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
        final formattedInt = buffer.toString().split('').reversed.join('');
        return "$formattedInt,$decimalPart đ";
      }
    } catch (_) {
      return "$amount đ";
    }
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED': return Colors.greenAccent;
      case 'IN_TRANSIT':
      case 'SHIPPING':
      case 'DELIVERING': return Colors.purpleAccent;
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
      case 'IN_TRANSIT':
      case 'SHIPPING':
      case 'DELIVERING': return 'Đang vận chuyển';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "CỬA HÀNG NHƯỢNG QUYỀN",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            Text(
              "Xin chào, ${ApiService.currentUser?.name.isNotEmpty == true && ApiService.currentUser?.name != 'User' ? ApiService.currentUser!.name : 'Cửa hàng'}",
              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.1),
          tabs: const [
            Tab(text: "ĐƠN HÀNG", icon: Icon(Icons.assignment_rounded, size: 18)),
            Tab(text: "NHẬN HÀNG", icon: Icon(Icons.check_circle_outline_rounded, size: 18)),
            Tab(text: "HÓA ĐƠN", icon: Icon(Icons.receipt_long_rounded, size: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOrdersTab(),
            _buildConfirmReceiptTab(),
            _buildBillingTab(),
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
      {'val': 'IN_TRANSIT', 'label': 'Đang vận chuyển'},
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
                      setState(() {
                        _selectedOrderStatus = filter['val']!;
                        _currentPage = 0;
                      });
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
                            final deliveryDate = o['deliveryDate'] ?? '';
                            final storeName = o['storeName'] ?? '';
                            final storePhone = o['storePhone'] ?? '';
                            final List itemsList = o['orderDetails'] ?? o['items'] ?? [];

                            // Tim shipment khop neu co
                            final matchingShipment = _shipments.firstWhere((s) {
                              final List stops = s['stops'] ?? [];
                              for (var stop in stops) {
                                final List oIds = stop['storeOrderIds'] ?? [];
                                if (oIds.contains(id)) return true;
                              }
                              return s['ahamoveOrderId'] == o['batchCode'] || s['shipmentId'] == o['batchId'];
                            }, orElse: () => <String, dynamic>{});

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
                                            Text(
                                              "Ngày tạo: ${date.toString().contains('T') ? date.toString().split('T')[0] : date}",
                                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                            ),
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
                                  
                                  // Section store info & delivery date
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff0F0F0F),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_rounded, color: Colors.orangeAccent, size: 13),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Ngày giao hàng: ${deliveryDate.toString().contains('T') ? deliveryDate.toString().split('T')[0] : (deliveryDate.toString().isNotEmpty ? deliveryDate : 'Chưa xếp')}",
                                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        if (storeName.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.storefront_rounded, color: Colors.grey, size: 13),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  "Cửa hàng: $storeName ${storePhone.isNotEmpty ? '($storePhone)' : ''}",
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),

                                  const Divider(color: Colors.white10, height: 20),

                                  // List Items
                                  const Text("CHI TIẾT MÓN ĐẶT:", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                  const SizedBox(height: 8),
                                  ...itemsList.map((item) {
                                    final pName = item['productName'] ?? item['name'] ?? 'Món';
                                    final qty = item['quantity'] ?? 0;
                                    final unit = item['unit'] ?? '';
                                    final unitPrice = item['unitPrice'];
                                    final subTotal = item['subTotal'];

                                    return Container(
                                      margin: const EdgeInsets.symmetric(vertical: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xff0F0F0F),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white.withOpacity(0.03)),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(pName.toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                              ),
                                              Text(
                                                "x$qty ${unit.toString().isNotEmpty ? unit : ''}",
                                                style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          if (unitPrice != null || subTotal != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                if (unitPrice != null)
                                                  Text("Đơn giá: ${_formatCurrency(unitPrice)}", style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                                if (subTotal != null)
                                                  Text("Thành tiền: ${_formatCurrency(subTotal)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            )
                                          ]
                                        ],
                                      ),
                                    );
                                  }),

                                  const Divider(color: Colors.white10, height: 20),
                                  
                                  // Detailed Fee Breakdown
                                  if (o['orderFee'] != null) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Tiền món đặt (Order fee):", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        Text(
                                          _formatCurrency(o['orderFee']),
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  
                                  // Shipping Fee Row
                                  (() {
                                    final sFee = o['shippingFee'];
                                    final bool hasFee = sFee != null &&
                                        (sFee is num ? sFee > 0 : (int.tryParse(sFee.toString()) ?? 0) > 0);
                                    return Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Tiền ship:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                            Text(
                                              hasFee ? _formatCurrency(sFee) : "Chưa có",
                                              style: TextStyle(
                                                color: hasFee ? Colors.orangeAccent : Colors.grey,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Text("Tổng số tiền:", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                                if (!hasFee) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "(chưa tính ship)",
                                                    style: TextStyle(color: Colors.orangeAccent.shade200, fontSize: 11, fontStyle: FontStyle.italic),
                                                  ),
                                                ]
                                              ],
                                            ),
                                            Text(
                                              _formatCurrency(total),
                                              style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  })(),

                                  // AhaMove Shipping Information Dropdown
                                  _OrderShipmentDropdown(
                                    order: o,
                                    matchingShipment: matchingShipment.isNotEmpty ? matchingShipment : null,
                                    onLaunchTracking: (link) => _launchAhamoveTracking(link),
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
            ),

            // Pagination Controls
            if (_totalPages > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xff1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage > 0 ? Colors.orange : const Color(0xff2A2A2A),
                        foregroundColor: _currentPage > 0 ? Colors.black : Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: _currentPage > 0 && !_isLoadingOrders
                          ? () {
                              setState(() => _currentPage--);
                              _loadOrders();
                            }
                          : null,
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 12),
                      label: const Text("Trước", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      "Trang ${_currentPage + 1} / $_totalPages\n(Tổng $_totalElements đơn)",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage < _totalPages - 1 ? Colors.orange : const Color(0xff2A2A2A),
                        foregroundColor: _currentPage < _totalPages - 1 ? Colors.black : Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: _currentPage < _totalPages - 1 && !_isLoadingOrders
                          ? () {
                              setState(() => _currentPage++);
                              _loadOrders();
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                      label: const Text("Sau", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
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

                          // Logistics Info Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xff0F0F0F),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow("Mã vận đơn AhaMove:", s['ahamoveOrderId'] ?? 'AHA-TRK-$id'),
                                const SizedBox(height: 6),
                                _buildDetailRow("Phương tiện:", s['vehicleInfo'] ?? serviceId),
                                const SizedBox(height: 6),
                                _buildDetailRow("Trạng thái vận chuyển:", _getShipmentStatusLabel(status), valColor: _getShipmentStatusColor(status)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          
                          // 2 Side-by-Side Action Buttons: [ Left: Đã nhận hàng | Right: Theo dõi đơn ]
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => _confirmReceiptAction(id, stopId),
                                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                                  label: const Text(
                                    "Đã nhận hàng",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.orange, width: 1.2),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () {
                                    final trackingUrl = s['trackingUrl'] ?? s['ahamoveTrackingUrl'] ?? s['ahamoveOrderId'] ?? 'AHA-TRK-$id';
                                    _launchAhamoveTracking(trackingUrl);
                                  },
                                  icon: const Icon(Icons.open_in_new_rounded, color: Colors.orange, size: 16),
                                  label: const Text(
                                    "Theo dõi đơn",
                                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Future<void> _launchAhamoveTracking(String link) async {
    if (link.isEmpty || link == 'null') return;

    String urlStr = link.trim();
    if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
      urlStr = 'https://$urlStr';
    }
    final Uri uri = Uri.parse(urlStr);

    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      }
      if (!launched) {
        _showCopyLinkDialog(urlStr);
      }
    } catch (_) {
      _showCopyLinkDialog(urlStr);
    }
  }

  void _showCopyLinkDialog(String url) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("Link Theo Dõi AhaMove", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Không thể tự động mở trình duyệt. Bạn có thể sao chép liên kết bên dưới để dán vào trình duyệt:",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff0F0F0F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Đóng", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              _showSnackBar("Đã sao chép đường dẫn theo dõi!", Colors.green);
            },
            icon: const Icon(Icons.copy_rounded, color: Colors.black, size: 16),
            label: const Text("Sao chép Link", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(Map<String, dynamic> statement) {
    String paymentMethod = "BANK_TRANSFER";
    final refController = TextEditingController();
    final statementId = statement['statementId'] ?? statement['id'] ?? 0;
    final totalAmount = statement['totalAmount'] ?? statement['orderTotal'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1A1A1A),
              title: const Text("Thanh Toán Hóa Đơn", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Tổng tiền: ${totalAmount.toString()} VND", style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  const Text("Phương thức thanh toán", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xff1A1A1A),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    value: paymentMethod,
                    onChanged: (val) => setDlgState(() => paymentMethod = val!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xff0F0F0F),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Chuyển khoản (VietQR)')),
                      DropdownMenuItem(value: 'MOMO', child: Text('Ví MoMo')),
                      DropdownMenuItem(value: 'CASH', child: Text('Tiền mặt')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text("Mã giao dịch / Ghi chú", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: refController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Nhập mã giao dịch chuyển khoản...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xff0F0F0F),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      int methodId = 1;
                      if (paymentMethod == 'MOMO') methodId = 2;
                      if (paymentMethod == 'CASH') methodId = 3;

                      final ok = await ApiService.updateBillingStatementStatus(
                        statementId,
                        'PAID',
                        paymentMethodId: methodId,
                        transactionReference: refController.text.trim(),
                      );
                      if (ok) {
                        _showSnackBar("Xác nhận thanh toán thành công!", Colors.green);
                        _loadBilling();
                      }
                    } catch (e) {
                      _showSnackBar("Lỗi thanh toán: $e", Colors.redAccent);
                    }
                  },
                  child: const Text("Xác nhận thanh toán", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBillingTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _isLoadingBilling
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _billingStatements.isEmpty
              ? Center(
                  child: Text("Không có hóa đơn nào", style: TextStyle(color: Colors.grey.shade500)),
                )
              : ListView.separated(
                  itemCount: _billingStatements.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _billingStatements[index];
                    final cycleName = item['cycleName'] ?? item['title'] ?? 'Kỳ thanh toán';
                    final totalAmount = item['totalAmount'] ?? item['orderTotal'] ?? 0;
                    final status = item['status'] ?? 'ISSUED';
                    final isPaid = status == 'PAID';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xff1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cycleName,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPaid ? "ĐÃ THANH TOÁN" : "CHỜ THANH TOÁN",
                                  style: TextStyle(
                                    color: isPaid ? Colors.greenAccent : Colors.orangeAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${totalAmount.toString()} VND",
                            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (!isPaid) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                                label: const Text("Thanh toán Hóa đơn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                onPressed: () => _showPaymentDialog(item),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
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
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));

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
        'deliveryDate': _deliveryDate.toIso8601String().split('T')[0],
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
                const SizedBox(height: 12),

                // Delivery Date Selector Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff0F0F0F),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.event_rounded, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text("Ngày giao hàng dự kiến:", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _deliveryDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(primary: Colors.orange, onPrimary: Colors.black, surface: Color(0xff1A1A1A)),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _deliveryDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Text(
                            "${_deliveryDate.day}/${_deliveryDate.month}/${_deliveryDate.year}",
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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

class _OrderShipmentDropdown extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic>? matchingShipment;
  final Function(String) onLaunchTracking;

  const _OrderShipmentDropdown({
    required this.order,
    this.matchingShipment,
    required this.onLaunchTracking,
  });

  @override
  State<_OrderShipmentDropdown> createState() => _OrderShipmentDropdownState();
}

class _OrderShipmentDropdownState extends State<_OrderShipmentDropdown> {
  bool _isExpanded = false;

  String? _getNonEmptyString(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty || str == 'null') return null;
    return str;
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final s = widget.matchingShipment;

    final rawAhaStatus = _getNonEmptyString(o['ahamoveStatus']) ?? _getNonEmptyString(s?['ahamoveStatus']);
    final rawDriverName = _getNonEmptyString(o['driverName']) ?? _getNonEmptyString(s?['driverName']);
    final rawDriverPhone = _getNonEmptyString(o['driverPhone']) ?? _getNonEmptyString(s?['driverPhone']);
    final rawTrackingLink = _getNonEmptyString(o['trackingLink']) ?? _getNonEmptyString(s?['trackingUrl']) ?? _getNonEmptyString(s?['ahamoveTrackingUrl']);

    final ahaStatusDisplay = rawAhaStatus ?? "Chưa có";
    
    String driverDisplay = "Chưa có";
    if (rawDriverName != null && rawDriverPhone != null) {
      driverDisplay = "$rawDriverName ($rawDriverPhone)";
    } else if (rawDriverName != null) {
      driverDisplay = rawDriverName;
    } else if (rawDriverPhone != null) {
      driverDisplay = rawDriverPhone;
    }

    final bool hasTrackingLink = rawTrackingLink != null &&
        (rawTrackingLink.startsWith('http://') || rawTrackingLink.startsWith('https://') || rawTrackingLink.contains('.'));

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: const Color(0xff0F0F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hasTrackingLink ? Colors.orange.withOpacity(0.3) : Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping_rounded, color: hasTrackingLink ? Colors.orange : Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        "Thông tin Ship (AhaMove)",
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRow("Trạng thái AhaMove:", ahaStatusDisplay, valColor: rawAhaStatus != null ? Colors.orangeAccent : Colors.grey),
                  const SizedBox(height: 6),
                  _buildRow("Tên tài xế:", driverDisplay, valColor: (rawDriverName != null || rawDriverPhone != null) ? Colors.white : Colors.grey),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: hasTrackingLink ? Colors.orange : Colors.grey.shade800,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: hasTrackingLink ? Colors.orange.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                      ),
                      onPressed: hasTrackingLink ? () => widget.onLaunchTracking(rawTrackingLink) : null,
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: hasTrackingLink ? Colors.orange : Colors.grey.shade600,
                        size: 16,
                      ),
                      label: Text(
                        hasTrackingLink ? "THEO DÕI ĐƠN AHAMOVE" : "CHƯA CÓ LINK THEO DÕI",
                        style: TextStyle(
                          color: hasTrackingLink ? Colors.orange : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRow(String label, String val, {Color valColor = Colors.white70}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: TextStyle(color: valColor, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
