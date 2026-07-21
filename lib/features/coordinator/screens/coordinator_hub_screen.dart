import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';

class CoordinatorHubScreen extends StatefulWidget {
  final int initialTab;

  const CoordinatorHubScreen({super.key, this.initialTab = 0});

  @override
  State<CoordinatorHubScreen> createState() => _CoordinatorHubScreenState();
}

class _CoordinatorHubScreenState extends State<CoordinatorHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Orders Tab State
  bool _isLoadingOrders = true;
  List<Map<String, dynamic>> _orders = [];
  String _selectedOrderStatus = "ALL";

  // Shipments Tab State
  bool _isLoadingShipments = true;
  List<Map<String, dynamic>> _shipments = [];
  String _selectedShipmentStatus = "ALL";

  // Kitchen Progress Tab State
  bool _isLoadingKitchenPlans = true;
  List<Map<String, dynamic>> _kitchenPlans = [];
  String _selectedKitchenPlanStatus = "ALL";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _ensureUserFullName();
    _loadOrders();
    _loadShipments();
    _loadKitchenPlans();
  }

  Future<void> _ensureUserFullName() async {
    final user = ApiService.currentUser;
    if (user != null && (user.name.isEmpty || user.name == 'User')) {
      final uId = int.tryParse(user.id);
      if (uId != null && uId > 0) {
        final profile = await ApiService.fetchUserById(uId);
        if (profile != null) {
          final fn =
              profile['fullName'] ?? profile['name'] ?? profile['username'];
          if (fn != null && fn.toString().isNotEmpty && mounted) {
            setState(() {
              ApiService.currentUser = ApiService.currentUser?.copyWith(
                name: fn.toString(),
              );
            });
          }
        }
      }
    }
  }

  Future<void> _loadKitchenPlans() async {
    setState(() => _isLoadingKitchenPlans = true);
    try {
      final plans = await ApiService.fetchProductionPlans();
      for (var p in plans) {
        if (p['items'] == null || (p['items'] as List).isEmpty) {
          try {
            final items = await ApiService.resolveProductionPlanItems(p);
            if (items.isNotEmpty) {
              p['items'] = items;
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          if (_selectedKitchenPlanStatus != "ALL") {
            _kitchenPlans = plans.where((p) {
              final s = (p['status'] ?? '').toString().toUpperCase();
              if (_selectedKitchenPlanStatus == 'PLANNED') {
                return s == 'PLANNED' ||
                    s == 'CREATED' ||
                    s == 'PENDING' ||
                    s == 'DRAFT';
              } else if (_selectedKitchenPlanStatus == 'READY_TO_PRODUCE') {
                return s == 'READY_TO_PRODUCE';
              } else if (_selectedKitchenPlanStatus == 'IN_PRODUCTION') {
                return s == 'IN_PRODUCTION' || s == 'PRODUCING';
              } else if (_selectedKitchenPlanStatus == 'FINISHED') {
                return s == 'FINISHED' || s == 'PRODUCED' || s == 'COMPLETED';
              }
              return s == _selectedKitchenPlanStatus;
            }).toList();
          } else {
            _kitchenPlans = plans;
          }
          _isLoadingKitchenPlans = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingKitchenPlans = false);
    }
  }

  Future<void> _launchAhamoveLink(String link) async {
    String url = link;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://tracking.ahamove.com/$link';
    }
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Mã AhaMove: $url"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Mã AhaMove: $url"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoadingOrders = true;
    });

    try {
      final orders = await ApiService.fetchOrdersList(
        status: _selectedOrderStatus,
      );
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoadingOrders = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Lỗi tải danh sách đơn hàng: ${e.toString().replaceAll("Exception: ", "")}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadShipments() async {
    setState(() {
      _isLoadingShipments = true;
    });

    try {
      final shipments = await ApiService.fetchShipmentsList(
        status: _selectedShipmentStatus,
      );
      if (mounted) {
        setState(() {
          _shipments = shipments;
          _isLoadingShipments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingShipments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Lỗi tải danh sách chuyến xe: ${e.toString().replaceAll("Exception: ", "")}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleUpdateOrderStatus(int orderId, String status) async {
    try {
      final success = await ApiService.updateOrderStatus(orderId, status);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'APPROVED'
                  ? "Đã duyệt đơn hàng thành công!"
                  : "Đã từ chối đơn hàng thành công!",
            ),
            backgroundColor: status == 'APPROVED'
                ? Colors.green
                : Colors.redAccent,
            duration: const Duration(seconds: 1),
          ),
        );
        _loadOrders();
        // Also reload shipments since they might depend on approved orders
        _loadShipments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Thao tác thất bại: ${e.toString().replaceAll("Exception: ", "")}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleStartTransit(int shipmentId) async {
    try {
      final success = await ApiService.startShipmentTransit(shipmentId);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã xác nhận xuất kho. Bắt đầu giao chuyến xe!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        _loadShipments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Thao tác thất bại: ${e.toString().replaceAll("Exception: ", "")}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAddShipmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return const AddShipmentForm();
      },
    ).then((value) {
      if (value == true) {
        _loadShipments();
        _loadOrders(); // Orders status might change to ALLOCATED
      }
    });
  }

  void _showOrderDetailBottomSheet(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final id = order['orderId'] ?? 0;
        final storeName = order['storeName'] ?? 'Cửa hàng';
        final status = order['status'] ?? 'SUBMITTED';
        final totalAmount = order['totalAmount'] ?? 0;
        final items = order['items'] as List? ?? [];
        final date = (order['orderDate'] ?? '2026-07-14').split('T')[0];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "MÃ ĐƠN HÀNG: #$id",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Ngày đặt: $date • Chi nhánh: $storeName",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const Divider(color: Colors.white12, height: 24),
                const Text(
                  "CHI TIẾT MÓN ĂN:",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),

                // Items List
                Flexible(
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            "Không có danh sách món ăn.",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: Colors.white10, height: 12),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item['name'] ?? 'Món ăn',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "x${item['quantity'] ?? 1}",
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const Divider(color: Colors.white12, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Tổng cộng giá trị:",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatCurrency(totalAmount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // AhaMove Tracking link button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final tracking =
                          order['ahamoveOrderId'] ??
                          order['trackingUrl'] ??
                          order['shipmentId'] ??
                          'AHA-ORDER-$id';
                      _launchAhamoveLink(tracking.toString());
                    },
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.orange,
                      size: 16,
                    ),
                    label: const Text(
                      "Xem link AhaMove (Tracking)",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick approve directly inside details sheet
                if (status == 'SUBMITTED') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _handleUpdateOrderStatus(id, 'REJECTED');
                          },
                          child: const Text(
                            "TỪ CHỐI",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _handleUpdateOrderStatus(id, 'APPROVED');
                          },
                          child: const Text(
                            "DUYỆT ĐƠN",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "ĐÓNG",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

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
        final String decimalPart = (val - intPart)
            .toStringAsFixed(2)
            .split('.')[1]
            .replaceAll(RegExp(r'0+$'), '');
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

  Color _getStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'SUBMITTED' || s == 'PENDING') return Colors.orange;
    if (s == 'APPROVED' || s == 'PREPARED') return Colors.blueAccent;
    if (s == 'ALLOCATED' || s == 'IN_TRANSIT') return Colors.purpleAccent;
    if (s == 'DELIVERED') return Colors.greenAccent;
    if (s == 'REJECTED' || s == 'CANCELLED') return Colors.redAccent;
    return Colors.grey;
  }

  String _getStatusLabel(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'SUBMITTED':
        return 'Chờ duyệt';
      case 'APPROVED':
        return 'Đã duyệt';
      case 'ALLOCATED':
        return 'Đã phân bổ';
      case 'DELIVERED':
        return 'Hoàn thành';
      case 'REJECTED':
        return 'Từ chối';
      case 'DRAFT':
        return 'Bản nháp';
      case 'PENDING':
        return 'Mới tạo';
      case 'PREPARED':
        return 'Đã chuẩn bị';
      case 'IN_TRANSIT':
        return 'Đang giao';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xff1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.orange,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "TRUNG TÂM ĐIỀU PHỐI",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              "Xin chào, ${ApiService.currentUser?.name.isNotEmpty == true && ApiService.currentUser?.name != 'User' ? ApiService.currentUser!.name : 'Coordinator'}",
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
          tabs: const [
            Tab(
              text: "ĐƠN HÀNG",
              icon: Icon(Icons.assignment_rounded, size: 18),
            ),
            Tab(
              text: "VẬN CHUYỂN",
              icon: Icon(Icons.local_shipping_rounded, size: 18),
            ),
            Tab(
              text: "TIẾN ĐỘ BẾP",
              icon: Icon(Icons.soup_kitchen_rounded, size: 18),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOrdersTab(),
            _buildShipmentsTab(),
            _buildKitchenProgressTab(),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: ORDERS ---
  Widget _buildOrdersTab() {
    final statusList = [
      {'val': 'ALL', 'label': 'Tất cả'},
      {'val': 'SUBMITTED', 'label': 'Chờ duyệt'},
      {'val': 'APPROVED', 'label': 'Đã duyệt'},
      {'val': 'DELIVERED', 'label': 'Hoàn thành'},
      {'val': 'REJECTED', 'label': 'Bị từ chối'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Filter Horizontal scroll
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statusList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final f = statusList[index];
                final isSelected = _selectedOrderStatus == f['val'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOrderStatus = f['val']!;
                    });
                    _loadOrders();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.orange
                          : const Color(0xff1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.orange
                            : Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        f['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : Colors.grey.shade400,
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

          // Orders List
          Expanded(
            child: _isLoadingOrders
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : _orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          color: Colors.grey.shade800,
                          size: 60,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Không có đơn hàng nào",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final id = order['orderId'] ?? 0;
                      final storeName = order['storeName'] ?? 'Cửa hàng';
                      final totalAmount = order['totalAmount'] ?? 0;
                      final status = order['status'] ?? 'SUBMITTED';
                      final dateStr = (order['orderDate'] ?? '2026-07-14')
                          .split('T')[0];

                      return InkWell(
                        onTap: () => _showOrderDetailBottomSheet(order),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xff1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.04),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      storeName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _buildStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Mã ĐH: #$id • $dateStr",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(totalAmount),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              // Quick actions if pending coordinator approval
                              if (status == 'SUBMITTED') ...[
                                const Divider(
                                  color: Colors.white10,
                                  height: 20,
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _handleUpdateOrderStatus(
                                        id,
                                        'REJECTED',
                                      ),
                                      child: const Text(
                                        "TỪ CHỐI",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: () => _handleUpdateOrderStatus(
                                        id,
                                        'APPROVED',
                                      ),
                                      child: const Text(
                                        "DUYỆT",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
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
    final statusList = [
      {'val': 'ALL', 'label': 'Tất cả'},
      {'val': 'PENDING', 'label': 'Chờ nhận xe'},
      {'val': 'PREPARED', 'label': 'Chuẩn bị xong'},
      {'val': 'IN_TRANSIT', 'label': 'Đang giao'},
      {'val': 'DELIVERED', 'label': 'Đã giao'},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _showAddShipmentBottomSheet,
        child: const Icon(Icons.add_road_rounded, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Filter Horizontal scroll
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: statusList.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final f = statusList[index];
                  final isSelected = _selectedShipmentStatus == f['val'];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedShipmentStatus = f['val']!;
                      });
                      _loadShipments();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.orange
                            : const Color(0xff1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange
                              : Colors.white.withOpacity(0.04),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          f['label']!,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : Colors.grey.shade400,
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

            // Shipments List
            Expanded(
              child: _isLoadingShipments
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    )
                  : _shipments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            color: Colors.grey.shade800,
                            size: 60,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Không có chuyến xe nào",
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _shipments.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final shipment = _shipments[index];
                        final id = shipment['shipmentId'] ?? 0;
                        final storeName = shipment['storeName'] ?? 'Cửa hàng';
                        final status = shipment['status'] ?? 'PENDING';
                        final driverName = shipment['driverName'] ?? 'Chưa gán';
                        final vehicle = shipment['vehicleInfo'] ?? 'Chưa rõ';
                        final dateStr = (shipment['createdAt'] ?? '2026-07-14')
                            .split('T')[0];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xff1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.04),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "CHUYẾN XE: TRK-$id",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  _buildStatusBadge(status),
                                ],
                              ),
                              const Divider(color: Colors.white10, height: 20),
                              _buildInfoLine(
                                Icons.storefront_rounded,
                                "Nơi nhận",
                                storeName,
                              ),
                              const SizedBox(height: 6),
                              _buildInfoLine(
                                Icons.person_rounded,
                                "Tài xế",
                                driverName,
                              ),
                              const SizedBox(height: 6),
                              _buildInfoLine(
                                Icons.badge_rounded,
                                "Phương tiện",
                                vehicle,
                              ),
                              const SizedBox(height: 6),
                              _buildInfoLine(
                                Icons.calendar_month_rounded,
                                "Ngày tạo",
                                dateStr,
                              ),

                              // Quick transit action if Prepared (Kitchen has prepared it)
                              if (status == 'PREPARED') ...[
                                const Divider(
                                  color: Colors.white10,
                                  height: 20,
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 38,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _handleStartTransit(id),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.departure_board_rounded,
                                          color: Colors.black,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "BẮT ĐẦU GIAO (START TRANSIT)",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoLine(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 14),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildKitchenProgressTab() {
    final statusFilters = [
      {'val': 'ALL', 'label': 'Tất cả'},
      {'val': 'PLANNED', 'label': 'Chờ đánh dấu'},
      {'val': 'READY_TO_PRODUCE', 'label': 'Chờ nấu'},
      {'val': 'IN_PRODUCTION', 'label': 'Đang nấu'},
      {'val': 'FINISHED', 'label': 'Đã nấu xong'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.soup_kitchen_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "TIẾN ĐỘ SẢN XUẤT BẾP TRUNG TÂM",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                onPressed: _loadKitchenPlans,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status Filter Bar
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statusFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = statusFilters[index];
                final isSelected = _selectedKitchenPlanStatus == filter['val'];
                return InkWell(
                  onTap: () {
                    setState(() => _selectedKitchenPlanStatus = filter['val']!);
                    _loadKitchenPlans();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.orange
                          : const Color(0xff1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.orange
                            : Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filter['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black
                              : Colors.grey.shade400,
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

          Expanded(
            child: _isLoadingKitchenPlans
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : _kitchenPlans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.grey.shade800,
                          size: 60,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Bếp chưa có kế hoạch sản xuất nào",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _kitchenPlans.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final plan = _kitchenPlans[index];
                      final id = plan['planId'] ?? plan['id'] ?? 0;
                      final planName = plan['planName'] ?? 'Lệnh sản xuất #$id';
                      final status = plan['status'] ?? 'PLANNED';
                      final kitchenName =
                          plan['kitchenName'] ?? 'Bếp trung tâm';
                      final code = plan['batchCode'] ?? '';
                      final date = plan['createdAt'] ?? '';
                      final List items = plan['items'] ?? [];

                      Color statusColor = Colors.grey;
                      String statusText = status.toString();
                      switch (status.toString().toUpperCase()) {
                        case 'FINISHED':
                        case 'PRODUCED':
                        case 'COMPLETED':
                          statusColor = Colors.greenAccent;
                          statusText = "Đã nấu xong";
                          break;
                        case 'IN_PRODUCTION':
                        case 'PRODUCING':
                          statusColor = Colors.blueAccent;
                          statusText = "Đang nấu";
                          break;
                        case 'READY_TO_PRODUCE':
                          statusColor = Colors.amberAccent;
                          statusText = "Chờ nấu";
                          break;
                        case 'PLANNED':
                        case 'CREATED':
                        case 'PENDING':
                        case 'DRAFT':
                          statusColor = Colors.orangeAccent;
                          statusText = "Chờ đánh dấu";
                          break;
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xff1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        planName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (code.toString().isNotEmpty ||
                                          date.toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          "${code.toString().isNotEmpty ? 'Mã lô: $code • ' : ''}${date.toString().contains('T') ? 'Ngày: ${date.toString().split('T')[0]}' : ''}",
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 2),
                                      Text(
                                        "Phụ trách: $kitchenName",
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: statusColor.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 20),
                            const Text(
                              "MÓN ĂN CẦN SẢN XUẤT:",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...items.map((it) {
                              final name =
                                  it['productName'] ?? it['name'] ?? 'Sản phẩm';
                              final qty =
                                  it['plannedQuantity'] ?? it['quantity'] ?? 0;
                              final actual =
                                  it['actualQuantity'] ?? it['actualQty'];
                              final unit = it['unit'] ?? 'PIECE';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      actual != null
                                          ? "Kế hoạch: $qty $unit (Thực tế: $actual)"
                                          : "$qty $unit",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // Materials Dropdown
                            Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 4,
                                ),
                                iconColor: Colors.orange,
                                collapsedIconColor: Colors.grey.shade400,
                                title: Row(
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "NGUYÊN LIỆU CẦN THIẾT (${(plan['materials'] as List?)?.length ?? 0})",
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                                onExpansionChanged: (expanded) async {
                                  if (expanded &&
                                      ((plan['materials'] as List?) == null ||
                                          (plan['materials'] as List)
                                              .isEmpty)) {
                                    final int planId =
                                        plan['planId'] ?? plan['id'] ?? 0;
                                    try {
                                      final detail =
                                          await ApiService.getProductionPlanDetails(
                                            planId,
                                          );
                                      if (detail.isNotEmpty && mounted) {
                                        setState(() {
                                          plan['materials'] =
                                              detail['materials'] ?? [];
                                          if (detail['items'] != null &&
                                              (detail['items'] as List)
                                                  .isNotEmpty) {
                                            plan['items'] = detail['items'];
                                          }
                                        });
                                      }
                                    } catch (_) {}
                                  }
                                },
                                children: [
                                  if ((plan['materials'] as List?) == null ||
                                      (plan['materials'] as List).isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        "Đang tải hoặc không có thông tin nguyên liệu",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    )
                                  else
                                    ...((plan['materials'] as List).map((mat) {
                                      final mName =
                                          mat['materialName'] ??
                                          mat['name'] ??
                                          'Nguyên liệu';
                                      final reqQty =
                                          mat['requiredQuantity'] ??
                                          mat['quantity'] ??
                                          0;
                                      final mUnit = mat['unit'] ?? 'KG';
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.05,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.grain_rounded,
                                                  color: Colors.orangeAccent,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  mName,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              "Cần: $reqQty $mUnit",
                                              style: const TextStyle(
                                                color: Colors.amberAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList()),
                                ],
                              ),
                            ),
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
}

class AddShipmentForm extends StatefulWidget {
  const AddShipmentForm({super.key});

  @override
  State<AddShipmentForm> createState() => _AddShipmentFormState();
}

class _AddShipmentFormState extends State<AddShipmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _vehicleController = TextEditingController();

  bool _isLoadingDropdowns = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _approvedOrders = [];

  int? _selectedStoreId;
  int? _selectedOrderId;
  String _selectedService = "SGN-BIKE";

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    try {
      final storesFuture = ApiService.fetchStores();
      // Load orders with status APPROVED to link to shipment
      final ordersFuture = ApiService.fetchOrdersList(status: 'APPROVED');

      final results = await Future.wait([storesFuture, ordersFuture]);

      if (mounted) {
        setState(() {
          _stores = results[0];
          _approvedOrders = results[1];
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load stores or orders: $e");
      if (mounted) {
        setState(() {
          _isLoadingDropdowns = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn cửa hàng nhận")),
      );
      return;
    }
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn đơn hàng gán kèm")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final store = _stores.firstWhere(
      (s) => s['id'] == _selectedStoreId,
      orElse: () => {},
    );
    final storeName = store['name'] ?? 'Cửa hàng';

    final payload = {
      'ahamoveServiceId': _selectedService,
      'productionPlanId': 301,
      'dropPoints': [
        {
          'storeId': _selectedStoreId,
          'storeOrderIds': [_selectedOrderId],
          'remarks': 'Giao đơn #${_selectedOrderId}',
        },
      ],
      'remarks': 'Giao hàng theo chuyến điều phối',
    };

    try {
      await ApiService.createShipment(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tạo chuyến xe điều phối thành công!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = [
      {'val': 'SGN-BIKE', 'label': 'Ahamove Xe máy (Bike)'},
      {'val': 'SGN-TRUCK-500', 'label': 'Xe tải 500kg (Truck)'},
      {'val': 'SGN-TRUCK-1000', 'label': 'Xe tải 1000kg (Truck)'},
    ];

    // Filter orders mapped to the selected store
    final filteredOrders = _selectedStoreId == null
        ? <Map<String, dynamic>>[]
        : _approvedOrders
              .where((o) => o['storeId'] == _selectedStoreId)
              .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: _isLoadingDropdowns
          ? const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.orange,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "ĐIỀU PHỐI CHUYẾN XE MỚI",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Store Selector
                    Text(
                      "CỬA HÀNG NHẬN",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      dropdownColor: const Color(0xff1A1A1A),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      value: _selectedStoreId,
                      onChanged: (val) {
                        setState(() {
                          _selectedStoreId = val;
                          _selectedOrderId = null; // reset order
                        });
                      },
                      validator: (val) =>
                          val == null ? "Vui lòng chọn cửa hàng" : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _stores.map((s) {
                        final id = s['id'] as int;
                        final name = s['name'] as String;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Order Selector
                    Text(
                      "ĐƠN HÀNG ĐÃ DUYỆT (APPROVED)",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      dropdownColor: const Color(0xff1A1A1A),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      value: _selectedOrderId,
                      onChanged: (val) {
                        setState(() {
                          _selectedOrderId = val;
                        });
                      },
                      validator: (val) => val == null
                          ? "Vui lòng chọn đơn hàng liên kết"
                          : null,
                      disabledHint: Text(
                        _selectedStoreId == null
                            ? "Chọn cửa hàng trước"
                            : "Không có đơn hàng đã duyệt",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      // Only show dropdown items if store is selected
                      items: _selectedStoreId == null
                          ? null
                          : filteredOrders.isEmpty
                          ? null
                          : filteredOrders.map((o) {
                              final id = o['orderId'] as int;
                              final total = o['totalAmount'] ?? 0;
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  "Đơn Hàng #$id - ${total ~/ 1000}k đ",
                                ),
                              );
                            }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Driver Name
                    Text(
                      "TÊN TÀI XẾ",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _driverNameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? "Vui lòng nhập tên tài xế"
                          : null,
                      decoration: InputDecoration(
                        hintText: "VD: Nguyễn Văn Tài",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Driver Phone
                    Text(
                      "SỐ ĐIỆN THOẠI TÀI XẾ",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _driverPhoneController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.phone,
                      validator: (val) => val == null || val.trim().length < 9
                          ? "Số điện thoại không hợp lệ"
                          : null,
                      decoration: InputDecoration(
                        hintText: "VD: 0901234567",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Vehicle plate
                    Text(
                      "THÔNG TIN XE / BIỂN SỐ XE",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _vehicleController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? "Vui lòng nhập thông tin xe"
                          : null,
                      decoration: InputDecoration(
                        hintText: "VD: Xe Tải - 29C-12345",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Service Dropdown
                    Text(
                      "DỊCH VỤ VẬN CHUYỂN",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xff1A1A1A),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      value: _selectedService,
                      onChanged: (val) {
                        setState(() {
                          _selectedService = val!;
                        });
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: services.map((s) {
                        return DropdownMenuItem<String>(
                          value: s['val'],
                          child: Text(s['label']!),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 28),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submitForm,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "TẠO CHUYẾN XE",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }
}
