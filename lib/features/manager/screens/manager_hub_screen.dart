import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

class ManagerHubScreen extends StatefulWidget {
  final int initialTab;

  const ManagerHubScreen({super.key, this.initialTab = 0});

  @override
  State<ManagerHubScreen> createState() => _ManagerHubScreenState();
}

class _ManagerHubScreenState extends State<ManagerHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Tab 1: Products State ---
  bool _isLoadingProducts = true;
  List<Map<String, dynamic>> _products = [];
  String _productSearchQuery = "";
  final TextEditingController _productSearchController = TextEditingController();

  // --- Tab 2: Materials State ---
  bool _isLoadingMaterials = true;
  List<Map<String, dynamic>> _materials = [];
  String _materialSearchQuery = "";
  final TextEditingController _materialSearchController = TextEditingController();

  // --- Tab 3: Categories State ---
  bool _isLoadingCategories = true;
  List<Map<String, dynamic>> _categories = [];
  String _categorySearchQuery = "";
  final TextEditingController _categorySearchController = TextEditingController();

  // --- Tab 4: Billing State ---
  bool _isLoadingBilling = true;
  List<Map<String, dynamic>> _billingStatements = [];
  String _selectedBillingStatus = "ALL";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _loadProducts();
    _loadMaterials();
    _loadCategories();
    _loadBillingStatements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productSearchController.dispose();
    _materialSearchController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  // --- Data Loading Methods ---

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _isLoadingProducts = true);
    try {
      final products = await ApiService.fetchProducts(search: _productSearchQuery);
      if (mounted) {
        setState(() {
          _products = products;
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar("Lỗi tải sản phẩm: ${e.toString()}");
    }
  }

  Future<void> _loadMaterials() async {
    if (!mounted) return;
    setState(() => _isLoadingMaterials = true);
    try {
      final list = await ApiService.fetchMaterials();
      if (mounted) {
        setState(() {
          // Local filter for search query
          if (_materialSearchQuery.isNotEmpty) {
            final q = _materialSearchQuery.toLowerCase();
            _materials = list.where((m) => m['name'].toString().toLowerCase().contains(q)).toList();
          } else {
            _materials = list;
          }
          _isLoadingMaterials = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar("Lỗi tải nguyên liệu: ${e.toString()}");
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCategories = true);
    try {
      final list = await ApiService.fetchCategories();
      if (mounted) {
        setState(() {
          // Local filter for search query
          if (_categorySearchQuery.isNotEmpty) {
            final q = _categorySearchQuery.toLowerCase();
            _categories = list.where((c) => c['name'].toString().toLowerCase().contains(q) || (c['description'] ?? '').toString().toLowerCase().contains(q)).toList();
          } else {
            _categories = list;
          }
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar("Lỗi tải danh mục: ${e.toString()}");
    }
  }

  Future<void> _loadBillingStatements() async {
    if (!mounted) return;
    setState(() => _isLoadingBilling = true);
    try {
      final billing = await ApiService.fetchBillingStatements(status: _selectedBillingStatus);
      if (mounted) {
        setState(() {
          _billingStatements = billing;
          _isLoadingBilling = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar("Lỗi tải hóa đơn: ${e.toString()}");
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }


  // --- Product Form Dialog Sheet ---
  void _showProductForm({Map<String, dynamic>? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return ProductFormSheet(
          product: product,
          categories: _categories,
          onSave: () {
            _loadProducts();
          },
        );
      },
    );
  }

  // --- Material Form Dialog Sheet ---
  void _showMaterialForm({Map<String, dynamic>? material}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return MaterialFormSheet(
          material: material,
          onSave: () {
            _loadMaterials();
          },
        );
      },
    );
  }

  // --- Category Form Dialog Sheet ---
  void _showCategoryForm({Map<String, dynamic>? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return CategoryFormSheet(
          category: category,
          onSave: () {
            _loadCategories();
          },
        );
      },
    );
  }

  // --- Billing Details Modal Bottom Sheet ---
  void _showBillingDetailBottomSheet(Map<String, dynamic> statement) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        final status = statement['status'] as String? ?? 'ISSUED';
        final storeName = statement['storeName'] ?? 'Cửa hàng';
        final cycleName = statement['cycleName'] ?? 'Hóa đơn';
        final totalAmount = statement['totalAmount'] ?? 0;
        final date = statement['issuedAt'] ?? '2026-07-14';
        final id = statement['statementId'] ?? 0;

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
                    decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "MÃ HÓA ĐƠN: #$id",
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getBillingStatusColor(status).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getBillingStatusColor(status).withOpacity(0.2)),
                      ),
                      child: Text(
                        _getBillingStatusLabel(status),
                        style: TextStyle(color: _getBillingStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 24),
                _buildDetailRow("Đơn vị thụ hưởng:", storeName),
                const SizedBox(height: 10),
                _buildDetailRow("Chu kỳ thanh toán:", cycleName),
                const SizedBox(height: 10),
                _buildDetailRow("Ngày phát hành:", date.split('T')[0]),
                const SizedBox(height: 10),
                _buildDetailRow("Tổng cộng cần thu:", _formatCurrency(totalAmount), valueColor: Colors.orange, isBold: true),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("ĐÓNG THÔNG TIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color valueColor = Colors.white70, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

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

  Color _getBillingStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'PAID') return Colors.greenAccent;
    if (s == 'ISSUED') return Colors.orangeAccent;
    if (s == 'OVERDUE') return Colors.redAccent;
    return Colors.grey;
  }

  String _getBillingStatusLabel(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'PAID': return 'Đã thanh toán';
      case 'ISSUED': return 'Đã phát hành';
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
          "TRUNG TÂM PHÂN PHỐI",
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.1),
          tabs: const [
            Tab(text: "SẢN PHẨM", icon: Icon(Icons.inventory_2_rounded, size: 18)),
            Tab(text: "NGUYÊN LIỆU", icon: Icon(Icons.receipt_long_rounded, size: 18)),
            Tab(text: "DANH MỤC", icon: Icon(Icons.category_rounded, size: 18)),
            Tab(text: "HÓA ĐƠN", icon: Icon(Icons.payments_rounded, size: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildProductsTab(),
            _buildMaterialsTab(),
            _buildCategoriesTab(),
            _buildBillingTab(),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: PRODUCTS ---
  Widget _buildProductsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showProductForm(),
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _productSearchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                setState(() => _productSearchQuery = val);
                _loadProducts();
              },
              decoration: InputDecoration(
                hintText: "Tìm kiếm món ăn...",
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.orange, size: 20),
                suffixIcon: _productSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          _productSearchController.clear();
                          setState(() => _productSearchQuery = "");
                          _loadProducts();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xff1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : _products.isEmpty
                      ? Center(child: Text("Không có sản phẩm nào", style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.separated(
                          itemCount: _products.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final p = _products[index];
                            final name = p['name'] ?? 'Món ăn';
                            final desc = p['description'] ?? 'Chưa cập nhật mô tả';
                            final price = p['price'] ?? 0;
                            final unit = p['unit'] ?? 'Đĩa';
                            final catName = p['category']?['name'] ?? 'Chưa phân loại';

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
                                  Expanded(
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
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.06),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                catName,
                                                style: const TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(desc, style: TextStyle(color: Colors.grey.shade500, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatCurrency(price),
                                              style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              "Đơn vị: $unit",
                                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, color: Colors.grey, size: 20),
                                    onPressed: () => _showProductForm(product: p),
                                  )
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

  // --- TAB 2: MATERIALS ---
  Widget _buildMaterialsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showMaterialForm(),
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _materialSearchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                setState(() => _materialSearchQuery = val);
                _loadMaterials();
              },
              decoration: InputDecoration(
                hintText: "Tìm kiếm nguyên liệu...",
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.orange, size: 20),
                suffixIcon: _materialSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          _materialSearchController.clear();
                          setState(() => _materialSearchQuery = "");
                          _loadMaterials();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xff1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoadingMaterials
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : _materials.isEmpty
                      ? Center(child: Text("Không có nguyên liệu nào", style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.separated(
                          itemCount: _materials.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final m = _materials[index];
                            final name = m['name'] ?? 'Nguyên liệu';
                            final unit = m['unit'] ?? 'KG';
                            final minStock = m['minStockLevel'] ?? 10;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xff1A1A1A),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.04)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("Định lượng cảnh báo: $minStock $unit", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(unit, style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_note_rounded, color: Colors.grey, size: 20),
                                        onPressed: () => _showMaterialForm(material: m),
                                      )
                                    ],
                                  )
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

  // --- TAB 3: CATEGORIES ---
  Widget _buildCategoriesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showCategoryForm(),
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _categorySearchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                setState(() => _categorySearchQuery = val);
                _loadCategories();
              },
              decoration: InputDecoration(
                hintText: "Tìm kiếm danh mục...",
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.orange, size: 20),
                suffixIcon: _categorySearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          _categorySearchController.clear();
                          setState(() => _categorySearchQuery = "");
                          _loadCategories();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xff1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoadingCategories
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : _categories.isEmpty
                      ? Center(child: Text("Không có danh mục nào", style: TextStyle(color: Colors.grey.shade500)))
                      : ListView.separated(
                          itemCount: _categories.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final c = _categories[index];
                            final name = c['name'] ?? 'Danh mục';
                            final desc = c['description'] ?? 'Không có mô tả';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xff1A1A1A),
                                borderRadius: BorderRadius.circular(20),
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
                                          name,
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(desc, style: TextStyle(color: Colors.grey.shade500, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, color: Colors.grey, size: 20),
                                    onPressed: () => _showCategoryForm(category: c),
                                  )
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

  // --- TAB 4: BILLING ---
  Widget _buildBillingTab() {
    final statusFilters = [
      {'val': 'ALL', 'label': 'Tất cả'},
      {'val': 'ISSUED', 'label': 'Chờ thu'},
      {'val': 'PAID', 'label': 'Đã thu'},
      {'val': 'OVERDUE', 'label': 'Quá hạn'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Filter scroll
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statusFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = statusFilters[index];
                final isSelected = _selectedBillingStatus == filter['val'];
                return InkWell(
                  onTap: () {
                    setState(() => _selectedBillingStatus = filter['val']!);
                    _loadBillingStatements();
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

          Expanded(
            child: _isLoadingBilling
                ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                : _billingStatements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, color: Colors.grey.shade800, size: 60),
                            const SizedBox(height: 12),
                            Text("Không có hóa đơn", style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _billingStatements.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final bill = _billingStatements[index];
                          final id = bill['statementId'] ?? 0;
                          final storeName = bill['storeName'] ?? 'Cửa hàng';
                          final cycleName = bill['cycleName'] ?? '';
                          final totalAmount = bill['totalAmount'] ?? 0;
                          final status = bill['status'] ?? 'ISSUED';

                          return InkWell(
                            onTap: () => _showBillingDetailBottomSheet(bill),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xff1A1A1A),
                                borderRadius: BorderRadius.circular(20),
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
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text("Chu kỳ: $cycleName • Mã: #$id", style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatCurrency(totalAmount),
                                          style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getBillingStatusColor(status).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _getBillingStatusColor(status).withOpacity(0.15)),
                                    ),
                                    child: Text(
                                      _getBillingStatusLabel(status),
                                      style: TextStyle(color: _getBillingStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
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
}

// --- Product Form Sheet (Create/Edit Product) ---
class ProductFormSheet extends StatefulWidget {
  final Map<String, dynamic>? product;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onSave;

  const ProductFormSheet({super.key, this.product, required this.categories, required this.onSave});

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController(text: 'Đĩa');
  int? _selectedCategoryId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!['name'] ?? '';
      _descController.text = widget.product!['description'] ?? '';
      _priceController.text = widget.product!['price']?.toString() ?? '0';
      _unitController.text = widget.product!['unit'] ?? 'Đĩa';
      _selectedCategoryId = widget.product!['category']?['id'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng chọn danh mục")));
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'price': int.tryParse(_priceController.text) ?? 0,
      'unit': _unitController.text.trim(),
      'categoryId': _selectedCategoryId,
    };

    try {
      if (widget.product != null) {
        final ok = await ApiService.updateProduct(widget.product!['id'], payload);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật thực đơn thành công!"), backgroundColor: Colors.green));
          widget.onSave();
          Navigator.pop(context);
        }
      } else {
        await ApiService.createProduct(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tạo món ăn mới thành công!"), backgroundColor: Colors.green));
          widget.onSave();
          Navigator.pop(context);
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
                  Icon(widget.product != null ? Icons.edit_note_rounded : Icons.add_box_rounded, color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.product != null ? "CHỈNH SỬA SẢN PHẨM" : "THÊM SẢN PHẨM MỚI",
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name
              Text("TÊN MÓN ĂN / SẢN PHẨM", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (val) => val == null || val.trim().isEmpty ? "Vui lòng nhập tên món" : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text("MÔ TẢ CHI TIẾT", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Row Price & Unit
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("GIÁ BÁN (VND)", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          validator: (val) => val == null || int.tryParse(val) == null ? "Không hợp lệ" : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xff0F0F0F),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("ĐƠN VỊ TÍNH", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _unitController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          validator: (val) => val == null || val.trim().isEmpty ? "Cần nhập đơn vị" : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xff0F0F0F),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category dropdown
              Text("DANH MỤC PHÂN LOẠI", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                dropdownColor: const Color(0xff1A1A1A),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                value: _selectedCategoryId,
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: widget.categories.map((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'],
                    child: Text(c['name'] ?? ''),
                  );
                }).toList(),
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
                      : Text(widget.product != null ? "CẬP NHẬT MÓN ĂN" : "TẠO MÓN ĂN", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

// --- Material Form Sheet (Create/Edit Material) ---
class MaterialFormSheet extends StatefulWidget {
  final Map<String, dynamic>? material;
  final VoidCallback onSave;

  const MaterialFormSheet({super.key, this.material, required this.onSave});

  @override
  State<MaterialFormSheet> createState() => _MaterialFormSheetState();
}

class _MaterialFormSheetState extends State<MaterialFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedUnit = 'KG';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.material != null) {
      _nameController.text = widget.material!['name'] ?? '';
      _selectedUnit = widget.material!['unit'] ?? 'KG';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'name': _nameController.text.trim(),
      'unit': _selectedUnit,
    };

    try {
      if (widget.material != null) {
        final ok = await ApiService.updateMaterial(widget.material!['id'], payload);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật nguyên liệu thành công!"), backgroundColor: Colors.green));
          widget.onSave();
          Navigator.pop(context);
        }
      } else {
        await ApiService.createMaterial(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tạo nguyên liệu mới thành công!"), backgroundColor: Colors.green));
          widget.onSave();
          Navigator.pop(context);
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
    final units = ['KG', 'GRAM', 'LITER', 'ML', 'PIECE'];

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
                  Icon(widget.material != null ? Icons.edit_note_rounded : Icons.add_box_rounded, color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.material != null ? "CẬP NHẬT NGUYÊN LIỆU" : "THÊM NGUYÊN LIỆU MỚI",
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name
              Text("TÊN NGUYÊN LIỆU", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (val) => val == null || val.trim().isEmpty ? "Vui lòng nhập tên nguyên liệu" : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Unit
              Text("ĐƠN VỊ TÍNH (UNIT)", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xff1A1A1A),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                value: _selectedUnit,
                onChanged: (val) => setState(() => _selectedUnit = val!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: units.map((u) {
                  return DropdownMenuItem<String>(
                    value: u,
                    child: Text(u),
                  );
                }).toList(),
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
                      : Text(widget.material != null ? "CẬP NHẬT" : "TẠO NGUYÊN LIỆU", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

// --- Category Form Sheet (Create/Edit Category) ---
class CategoryFormSheet extends StatefulWidget {
  final Map<String, dynamic>? category;
  final VoidCallback onSave;

  const CategoryFormSheet({super.key, this.category, required this.onSave});

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!['name'] ?? '';
      _descController.text = widget.category!['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
    };

    try {
      if (widget.category != null) {
        final ok = await ApiService.updateCategory(widget.category!['id'], payload);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật danh mục thành công!"), backgroundColor: Colors.green));
          widget.onSave();
          Navigator.pop(context);
        }
      } else {
        await ApiService.createCategory(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tạo danh mục mới thành công!"), backgroundColor: Colors.green));
          widget.onSave();
          Navigator.pop(context);
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
                  Icon(widget.category != null ? Icons.edit_note_rounded : Icons.add_box_rounded, color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.category != null ? "CHỈNH SỬA DANH MỤC" : "THÊM DANH MỤC MỚI",
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name
              Text("TÊN DANH MỤC NHÓM MÓN", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                validator: (val) => val == null || val.trim().isEmpty ? "Vui lòng nhập tên danh mục" : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xff0F0F0F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text("MÔ TẢ DANH MỤC", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 14),
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
                      : Text(widget.category != null ? "CẬP NHẬT" : "TẠO DANH MỤC", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
