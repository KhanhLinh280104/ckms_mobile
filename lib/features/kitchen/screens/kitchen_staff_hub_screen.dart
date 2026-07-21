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
    _ensureUserFullName();
    _loadProductionPlans();
    _loadShipments();
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
      for (var p in list) {
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
          if (_selectedPlanStatus != "ALL") {
            _productionPlans = list.where((p) {
              final s = (p['status'] ?? '').toString().toUpperCase();
              if (_selectedPlanStatus == 'PLANNED') {
                return s == 'PLANNED' || s == 'CREATED' || s == 'PENDING' || s == 'DRAFT';
              } else if (_selectedPlanStatus == 'READY_TO_PRODUCE') {
                return s == 'READY_TO_PRODUCE';
              } else if (_selectedPlanStatus == 'IN_PRODUCTION') {
                return s == 'IN_PRODUCTION' || s == 'PRODUCING';
              } else if (_selectedPlanStatus == 'FINISHED') {
                return s == 'FINISHED' || s == 'PRODUCED' || s == 'COMPLETED';
              }
              return s == _selectedPlanStatus;
            }).toList();
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
      final ok = await ApiService.markProductionPlanReady(planId);
      if (ok) {
        _showSnackBar("Đã đánh dấu ĐÃ SẴN SÀNG cho lệnh sản xuất #$planId!", Colors.green);
        _loadProductionPlans();
      }
    } catch (e) {
      _showSnackBar("Lỗi đánh dấu sẵn sàng: $e", Colors.redAccent);
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

  Future<void> _completePlan(Map<String, dynamic> plan) async {
    final int planId = plan['planId'] ?? plan['id'] ?? 0;
    List items = await ApiService.resolveProductionPlanItems(plan);

    if (items.isEmpty) {
      try {
        final planDetail = await ApiService.getProductionPlanDetails(planId);
        if (planDetail.isNotEmpty) {
          items = planDetail['items'] ?? planDetail['details'] ?? planDetail['outputs'] ?? [];
        }
      } catch (_) {}
    }

    final Map<int, TextEditingController> qtyControllers = {};
    for (var item in items) {
      final pid = item['productId'] ?? item['id'] ?? 0;
      final plannedQty = item['plannedQuantity'] ?? item['targetQuantity'] ?? item['quantity'] ?? 1;
      qtyControllers[pid] = TextEditingController(text: plannedQty.toString());
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.done_all_rounded, color: Colors.greenAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Báo sản lượng #$planId",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Xác nhận sản lượng sản xuất thực tế:",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Nhấn xác nhận để hoàn tất lệnh sản xuất.",
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  )
                else
                  ...items.map((item) {
                    final pid = item['productId'] ?? item['id'] ?? 0;
                    final pName = item['productName'] ?? item['name'] ?? 'Sản phẩm #$pid';
                    final unit = item['unit'] ?? 'PIECE';
                    final ctrl = qtyControllers[pid];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$pName ($unit)",
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: "Số lượng thực tế",
                              labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                              filled: true,
                              fillColor: Colors.black,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.orange),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final List<Map<String, dynamic>> outputs = [];
                for (var item in items) {
                  final pid = item['productId'] ?? item['id'] ?? 0;
                  final ctrl = qtyControllers[pid];
                  final actualQty = int.tryParse(ctrl?.text ?? '') ?? (item['plannedQuantity'] ?? item['quantity'] ?? 1);
                  outputs.add({
                    'productId': pid,
                    'actualQty': actualQty,
                  });
                }

                if (outputs.isEmpty) {
                  outputs.add({
                    'productId': plan['productId'] ?? 1,
                    'actualQty': 1,
                  });
                }

                Navigator.pop(context);
                await _submitCompletePlan(planId, outputs);
              },
              child: const Text("XÁC NHẬN HOÀN THÀNH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitCompletePlan(int planId, List<Map<String, dynamic>> outputs) async {
    try {
      final ok = await ApiService.finishProductionPlan(planId, outputs: outputs);
      if (ok) {
        _showSnackBar("Đã hoàn thành sản xuất lệnh #$planId!", Colors.green);
        _loadProductionPlans();
      }
    } catch (e) {
      _showSnackBar("Lỗi hoàn thành sản xuất: ${e.toString().replaceAll('Exception: ', '')}", Colors.redAccent);
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
      case 'FINISHED':
      case 'PRODUCED':
      case 'COMPLETED':
        return Colors.greenAccent;
      case 'IN_PRODUCTION':
      case 'PRODUCING':
        return Colors.blueAccent;
      case 'READY_TO_PRODUCE':
        return Colors.amberAccent;
      case 'PLANNED':
      case 'CREATED':
      case 'PENDING':
      case 'DRAFT':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  String _getPlanStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'FINISHED':
      case 'PRODUCED':
      case 'COMPLETED':
        return 'Đã nấu xong';
      case 'IN_PRODUCTION':
      case 'PRODUCING':
        return 'Đang nấu';
      case 'READY_TO_PRODUCE':
        return 'Chờ nấu';
      case 'PLANNED':
      case 'CREATED':
      case 'PENDING':
      case 'DRAFT':
        return 'Chờ đánh dấu';
      default:
        return status;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "ĐIỀU HÀNH BẾP TRUNG TÂM",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            Text(
              "Xin chào, ${ApiService.currentUser?.name.isNotEmpty == true && ApiService.currentUser?.name != 'User' ? ApiService.currentUser!.name : 'Bếp'}",
              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
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
      {'val': 'PLANNED', 'label': 'Chờ đánh dấu'},
      {'val': 'READY_TO_PRODUCE', 'label': 'Chờ nấu'},
      {'val': 'IN_PRODUCTION', 'label': 'Đang nấu'},
      {'val': 'FINISHED', 'label': 'Đã nấu xong'},
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
                    setState(() {
                      _selectedPlanStatus = filter['val']!;
                    });
                    _loadProductionPlans();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : const Color(0xff1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Colors.orange : Colors.white.withOpacity(0.08)),
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
                          final status = (plan['status'] ?? 'PLANNED').toString();
                          final date = plan['createdAt'] ?? '';
                          final List itemsList = plan['items'] ?? [];

                          final stUpper = status.toUpperCase();

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
                                          Text("Mã lô: $code • Ngày lập: ${date.contains('T') ? date.split('T')[0] : date}", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
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
                                  final pName = item['productName'] ?? item['name'] ?? 'Sản phẩm';
                                  final qty = item['plannedQuantity'] ?? item['quantity'] ?? 0;
                                  final actual = item['actualQuantity'] ?? item['actualQty'];
                                  final unit = item['unit'] ?? 'PIECE';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(pName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                        Text(
                                          actual != null ? "Kế hoạch: $qty $unit (Thực tế: $actual)" : "SL: $qty $unit",
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                // Materials Dropdown
                                Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
                                    iconColor: Colors.orange,
                                    collapsedIconColor: Colors.grey.shade400,
                                    title: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, color: Colors.orange, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          "NGUYÊN LIỆU CẦN THIẾT (${(plan['materials'] as List?)?.length ?? 0})",
                                          style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                                        ),
                                      ],
                                    ),
                                    onExpansionChanged: (expanded) async {
                                      if (expanded && ((plan['materials'] as List?) == null || (plan['materials'] as List).isEmpty)) {
                                        try {
                                          final detail = await ApiService.getProductionPlanDetails(id);
                                          if (detail.isNotEmpty && mounted) {
                                            setState(() {
                                              plan['materials'] = detail['materials'] ?? [];
                                              if (detail['items'] != null && (detail['items'] as List).isNotEmpty) {
                                                plan['items'] = detail['items'];
                                              }
                                            });
                                          }
                                        } catch (_) {}
                                      }
                                    },
                                    children: [
                                      if ((plan['materials'] as List?) == null || (plan['materials'] as List).isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 6),
                                          child: Text("Đang tải hoặc không có thông tin nguyên liệu", style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                                        )
                                      else
                                        ...((plan['materials'] as List).map((mat) {
                                          final mName = mat['materialName'] ?? mat['name'] ?? 'Nguyên liệu';
                                          final reqQty = mat['requiredQuantity'] ?? mat['quantity'] ?? 0;
                                          final mUnit = mat['unit'] ?? 'KG';
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.grain_rounded, color: Colors.orangeAccent, size: 14),
                                                    const SizedBox(width: 6),
                                                    Text(mName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                                  ],
                                                ),
                                                Text("Cần: $reqQty $mUnit", style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          );
                                        }).toList()),
                                    ],
                                  ),
                                ),

                                // Actions
                                if (stUpper == 'PLANNED' || stUpper == 'CREATED' || stUpper == 'PENDING' || stUpper == 'DRAFT') ...[
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _markReadyPlan(id),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check_circle_outline_rounded, color: Colors.black, size: 18),
                                          SizedBox(width: 6),
                                          Text("ĐÁNH DẤU SẴN SÀNG", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  )
                                ] else if (stUpper == 'READY_TO_PRODUCE') ...[
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
                                          Text("BẮT ĐẦU NẤU", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  )
                                ] else if (stUpper == 'IN_PRODUCTION' || stUpper == 'PRODUCING') ...[
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _completePlan(plan),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
                                          SizedBox(width: 6),
                                          Text("BÁO HOÀN THÀNH (ĐÃ NẤU XONG)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
