import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await ApiService.fetchUsers(search: _searchQuery);
      if (mounted) {
        setState(() {
          _users = users;
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
            content: Text("Lỗi tải danh sách người dùng: ${e.toString().replaceAll("Exception: ", "")}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAddUserBottomSheet() async {
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
        _loadUsers();
      }
    });
  }

  String _cleanRoleName(String roleName) {
    final clean = roleName.toUpperCase().replaceAll('ROLE_', '');
    switch (clean) {
      case 'ADMIN':
        return 'Quản trị viên';
      case 'COORDINATOR':
        return 'Điều phối viên';
      case 'KITCHEN_STAFF':
        return 'Nhân viên bếp';
      case 'STORE_STAFF':
        return 'Nhân viên cửa hàng';
      case 'MANAGER':
        return 'Quản lý phân phối';
      default:
        return clean;
    }
  }

  Color _getRoleColor(String roleName) {
    final clean = roleName.toUpperCase().replaceAll('ROLE_', '');
    switch (clean) {
      case 'ADMIN':
        return Colors.redAccent;
      case 'MANAGER':
        return Colors.purpleAccent;
      case 'COORDINATOR':
        return Colors.blueAccent;
      case 'KITCHEN_STAFF':
        return Colors.amber;
      case 'STORE_STAFF':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xff1A1A1A),
        elevation: 0,
        title: const Text(
          "NHÂN SỰ HỆ THỐNG",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.orange, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            onPressed: _loadUsers,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _showAddUserBottomSheet,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                  // Debounce search/load
                  _loadUsers();
                },
                decoration: InputDecoration(
                  hintText: "Tìm theo họ tên, username, email...",
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.orange, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = "";
                            });
                            _loadUsers();
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
              
              // Users List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.orange),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline_rounded, color: Colors.grey.shade800, size: 60),
                                const SizedBox(height: 12),
                                Text(
                                  "Không tìm thấy nhân viên nào",
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
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
                              final bool isActive = user['isActive'] ?? true;

                              // Initials for avatar
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
                                    // Avatar circle
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: _getRoleColor(roleName).withOpacity(0.1),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: _getRoleColor(roleName),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    
                                    // Detail text
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
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                                                  style: TextStyle(
                                                    color: _getRoleColor(roleName),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "@$username",
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.mail_outline_rounded, color: Colors.grey.shade600, size: 12),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  email,
                                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          // Additional Store/Kitchen location if mapped
                                          if (storeName != null || kitchenName != null) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.02),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.white.withOpacity(0.04)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    storeName != null ? Icons.storefront_rounded : Icons.warehouse_rounded,
                                                    color: Colors.grey.shade500,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    storeName ?? kitchenName ?? '',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade300,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
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
        ),
      ),
    );
  }
}

class AddUserForm extends StatefulWidget {
  const AddUserForm({super.key});

  @override
  State<AddUserForm> createState() => _AddUserFormState();
}

class _AddUserFormState extends State<AddUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _kitchens = [];
  
  int? _selectedRoleId;
  int? _selectedStoreId;
  int? _selectedKitchenId;

  bool _isLoadingDropdowns = true;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    try {
      final rolesFuture = ApiService.fetchRoles();
      final storesFuture = ApiService.fetchStores();
      final kitchensFuture = ApiService.fetchKitchens();

      final results = await Future.wait([rolesFuture, storesFuture, kitchensFuture]);

      if (mounted) {
        setState(() {
          _roles = results[0];
          _stores = results[1];
          _kitchens = results[2];
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load form dropdown values: $e");
      if (mounted) {
        setState(() {
          _isLoadingDropdowns = false;
        });
      }
    }
  }

  String? _getSelectedRoleName() {
    if (_selectedRoleId == null) return null;
    final role = _roles.firstWhere((r) => r['roleId'] == _selectedRoleId, orElse: () => {});
    return role['roleName']?.toString().toUpperCase().replaceAll('ROLE_', '');
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng chọn vai trò nhân viên")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final payload = {
      'email': _emailController.text.trim(),
      'fullName': _fullNameController.text.trim(),
      'roleId': _selectedRoleId,
      if (_getSelectedRoleName() == 'STORE_STAFF') 'storeId': _selectedStoreId,
      if (_getSelectedRoleName() == 'KITCHEN_STAFF' || _getSelectedRoleName() == 'COORDINATOR') 'kitchenId': _selectedKitchenId,
    };

    try {
      final res = await ApiService.createUser(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? "Khởi tạo tài khoản thành công!"),
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
    final roleName = _getSelectedRoleName();
    final showStoreDropdown = roleName == 'STORE_STAFF';
    final showKitchenDropdown = roleName == 'KITCHEN_STAFF' || roleName == 'COORDINATOR';

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
                        Icon(Icons.person_add_alt_1_rounded, color: Colors.orange, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          "THÊM NGƯỜI DÙNG MỚI",
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
                    
                    // Name Field
                    Text(
                      "HỌ VÀ TÊN",
                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      validator: (val) {
                        if (val == null || val.trim().length < 2) {
                          return "Họ tên phải có ít nhất 2 ký tự";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: "Nhập họ và tên đầy đủ",
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    Text(
                      "EMAIL",
                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || !val.contains('@') || !val.contains('.')) {
                          return "Email không hợp lệ";
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: "VD: name.staff@steakchain.vn",
                        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role Select
                    Text(
                      "VAI TRÒ (ROLE)",
                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      dropdownColor: const Color(0xff1A1A1A),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      value: _selectedRoleId,
                      onChanged: (val) {
                        setState(() {
                          _selectedRoleId = val;
                          _selectedStoreId = null;
                          _selectedKitchenId = null;
                        });
                      },
                      validator: (val) => val == null ? "Vui lòng chọn vai trò" : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xff0F0F0F),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _roles.map((r) {
                        final id = r['roleId'] as int;
                        final name = r['roleName'] as String;
                        // Map displays beautifully
                        String disp = name.replaceAll('ROLE_', '').replaceAll('_', ' ');
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(disp),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Store Selector
                    if (showStoreDropdown) ...[
                      Text(
                        "CỬA HÀNG GÁN TRỰC TIẾP",
                        style: TextStyle(color: Colors.orange.shade300, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        dropdownColor: const Color(0xff1A1A1A),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        value: _selectedStoreId,
                        onChanged: (val) {
                          setState(() {
                            _selectedStoreId = val;
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
                    ],

                    // Dynamic Kitchen Selector
                    if (showKitchenDropdown) ...[
                      Text(
                        "BẾP TRUNG TÂM PHỤ TRÁCH",
                        style: TextStyle(color: Colors.orange.shade300, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        dropdownColor: const Color(0xff1A1A1A),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        value: _selectedKitchenId,
                        onChanged: (val) {
                          setState(() {
                            _selectedKitchenId = val;
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
                        items: _kitchens.map((k) {
                          final id = k['kitchenId'] as int;
                          final name = k['kitchenName'] as String;
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(name),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),
                    
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
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                              )
                            : const Text(
                                "TẠO TÀI KHOẢN",
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
