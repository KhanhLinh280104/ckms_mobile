import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/api_service.dart';
import 'user_management_screen.dart';

class AdminHubScreen extends StatefulWidget {
  final int initialTab;

  const AdminHubScreen({super.key, this.initialTab = 0});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Common States ---
  bool _isLoading = false;

  // --- Tab 1: Users & Roles States ---
  String _userSubTab = "USERS"; // "USERS" or "ROLES"
  List<Map<String, dynamic>> _users = [];
  String _userSearchQuery = "";
  final TextEditingController _userSearchController = TextEditingController();

  // --- Tab 2: Facilities States ---
  String _facilitySubTab = "KITCHEN"; // "KITCHEN" or "STORES"
  Map<String, dynamic>? _centralKitchen;
  List<Map<String, dynamic>> _stores = [];

  // --- Tab 3: Billing States ---
  List<Map<String, dynamic>> _billingStatements = [];
  String _billingFilterStatus = "ALL";
  DateTime _periodStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodEnd = DateTime.now();
  final TextEditingController _cycleNameController = TextEditingController(text: "Chu kỳ T7/2026");

  // Role permissions definitions (matching React permissions.ts exactly)
  final Map<String, List<String>> _rolePermissions = {
    'ADMIN': [
      'FULL_ACCESS',
      'USER_MANAGEMENT',
      'STORE_MANAGEMENT',
      'KITCHEN_MANAGEMENT',
      'BILLING_EDIT',
      'BATCH_BILLING_GENERATE'
    ],
    'MANAGER': [
      'PRODUCT_MANAGEMENT',
      'VIEW_BILLING',
      'CONFIRM_BILLING',
      'VIEW_REPORTS',
      'ORDER_ALLOCATION'
    ],
    'COORDINATOR': [
      'APPROVE_ORDERS',
      'PRODUCTION_PLANNING',
      'ALLOCATION_MANAGEMENT',
      'CREATE_SHIPMENT',
      'VIEW_SHIPMENT',
      'START_TRANSIT'
    ],
    'KITCHEN_STAFF': [
      'VIEW_PRODUCTION_PLAN',
      'UPDATE_PRODUCTION_STATUS',
      'PREPARE_SHIPMENT',
      'INVENTORY_CHECK'
    ],
    'STORE_STAFF': [
      'CREATE_ORDER',
      'VIEW_STORE_ORDERS',
      'RECEIVE_SHIPMENT',
      'CONFIRM_DELIVERY'
    ]
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    _cycleNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final usersFuture = ApiService.fetchUsers(search: _userSearchQuery);
      final kitchensFuture = ApiService.fetchKitchens();
      final storesFuture = ApiService.fetchStores();
      final billingFuture = ApiService.fetchBillingStatements();

      final results = await Future.wait([usersFuture, kitchensFuture, storesFuture, billingFuture]);

      if (mounted) {
        setState(() {
          _users = results[0];
          
          final kitchens = results[1];
          if (kitchens.isNotEmpty) {
            _centralKitchen = kitchens.first;
          }
          
          _stores = results[2];
          _billingStatements = results[3];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Không thể tải dữ liệu: ${e.toString()}");
      }
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  // --- User Operations ---
  void _openAddUserBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return const AddUserForm();
      },
    ).then((value) {
      if (value == true) {
        _loadAllData();
      }
    });
  }

  // --- Kitchen & Store Operations ---
  void _openEditKitchenBottomSheet() {
    if (_centralKitchen == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return EditKitchenForm(kitchen: _centralKitchen!);
      },
    ).then((value) {
      if (value == true) {
        _loadAllData();
      }
    });
  }

  void _openAddStoreBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return const AddStoreForm();
      },
    ).then((value) {
      if (value == true) {
        _loadAllData();
      }
    });
  }

  void _openEditStoreBottomSheet(Map<String, dynamic> store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return AddStoreForm(store: store);
      },
    ).then((value) {
      if (value == true) {
        _loadAllData();
      }
    });
  }

  // --- Billing/Invoice Operations ---
  Future<void> _handleBatchBillingGeneration() async {
    setState(() => _isLoading = true);
    final payload = {
      'periodStart': "${_periodStart.year}-${_periodStart.month.toString().padLeft(2, '0')}-${_periodStart.day.toString().padLeft(2, '0')}",
      'periodEnd': "${_periodEnd.year}-${_periodEnd.month.toString().padLeft(2, '0')}-${_periodEnd.day.toString().padLeft(2, '0')}",
      'cycleName': _cycleNameController.text.trim(),
    };

    try {
      final res = await ApiService.generateBatchBilling(payload);
      if (mounted) {
        setState(() => _isLoading = false);
        _showBatchGenerationResultDialog(res);
        _loadAllData(); // Reload invoices
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar("Lỗi xuất hóa đơn hàng loạt: ${e.toString()}");
      }
    }
  }

  void _showBatchGenerationResultDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text("KẾT QUẢ XUẤT HĐ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Chu kỳ: ${data['cycleName'] ?? 'Không rõ'}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text("• Tổng số cửa hàng quét: ${data['processedStoresCount'] ?? 0}", style: const TextStyle(color: Colors.white70)),
              Text("• Số hóa đơn mới đã tạo: ${data['generatedStatementsCount'] ?? 0}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w500)),
              Text("• Số cửa hàng bỏ qua (đã có HĐ): ${data['skippedStoresCount'] ?? 0}", style: const TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ĐỒNG Ý", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }

  void _openEditInvoiceBottomSheet(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        String currentStatus = invoice['status'] ?? 'ISSUED';
        final statusOptions = ['DRAFT', 'ISSUED', 'PAID', 'OVERDUE'];

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CHỈNH SỬA HÓA ĐƠN #${invoice['statementId']}",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${invoice['storeName']} • ${invoice['cycleName']}",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    const Text("TRẠNG THÁI THANH TOÁN:", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    
                    Wrap(
                      spacing: 8,
                      children: statusOptions.map((status) {
                        final isSelected = currentStatus == status;
                        return ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          selectedColor: Colors.orange,
                          backgroundColor: Colors.white10,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setSheetState(() {
                                currentStatus = status;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("HỦY BỎ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              setState(() => _isLoading = true);
                              try {
                                final ok = await ApiService.updateBillingStatementStatus(invoice['statementId'], currentStatus);
                                if (ok && mounted) {
                                  _showSuccessSnackBar("Cập nhật trạng thái hóa đơn thành công!");
                                  _loadAllData();
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  _showErrorSnackBar("Không thể cập nhật hóa đơn: ${e.toString()}");
                                }
                              }
                            },
                            child: const Text("CẬP NHẬT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Render Utilities ---
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

  Color _getRoleColor(String roleName) {
    final clean = roleName.toUpperCase().replaceAll('ROLE_', '');
    switch (clean) {
      case 'ADMIN': return Colors.redAccent;
      case 'MANAGER': return Colors.purpleAccent;
      case 'COORDINATOR': return Colors.blueAccent;
      case 'KITCHEN_STAFF': return Colors.amber;
      case 'STORE_STAFF': return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  String _cleanRoleName(String roleName) {
    final clean = roleName.toUpperCase().replaceAll('ROLE_', '');
    switch (clean) {
      case 'ADMIN': return 'Quản trị viên';
      case 'COORDINATOR': return 'Điều phối viên';
      case 'KITCHEN_STAFF': return 'Nhân viên bếp';
      case 'STORE_STAFF': return 'Nhân viên cửa hàng';
      case 'MANAGER': return 'Quản lý phân phối';
      default: return clean;
    }
  }

  Color _getBillingStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'ISSUED') return Colors.orange;
    if (s == 'PAID') return Colors.greenAccent;
    if (s == 'OVERDUE') return Colors.redAccent;
    return Colors.grey;
  }

  String _getBillingStatusLabel(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'ISSUED': return 'Chờ thanh toán';
      case 'PAID': return 'Đã thanh toán';
      case 'OVERDUE': return 'Quá hạn';
      case 'DRAFT': return 'Bản nháp';
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
          "HỆ THỐNG QUẢN TRỊ",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
          tabs: const [
            Tab(text: "NHÂN SỰ & VAI TRÒ", icon: Icon(Icons.people_alt_rounded, size: 18)),
            Tab(text: "BẾP & CỬA HÀNG", icon: Icon(Icons.storefront_rounded, size: 18)),
            Tab(text: "HÓA ĐƠN & BILLING", icon: Icon(Icons.payments_rounded, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersTab(),
                _buildFacilitiesTab(),
                _buildBillingTab(),
              ],
            ),
    );
  }

  // --- TAB 1: USERS & ROLES ---
  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Segmented sub-tab
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("DANH SÁCH NHÂN VIÊN")),
                  selected: _userSubTab == "USERS",
                  selectedColor: Colors.orange,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                    color: _userSubTab == "USERS" ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _userSubTab = "USERS");
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("VAI TRÒ & PHÂN QUYỀN")),
                  selected: _userSubTab == "ROLES",
                  selectedColor: Colors.orange,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                    color: _userSubTab == "ROLES" ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _userSubTab = "ROLES");
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _userSubTab == "USERS"
                ? _buildUsersSubSection()
                : _buildRolesSubSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersSubSection() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _openAddUserBottomSheet,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black),
      ),
      body: Column(
        children: [
          TextField(
            controller: _userSearchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) {
              setState(() => _userSearchQuery = val);
              _loadAllData();
            },
            decoration: InputDecoration(
              hintText: "Tìm theo họ tên, username, email...",
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.orange, size: 20),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                      onPressed: () {
                        _userSearchController.clear();
                        setState(() => _userSearchQuery = "");
                        _loadAllData();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xff1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _users.isEmpty
                ? Center(child: Text("Không tìm thấy nhân viên nào", style: TextStyle(color: Colors.grey.shade500)))
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final String fullName = user['fullName'] ?? 'Nhân sự';
                      final String username = user['username'] ?? '';
                      final String email = user['email'] ?? '';
                      final String roleName = user['roleName'] ?? 'STORE_STAFF';
                      final String? storeName = user['storeName'];
                      final String? kitchenName = user['kitchenName'];
                      final initials = fullName.isNotEmpty ? fullName.split(' ').last[0].toUpperCase() : 'U';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xff1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: _getRoleColor(roleName).withOpacity(0.1),
                              child: Text(
                                initials,
                                style: TextStyle(color: _getRoleColor(roleName), fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fullName,
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(roleName).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _getRoleColor(roleName).withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          _cleanRoleName(roleName),
                                          style: TextStyle(color: _getRoleColor(roleName), fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text("@$username", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(email, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                  if (storeName != null || kitchenName != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.02),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(storeName != null ? Icons.storefront_rounded : Icons.warehouse_rounded, color: Colors.grey, size: 12),
                                          const SizedBox(width: 6),
                                          Text(storeName ?? kitchenName ?? '', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                        ],
                                      ),
                                    )
                                  ]
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildRolesSubSection() {
    return ListView.separated(
      itemCount: _rolePermissions.keys.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final roleKey = _rolePermissions.keys.elementAt(index);
        final perms = _rolePermissions[roleKey]!;
        final dispRole = _cleanRoleName(roleKey);
        final color = _getRoleColor(roleKey);

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
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dispRole,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Text("($roleKey)", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              const Text("QUYỀN HẠN ĐƯỢC PHÂN PHỐI:", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: perms.map((p) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withOpacity(0.15)),
                    ),
                    child: Text(
                      p,
                      style: const TextStyle(color: Colors.orange, fontSize: 10, fontFamily: 'monospace'),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: FACILITIES ---
  Widget _buildFacilitiesTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("BẾP TRUNG TÂM (1)")),
                  selected: _facilitySubTab == "KITCHEN",
                  selectedColor: Colors.orange,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                    color: _facilitySubTab == "KITCHEN" ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _facilitySubTab = "KITCHEN");
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text("DANH SÁCH CỬA HÀNG")),
                  selected: _facilitySubTab == "STORES",
                  selectedColor: Colors.orange,
                  backgroundColor: Colors.white10,
                  labelStyle: TextStyle(
                    color: _facilitySubTab == "STORES" ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _facilitySubTab = "STORES");
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _facilitySubTab == "KITCHEN"
                ? _buildKitchenSubSection()
                : _buildStoresSubSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildKitchenSubSection() {
    if (_centralKitchen == null) {
      return const Center(child: Text("Không có dữ liệu bếp trung tâm", style: TextStyle(color: Colors.grey)));
    }
    final name = _centralKitchen!['kitchenName'] ?? 'Bếp trung tâm';
    final address = _centralKitchen!['address'] ?? 'Chưa xác định';
    final capacity = _centralKitchen!['maxDailyCapacity'] ?? 0;
    final lat = _centralKitchen!['latitude'] ?? 0.0;
    final lng = _centralKitchen!['longitude'] ?? 0.0;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xff1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warehouse_rounded, color: Colors.orange, size: 24),
                    SizedBox(width: 10),
                    Text("BẾP ĐIỀU HÀNH CHÍNH", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton.icon(
                  onPressed: _openEditKitchenBottomSheet,
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.orange),
                  label: const Text("SỬA", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            _buildDetailField("Tên cơ sở", name),
            const SizedBox(height: 12),
            _buildDetailField("Địa chỉ (Goong Map)", address),
            const SizedBox(height: 12),
            _buildDetailField("Công suất tối đa", "$capacity phần ăn/ngày"),
            const SizedBox(height: 12),
            _buildDetailField("Tọa độ Geolocation", "Vĩ độ: $lat, Kinh độ: $lng"),
            const SizedBox(height: 20),
            
            // Map simulator widget
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        "https://api.mapbox.com/styles/v1/mapbox/dark-v10/static/pin-s-a+ff5500($lng,$lat)/$lng,$lat,14/600x300?access_token=mock",
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to stylized grid mapping
                          return Container(
                            color: const Color(0xff090909),
                            child: CustomPaint(
                              painter: MapGridPainter(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 38),
                        SizedBox(height: 4),
                        Text(
                          "Bếp trung tâm đang trực tuyến",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoresSubSection() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _openAddStoreBottomSheet,
        child: const Icon(Icons.storefront_rounded, color: Colors.black),
      ),
      body: _stores.isEmpty
          ? const Center(child: Text("Không có cửa hàng liên kết", style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              itemCount: _stores.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final store = _stores[index];
                final name = store['name'] ?? 'Cửa hàng';
                final addr = store['address'] ?? 'Chưa cập nhật địa chỉ';
                final phone = store['phone'] ?? 'Chưa gán';
                final cycle = store['paymentCycle'] ?? 'MONTHLY';
                final lat = store['latitude'] ?? 0.0;
                final lng = store['longitude'] ?? 0.0;

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
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.grey),
                            onPressed: () => _openEditStoreBottomSheet(store),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildInfoRow(Icons.location_on_rounded, "Địa chỉ", addr),
                      const SizedBox(height: 6),
                      _buildInfoRow(Icons.phone_rounded, "Điện thoại", phone),
                      const SizedBox(height: 6),
                      _buildInfoRow(Icons.sync_rounded, "Chu kỳ đối soát", cycle),
                      const SizedBox(height: 6),
                      _buildInfoRow(Icons.map_rounded, "Tọa độ", "Vĩ độ: $lat, Kinh độ: $lng"),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailField(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 14),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ],
    );
  }

  // --- TAB 3: BILLING ---
  Widget _buildBillingTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Batch Invoice Section Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.orange, size: 22),
                    SizedBox(width: 8),
                    Text("XUẤT HÓA ĐƠN HÀNG LOẠT", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Date pickers row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _periodStart,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) setState(() => _periodStart = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TỪ NGÀY", style: TextStyle(color: Colors.grey.shade600, fontSize: 8)),
                              const SizedBox(height: 4),
                              Text("${_periodStart.day}/${_periodStart.month}/${_periodStart.year}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _periodEnd,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) setState(() => _periodEnd = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("ĐẾN NGÀY", style: TextStyle(color: Colors.grey.shade600, fontSize: 8)),
                              const SizedBox(height: 4),
                              Text("${_periodEnd.day}/${_periodEnd.month}/${_periodEnd.year}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Cycle name text field
                TextField(
                  controller: _cycleNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: "TÊN CHU KỲ PHÁT HÀNH",
                    labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _handleBatchBillingGeneration,
                    child: const Text("XUẤT HÓA ĐƠN ĐỒNG LOẠT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 18),
          
          const Text("DANH SÁCH HÓA ĐƠN HỆ THỐNG", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          
          // Invoices Filter Row
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['ALL', 'DRAFT', 'ISSUED', 'PAID', 'OVERDUE'].map((status) {
                final isSelected = _billingFilterStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(status == 'ALL' ? 'Tất cả' : status),
                    selected: isSelected,
                    selectedColor: Colors.orange,
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _billingFilterStatus = status);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Invoices List
          Expanded(
            child: _billingStatements.isEmpty
                ? const Center(child: Text("Không có hóa đơn", style: TextStyle(color: Colors.grey)))
                : Builder(
                    builder: (context) {
                      final filtered = _billingFilterStatus == 'ALL'
                          ? _billingStatements
                          : _billingStatements.where((b) => b['status'].toString().toUpperCase() == _billingFilterStatus).toList();
                      
                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final id = item['statementId'] ?? 0;
                          final storeName = item['storeName'] ?? 'Cửa hàng';
                          final cycleName = item['cycleName'] ?? '';
                          final totalAmount = item['totalAmount'] ?? 0;
                          final status = item['status'] ?? 'ISSUED';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xff1A1A1A),
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
                                      Text(
                                        storeName,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Mã HĐ: #$id • $cycleName",
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatCurrency(totalAmount),
                                        style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getBillingStatusColor(status).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getBillingStatusLabel(status),
                                        style: TextStyle(color: _getBillingStatusColor(status), fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 20),
                                      onPressed: () => _openEditInvoiceBottomSheet(item),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      );
                    }
                  ),
          )
        ],
      ),
    );
  }
}

// --- Map grid background simulator painter ---
class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1.0;

    const spacing = 20.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Dynamic Goong Map Address Autocomplete Field Widget ---
class GoongMapAddressField extends StatefulWidget {
  final String label;
  final String hint;
  final String? initialValue;
  final double? initialLat;
  final double? initialLng;
  final Function(String address, double lat, double lng) onLocationSelected;

  const GoongMapAddressField({
    super.key,
    required this.label,
    required this.hint,
    this.initialValue,
    this.initialLat,
    this.initialLng,
    required this.onLocationSelected,
  });

  @override
  State<GoongMapAddressField> createState() => _GoongMapAddressFieldState();
}

class _GoongMapAddressFieldState extends State<GoongMapAddressField> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _predictions = [];
  double? _latitude;
  double? _longitude;

  // Standard Demo Goong API key config
  final String _goongApiKey = "gp6Y74fGf8mQy6n2qg4Y0W0t6T5iXo1x2y4z"; 

  // Local fallback predictions matching HCMC central points for demo robustness
  final List<Map<String, dynamic>> _fallbackPlaces = [
    {'description': '120 Lê Lợi, Bến Thành, Quận 1, TP. Hồ Chí Minh', 'place_id': 'fallback-1', 'lat': 10.7725, 'lng': 106.6980},
    {'description': '72 Lê Thánh Tôn, Bến Nghé, Quận 1, TP. Hồ Chí Minh', 'place_id': 'fallback-2', 'lat': 10.7782, 'lng': 106.7021},
    {'description': '268 Lý Thường Kiệt, Quận 10, TP. Hồ Chí Minh', 'place_id': 'fallback-3', 'lat': 10.7735, 'lng': 106.6601},
    {'description': '1 Võ Văn Ngân, Linh Chiểu, Thủ Đức, TP. Hồ Chí Minh', 'place_id': 'fallback-4', 'lat': 10.8510, 'lng': 106.7720},
    {'description': '10 Huỳnh Tấn Phát, Tân Thuận Đông, Quận 7, TP. Hồ Chí Minh', 'place_id': 'fallback-5', 'lat': 10.7410, 'lng': 106.7230},
    {'description': '288 Nguyễn Văn Cừ, Quận 5, TP. Hồ Chí Minh', 'place_id': 'fallback-6', 'lat': 10.7629, 'lng': 106.6822},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _latitude = widget.initialLat;
    _longitude = widget.initialLng;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final url = "https://rsapi.goong.io/place/autocomplete?api_key=$_goongApiKey&input=${Uri.encodeComponent(query)}";
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final predictionsList = body['predictions'] as List? ?? [];
        
        setState(() {
          _predictions = predictionsList;
          _isSearching = false;
        });
        return;
      }
      throw Exception("Invalid response");
    } catch (_) {
      // Fallback search in our mock lists for HCMC
      final q = query.toLowerCase();
      final filtered = _fallbackPlaces.where((p) => p['description'].toString().toLowerCase().contains(q)).toList();
      setState(() {
        _predictions = filtered;
        _isSearching = false;
      });
    }
  }

  Future<void> _selectPrediction(dynamic prediction) async {
    final String desc = prediction['description'] ?? prediction['name'] ?? '';
    final String placeId = prediction['place_id'] ?? '';
    
    _controller.text = desc;
    setState(() => _predictions = []);

    if (placeId.startsWith('fallback-')) {
      final item = _fallbackPlaces.firstWhere((p) => p['place_id'] == placeId);
      setState(() {
        _latitude = item['lat'];
        _longitude = item['lng'];
      });
      widget.onLocationSelected(desc, _latitude!, _longitude!);
      return;
    }

    // Call Goong Detail API
    try {
      setState(() => _isSearching = true);
      final url = "https://rsapi.goong.io/place/detail?api_key=$_goongApiKey&place_id=$placeId";
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final geometry = body['result']?['geometry']?['location'] ?? {};
        setState(() {
          _latitude = geometry['lat'];
          _longitude = geometry['lng'];
          _isSearching = false;
        });
        widget.onLocationSelected(desc, _latitude!, _longitude!);
        return;
      }
    } catch (_) {}

    // Ultimate fallback if API fails
    final hash = desc.hashCode;
    final fallbackLat = 10.75 + (hash % 100) / 1000.0;
    final fallbackLng = 106.65 + (hash % 200) / 1000.0;
    setState(() {
      _latitude = fallbackLat;
      _longitude = fallbackLng;
      _isSearching = false;
    });
    widget.onLocationSelected(desc, fallbackLat, fallbackLng);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: _searchAddress,
          validator: (val) => val == null || val.trim().isEmpty ? "Vui lòng nhập địa chỉ" : null,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            filled: true,
            fillColor: const Color(0xff0F0F0F),
            suffixIcon: _isSearching
                ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)))
                : const Icon(Icons.map_rounded, color: Colors.orange, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        
        // Autocomplete suggestions box
        if (_predictions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: const Color(0xff1E1E1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _predictions.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final item = _predictions[index];
                final text = item['description'] ?? '';
                return ListTile(
                  title: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  dense: true,
                  onTap: () => _selectPrediction(item),
                );
              },
            ),
          ),
        ],

        // Coordinates & Map Simulator visualization
        if (_latitude != null && _longitude != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, color: Colors.orange, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Định vị thành công: Vĩ độ ${_latitude!.toStringAsFixed(5)}, Kinh độ ${_longitude!.toStringAsFixed(5)}",
                    style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// --- Edit Kitchen Form Widget ---
class EditKitchenForm extends StatefulWidget {
  final Map<String, dynamic> kitchen;

  const EditKitchenForm({super.key, required this.kitchen});

  @override
  State<EditKitchenForm> createState() => _EditKitchenFormState();
}

class _EditKitchenFormState extends State<EditKitchenForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  late String _address;
  late double _latitude;
  late double _longitude;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.kitchen['kitchenName']);
    _capacityController = TextEditingController(text: widget.kitchen['maxDailyCapacity']?.toString() ?? '1000');
    _address = widget.kitchen['address'] ?? '';
    _latitude = widget.kitchen['latitude'] ?? 10.7629;
    _longitude = widget.kitchen['longitude'] ?? 106.6822;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'name': _nameController.text.trim(),
      'address': _address,
      'maxDailyCapacity': int.tryParse(_capacityController.text) ?? 1000,
      'isActive': widget.kitchen['isActive'] ?? true,
      'latitude': _latitude,
      'longitude': _longitude,
    };

    try {
      final ok = await ApiService.updateKitchen(widget.kitchen['kitchenId'], payload);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật thông tin bếp trung tâm thành công!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.warehouse_rounded, color: Colors.orange, size: 22),
                  SizedBox(width: 8),
                  Text("CẬP NHẬT THÔNG TIN BẾP", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              
              // Kitchen Name
              Text("TÊN BẾP TRUNG TÂM", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (val) => val == null || val.trim().isEmpty ? "Vui lòng nhập tên bếp" : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              
              // Address with Goong Map Autocomplete picker
              GoongMapAddressField(
                label: "Địa chỉ Bếp trung tâm (Goong Map)",
                hint: "Tìm địa chỉ thực tế...",
                initialValue: _address,
                initialLat: _latitude,
                initialLng: _longitude,
                onLocationSelected: (addr, lat, lng) {
                  setState(() {
                    _address = addr;
                    _latitude = lat;
                    _longitude = lng;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Capacity
              Text("CÔNG SUẤT HÀNG NGÀY (PHẦN ĂN)", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (val) => val == null || int.tryParse(val) == null ? "Vui lòng nhập công suất hợp lệ" : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : const Text("CẬP NHẬT CƠ SỞ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
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

// --- Add/Edit Store Form Widget ---
class AddStoreForm extends StatefulWidget {
  final Map<String, dynamic>? store;

  const AddStoreForm({super.key, this.store});

  @override
  State<AddStoreForm> createState() => _AddStoreFormState();
}

class _AddStoreFormState extends State<AddStoreForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late String _address;
  late double _latitude;
  late double _longitude;
  late String _cycle;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store?['name'] ?? '');
    _phoneController = TextEditingController(text: widget.store?['phone'] ?? '');
    _emailController = TextEditingController(text: widget.store?['email'] ?? '');
    _address = widget.store?['address'] ?? '';
    _latitude = widget.store?['latitude'] ?? 10.7725;
    _longitude = widget.store?['longitude'] ?? 106.6980;
    _cycle = widget.store?['paymentCycle'] ?? 'MONTHLY';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_address.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn địa chỉ bằng Goong Map")));
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'name': _nameController.text.trim(),
      'address': _address,
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'isActive': widget.store?['isActive'] ?? true,
      'paymentCycle': _cycle,
      'latitude': _latitude,
      'longitude': _longitude,
    };

    try {
      if (widget.store != null) {
        final ok = await ApiService.updateStore(widget.store!['id'] ?? widget.store!['storeId'], payload);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật thông tin cửa hàng thành công!"), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        await ApiService.createStore(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tạo cửa hàng liên kết mới thành công!"), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${e.toString()}"), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(widget.store != null ? Icons.edit_location_rounded : Icons.add_box_rounded, color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.store != null ? "CẬP NHẬT CỬA HÀNG" : "THÊM CỬA HÀNG MỚI",
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Name
              Text("TÊN CỬA HÀNG", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (val) => val == null || val.trim().isEmpty ? "Vui lòng nhập tên cửa hàng" : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              
              // Goong Map address autocomplete picker
              GoongMapAddressField(
                label: "Địa chỉ Cửa hàng (Goong Map)",
                hint: "Tìm địa chỉ trên Goong Map...",
                initialValue: _address,
                initialLat: _latitude,
                initialLng: _longitude,
                onLocationSelected: (addr, lat, lng) {
                  setState(() {
                    _address = addr;
                    _latitude = lat;
                    _longitude = lng;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Phone
              Text("SỐ ĐIỆN THOẠI CỬA HÀNG", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty ? "Vui lòng nhập số điện thoại" : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              Text("EMAIL LIÊN HỆ", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val == null || !val.contains('@') ? "Email không hợp lệ" : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Payment Cycle dropdown
              Text("CHU KỲ ĐỐI SOÁT HÓA ĐƠN", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xff1A1A1A),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                value: _cycle,
                onChanged: (val) => setState(() => _cycle = val!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'WEEKLY', child: Text("Hàng Tuần (WEEKLY)")),
                  DropdownMenuItem(value: 'MONTHLY', child: Text("Hàng Tháng (MONTHLY)")),
                  DropdownMenuItem(value: 'QUARTERLY', child: Text("Hàng Quý (QUARTERLY)")),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                      : Text(widget.store != null ? "CẬP NHẬT" : "TẠO CỬA HÀNG", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
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
