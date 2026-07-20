import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../admin/screens/admin_hub_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../coordinator/screens/coordinator_hub_screen.dart';
import '../../manager/screens/manager_hub_screen.dart';
import '../../kitchen/screens/kitchen_staff_hub_screen.dart';
import '../../store/screens/store_staff_hub_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _activities = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final statsFuture = ApiService.fetchDashboardStats();
      final activitiesFuture = ApiService.fetchRecentActivity();

      final results = await Future.wait([statsFuture, activitiesFuture]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _activities = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Lỗi tải dữ liệu: ${e.toString().replaceAll("Exception: ", "")}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Đăng xuất",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?",
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                ApiService.currentUser = null;
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text(
                "Xác nhận",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFeatureUnderDevelopment(String featureName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    color: Colors.orange,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  featureName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Tính năng này đang được phát triển cho ứng dụng Mobile. Vui lòng sử dụng phiên bản Web để thao tác đầy đủ hoặc quay lại ở phiên bản tiếp theo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "ĐÃ HIỂU",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Badge styling based on status ---
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F0F0F),
      body: SafeArea(
        child: RefreshIndicator(
          color: Colors.orange,
          backgroundColor: const Color(0xff1A1A1A),
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                if (ApiService.isOfflineMockMode) _buildOfflineBanner(),
                const SizedBox(height: 24),
                _buildSectionTitle(Icons.insights, "Chỉ Số Hoạt Động"),
                const SizedBox(height: 12),
                _buildStatsSection(),
                const SizedBox(height: 28),
                _buildSectionTitle(Icons.grid_view, "Trung Tâm Điều Hành"),
                const SizedBox(height: 12),
                _buildQuickActionsSection(),
                const SizedBox(height: 28),
                _buildSectionTitle(Icons.history, "Hoạt Động Gần Đây"),
                const SizedBox(height: 12),
                _buildRecentActivitySection(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange, size: 18),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final userName = widget.user.name.isNotEmpty ? widget.user.name : "User";
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Active Role badge with Flexible to prevent right overflow
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withOpacity(
                                _pulseController.value * 0.7 + 0.3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(
                                    _pulseController.value * 0.4,
                                  ),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          "Vai trò: ${widget.user.vietnameseRole}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Logout & Refresh actions with compact density
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    icon: const Icon(Icons.sync_rounded, color: Colors.grey, size: 20),
                    onPressed: _isLoading ? null : _loadData,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    icon: const Icon(
                      Icons.power_settings_new_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Chào mừng trở lại,",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.user.storeId != null
                ? "Quản lý tại: ${widget.user.storeName}"
                : (widget.user.kitchenId != null
                      ? "Phụ trách: ${widget.user.kitchenName ?? 'Bếp trung tâm'}"
                      : "Hệ thống Bếp Trung Tâm CKMS"),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Máy chủ ngoại tuyến. Đang chạy trong chế độ Demo.",
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_isLoading) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: List.generate(
          widget.user.role == 'ADMIN' || widget.user.role == 'KITCHEN_STAFF'
              ? 2
              : (widget.user.role == 'COORDINATOR' ? 3 : 1),
          (index) => Container(
            decoration: BoxDecoration(
              color: const Color(0xff1A1A1A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.orange,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final List<Widget> statCards = [];

    if (widget.user.role == 'ADMIN') {
      statCards.add(
        _buildStatCard(
          "Số Cửa Hàng",
          _stats['activeStores'] ?? 0,
          Icons.store,
          Colors.amber,
        ),
      );
      statCards.add(
        _buildStatCard(
          "Người Dùng",
          _stats['activeUsers'] ?? 0,
          Icons.people_alt,
          Colors.blue,
        ),
      );
    } else if (widget.user.role == 'COORDINATOR') {
      statCards.add(
        _buildStatCard(
          "Chờ Xử Lý",
          _stats['pendingOrders'] ?? 0,
          Icons.shopping_bag,
          Colors.orange,
        ),
      );
      statCards.add(
        _buildStatCard(
          "Đang Giao",
          _stats['pendingShipments'] ?? 0,
          Icons.local_shipping,
          Colors.blue,
        ),
      );
      statCards.add(
        _buildStatCard(
          "Tổng Cửa Hàng",
          _stats['activeStores'] ?? 0,
          Icons.store,
          Colors.amber,
        ),
      );
    } else if (widget.user.role == 'KITCHEN_STAFF') {
      statCards.add(
        _buildStatCard(
          "KH Sản Xuất",
          _stats['productionPlans'] ?? 0,
          Icons.assignment,
          Colors.amber,
        ),
      );
      statCards.add(
        _buildStatCard(
          "Chuyến Xe",
          _stats['pendingShipments'] ?? 0,
          Icons.local_shipping,
          Colors.blue,
        ),
      );
    } else {
      // STORE_STAFF / MANAGER
      statCards.add(
        _buildStatCard(
          "Đơn Của Tôi",
          _stats['pendingOrders'] ?? 0,
          Icons.receipt_long,
          Colors.orange,
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: statCards,
    );
  }

  Widget _buildStatCard(
    String title,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final List<Map<String, dynamic>> actions = [];

    if (widget.user.role == 'ADMIN') {
      actions.addAll([
        {
          'name': 'Nhân sự',
          'icon': Icons.people_alt_rounded,
          'color': Colors.redAccent,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminHubScreen(initialTab: 0),
            ),
          ),
        },
        {
          'name': 'Cửa hàng',
          'icon': Icons.storefront_rounded,
          'color': Colors.amber,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminHubScreen(initialTab: 1),
            ),
          ),
        },
        {
          'name': 'Hóa đơn',
          'icon': Icons.payments_rounded,
          'color': Colors.orange,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminHubScreen(initialTab: 2),
            ),
          ),
        },
        {
          'name': 'Báo cáo',
          'icon': Icons.analytics_rounded,
          'color': Colors.purpleAccent,
          'action': () => _showFeatureUnderDevelopment('Báo cáo'),
        },
      ]);
    } else if (widget.user.role == 'MANAGER') {
      actions.addAll([
        {
          'name': 'Sản phẩm',
          'icon': Icons.inventory_2_rounded,
          'color': Colors.teal,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerHubScreen(initialTab: 0),
            ),
          ),
        },
        {
          'name': 'Nguyên liệu',
          'icon': Icons.receipt_long_rounded,
          'color': Colors.indigoAccent,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerHubScreen(initialTab: 1),
            ),
          ),
        },
        {
          'name': 'Danh mục',
          'icon': Icons.category_rounded,
          'color': Colors.amber,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerHubScreen(initialTab: 2),
            ),
          ),
        },
        {
          'name': 'Hóa đơn',
          'icon': Icons.payments_rounded,
          'color': Colors.orange,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ManagerHubScreen(initialTab: 3),
            ),
          ),
        },
      ]);
    } else if (widget.user.role == 'COORDINATOR') {
      actions.addAll([
        {
          'name': 'Đơn hàng',
          'icon': Icons.assignment_rounded,
          'color': Colors.orange,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CoordinatorHubScreen(initialTab: 0),
            ),
          ),
        },
        {
          'name': 'Vận chuyển',
          'icon': Icons.local_shipping_rounded,
          'color': Colors.blue,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CoordinatorHubScreen(initialTab: 1),
            ),
          ),
        },
        {
          'name': 'Báo cáo',
          'icon': Icons.analytics_rounded,
          'color': Colors.purpleAccent,
          'action': () => _showFeatureUnderDevelopment('Báo cáo'),
        },
      ]);
    } else if (widget.user.role == 'KITCHEN_STAFF') {
      actions.addAll([
        {
          'name': 'Sản xuất',
          'icon': Icons.soup_kitchen_rounded,
          'color': Colors.orange,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KitchenStaffHubScreen(initialTab: 0),
            ),
          ),
        },
        {
          'name': 'Giao hàng',
          'icon': Icons.local_shipping_rounded,
          'color': Colors.teal,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KitchenStaffHubScreen(initialTab: 1),
            ),
          ),
        },
        {
          'name': 'Báo cáo',
          'icon': Icons.analytics_rounded,
          'color': Colors.purpleAccent,
          'action': () => _showFeatureUnderDevelopment('Báo cáo'),
        },
      ]);
    } else if (widget.user.role == 'STORE_STAFF') {
      actions.addAll([
        {
          'name': 'Đơn hàng',
          'icon': Icons.assignment_rounded,
          'color': Colors.orange,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StoreStaffHubScreen(initialTab: 0),
            ),
          ),
        },
        {
          'name': 'Nhận hàng',
          'icon': Icons.check_circle_outline_rounded,
          'color': Colors.teal,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StoreStaffHubScreen(initialTab: 1),
            ),
          ),
        },
        {
          'name': 'Hóa đơn',
          'icon': Icons.receipt_long_rounded,
          'color': Colors.purpleAccent,
          'action': () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StoreStaffHubScreen(initialTab: 2),
            ),
          ),
        },
      ]);
    } else {
      actions.addAll([
        {
          'name': 'Đơn hàng',
          'icon': Icons.assignment_rounded,
          'color': Colors.orange,
          'action': () => _showFeatureUnderDevelopment('Đơn hàng'),
        },
        {
          'name': 'Vận chuyển',
          'icon': Icons.local_shipping_rounded,
          'color': Colors.blue,
          'action': () => _showFeatureUnderDevelopment('Vận chuyển'),
        },
        {
          'name': 'Báo cáo',
          'icon': Icons.analytics_rounded,
          'color': Colors.purpleAccent,
          'action': () => _showFeatureUnderDevelopment('Báo cáo'),
        },
      ]);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        final VoidCallback actionCallback = action['action'] as VoidCallback;
        return InkWell(
          onTap: actionCallback,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xff1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  action['icon'] as IconData,
                  color: action['color'] as Color,
                  size: 24,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action['name'] as String,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivitySection() {
    if (_isLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xff1A1A1A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    if (_activities.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xff1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.02)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              color: Colors.grey.shade700,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              "Không có hoạt động mới nào",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final activity = _activities[index];
        final bool isOrder = activity['type'] == 'ORDER';
        final status = activity['status'] as String? ?? 'PENDING';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xff1A1A1A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Icon(
                        isOrder
                            ? Icons.inventory_2_rounded
                            : Icons.local_shipping_rounded,
                        color: isOrder ? Colors.orange : Colors.blueAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['title'] as String? ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity['subtitle'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(status).withOpacity(0.2),
                  ),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
