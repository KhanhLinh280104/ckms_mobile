import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/utils/jwt_parser.dart';
import '../models/user_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // 1. Biến môi trường cao nhất ưu tiên cho Docker / Production
  static const String _apiEnv = String.fromEnvironment('API_BASE_URL');

  // 2. Hàm xử lý bóc tách cấu hình thông minh
  static String _resolveBaseUrl() {
    if (kIsWeb) {
      // Production (Docker + Nginx): dùng path tương đối /api/v1
      // Dev (flutter run -d chrome): đọc từ .env hoặc fallback localhost
      if (_apiEnv.isNotEmpty) return _apiEnv;
      final webUrl = dotenv.maybeGet('API_URL_WEB');
      return webUrl ?? 'http://localhost:8081/api/v1';
    }

    if (_apiEnv.isNotEmpty) return _apiEnv;

    if (Platform.isAndroid) {
      final isEmulator = dotenv.env['RUN_EMULATOR'] == 'true';
      return isEmulator
          ? dotenv.get(
              'API_URL_EMULATOR',
              fallback: 'http://10.0.2.2:8080/api/v1',
            )
          : dotenv.get(
              'API_URL_REAL_DEVICE',
              fallback: 'http://192.168.2.39:8080/api/v1',
            );
    }

    return 'http://localhost:8080/api/v1';
  }

  // 3. URL cuối cùng để gọi API
  static final String _baseUrl = _resolveBaseUrl();

  // Cache của người dùng đang đăng nhập
  static UserModel? currentUser;

  // Track offline mode flag (Giữ lại để tương thích UI, luôn bằng false)
  static bool isOfflineMockMode = false;

  // Headers chứa Authorization Bearer Token
  static Map<String, String> _getAuthHeaders() {
    return {
      'Content-Type': 'application/json',
      if (currentUser?.token != null)
        'Authorization': 'Bearer ${currentUser!.token}',
    };
  }

  // Helper xử lý HTTP Response
  static dynamic _handleResponse(http.Response response) {
    debugPrint(
      'API [${response.request?.method}] ${response.request?.url} -> status ${response.statusCode}',
    );
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
      return null;
    }

    final String decodedBody = utf8.decode(response.bodyBytes);
    dynamic body;
    try {
      body = jsonDecode(decodedBody);
    } catch (_) {
      body = decodedBody;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      String errorMsg = "Yêu cầu thất bại (Mã lỗi: ${response.statusCode})";
      if (body is Map<String, dynamic>) {
        errorMsg =
            body['message'] ??
            body['error'] ??
            body['data']?.toString() ??
            errorMsg;
      } else if (body is String && body.isNotEmpty) {
        errorMsg = body;
      }
      throw Exception(errorMsg);
    }
  }

  // Helper gỡ wrapper ApiResponse<T> (nếu response có bọc qua object data)
  static dynamic _unwrapData(dynamic responseJson) {
    if (responseJson is Map<String, dynamic> &&
        responseJson.containsKey('data')) {
      return responseJson['data'];
    }
    return responseJson;
  }

  // Helper bóc tách danh sách item từ Spring Boot Page<T> (hỗ trợ cả wrapped lẫn raw Page)
  static List<Map<String, dynamic>> _unwrapPageContent(dynamic responseJson) {
    final data = _unwrapData(responseJson);
    if (data is Map<String, dynamic> && data.containsKey('content')) {
      final List content = data['content'] ?? [];
      return content.cast<Map<String, dynamic>>();
    } else if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ==========================================
  // 1. NHÓM CHỨC NĂNG XÁC THỰC (AUTHENTICATION)
  // ==========================================

  /// 1. Đăng nhập hệ thống (POST /api/v1/auth/login)
  static Future<UserModel> login(String username, String password) async {
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      throw Exception("Vui lòng điền đầy đủ tên đăng nhập và mật khẩu");
    }

    isOfflineMockMode = false;
    final url = Uri.parse('$_baseUrl/auth/login');
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': cleanUsername,
            'password': cleanPassword,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final data = _handleResponse(response);
    final rawData = (_unwrapData(data) as Map<String, dynamic>?) ?? {};
    final token = rawData['accessToken'] ?? rawData['token'];

    if (token == null) {
      throw Exception("Không tìm thấy Access Token từ phản hồi của máy chủ");
    }

    final decodedPayload = JwtParser.parse(token);
    if (decodedPayload == null) {
      throw Exception("Không thể giải mã Access Token định dạng JWT");
    }

    currentUser = UserModel.fromResponse(
      responseData: rawData,
      decodedJwt: decodedPayload,
      token: token,
    );

    // Automatically fetch full name (fullName) using GET /api/v1/users/{id} or GET /api/v1/users/search
    try {
      final int? uId = rawData['userId'] != null
          ? int.tryParse(rawData['userId'].toString())
          : (decodedPayload['userId'] != null
                ? int.tryParse(decodedPayload['userId'].toString())
                : null);
      Map<String, dynamic>? profile;
      if (uId != null && uId > 0) {
        profile = await fetchUserById(uId);
      }
      if (profile == null && cleanUsername.isNotEmpty) {
        profile = await searchUser(username: cleanUsername);
      }
      if (profile != null) {
        final String fn =
            (profile['fullName'] ??
                    profile['name'] ??
                    profile['username'] ??
                    '')
                .toString();
        if (fn.isNotEmpty) {
          currentUser = currentUser!.copyWith(
            name: fn,
            email: (profile['email'] ?? currentUser!.email).toString(),
          );
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch full user profile: $e");
    }

    if (currentUser!.name == 'User' || currentUser!.name.isEmpty) {
      currentUser = currentUser!.copyWith(name: cleanUsername);
    }

    return currentUser!;
  }

  /// 2. Quên mật khẩu (POST /api/v1/auth/forgot-password)
  static Future<bool> forgotPassword(String email) async {
    final url = Uri.parse('$_baseUrl/auth/forgot-password');
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  // ==========================================
  // 2. NHÓM CHỨC NĂNG CỬA HÀNG & BẾP (STORES & KITCHENS)
  // ==========================================

  /// 3. Lấy danh sách Cửa hàng nhượng quyền (GET /api/v1/stores?page=0&size=100&search=)
  static Future<List<Map<String, dynamic>>> fetchStores({
    String? search,
    int page = 0,
    int size = 100,
  }) async {
    var urlStr = '$_baseUrl/stores?page=$page&size=$size';
    if (search != null && search.trim().isNotEmpty) {
      urlStr += '&search=${Uri.encodeComponent(search.trim())}';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapPageContent(res);
  }

  /// 4. Tạo mới Cửa hàng nhượng quyền (POST /api/v1/stores)
  static Future<Map<String, dynamic>> createStore(
    Map<String, dynamic> storeData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/stores'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'name': storeData['name'],
            'address': storeData['address'],
            'paymentCycle': storeData['paymentCycle'] ?? 'MONTHLY',
            'phoneNumber': storeData['phoneNumber'] ?? storeData['phone'] ?? '',
            'latitude': storeData['latitude'] ?? 10.7725,
            'longitude': storeData['longitude'] ?? 106.698,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 5. Cập nhật Cửa hàng nhượng quyền (PUT /api/v1/stores/{id})
  static Future<bool> updateStore(
    int storeId,
    Map<String, dynamic> storeData,
  ) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/stores/$storeId'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'name': storeData['name'],
            'address': storeData['address'],
            'paymentCycle': storeData['paymentCycle'] ?? 'MONTHLY',
            'phoneNumber': storeData['phoneNumber'] ?? storeData['phone'] ?? '',
            'latitude': storeData['latitude'] ?? 10.7725,
            'longitude': storeData['longitude'] ?? 106.698,
          }),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 6. Lấy danh sách Bếp trung tâm (GET /api/v1/kitchens)
  static Future<List<Map<String, dynamic>>> fetchKitchens() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/kitchens'), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    final data = _unwrapData(res);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 7. Cập nhật Bếp trung tâm (PATCH /api/v1/kitchens/{kitchenId})
  static Future<bool> updateKitchen(
    int kitchenId,
    Map<String, dynamic> kitchenData,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/kitchens/$kitchenId'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'name': kitchenData['name'] ?? kitchenData['kitchenName'],
            'address': kitchenData['address'],
            'maxDailyCapacity': kitchenData['maxDailyCapacity'] ?? 1000,
            'latitude': kitchenData['latitude'] ?? 10.7629,
            'longitude': kitchenData['longitude'] ?? 106.6822,
            'phone': kitchenData['phone'] ?? '0900000000',
            'isActive': kitchenData['isActive'] ?? true,
          }),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  // ==========================================
  // 3. NHÓM CHỨC NĂNG NGƯỜI DÙNG & VAI TRÒ (USERS & ROLES)
  // ==========================================

  /// 8. Lấy danh sách Người dùng (GET /api/v1/users?page=0&size=100&search=)
  static Future<List<Map<String, dynamic>>> fetchUsers({
    String? search,
    int page = 0,
    int size = 100,
  }) async {
    var urlStr = '$_baseUrl/users?page=$page&size=$size';
    if (search != null && search.trim().isNotEmpty) {
      urlStr += '&search=${Uri.encodeComponent(search.trim())}';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapPageContent(res);
  }

  /// 9. Tạo mới Người dùng (POST /api/v1/users)
  static Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> userData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/users'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'email': userData['email'],
            'fullName': userData['fullName'],
            'roleId': userData['roleId'],
            if (userData['storeId'] != null) 'storeId': userData['storeId'],
            if (userData['kitchenId'] != null)
              'kitchenId': userData['kitchenId'],
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 10. Lấy danh sách Vai trò (GET /api/v1/roles)
  static Future<List<Map<String, dynamic>>> fetchRoles() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/roles'), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    final data = _unwrapData(res);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ==========================================
  // 4. NHÓM CHỨC NĂNG CATALOG (PRODUCTS, CATEGORIES & MATERIALS)
  // ==========================================

  /// 11. Lấy danh sách Sản phẩm (GET /api/v1/products?search=&page=0&size=100)
  static Future<List<Map<String, dynamic>>> fetchProducts({
    String? search,
    int? categoryId,
    int page = 0,
    int size = 100,
  }) async {
    var urlStr = '$_baseUrl/products?page=$page&size=$size';
    if (search != null && search.trim().isNotEmpty) {
      urlStr += '&search=${Uri.encodeComponent(search.trim())}';
    }
    if (categoryId != null) {
      urlStr += '&categoryId=$categoryId';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapPageContent(res);
  }

  /// 12. Tạo mới Sản phẩm (POST /api/v1/products)
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> productData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/products'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'unit': productData['unit'] ?? 'PIECE',
            'name': productData['name'],
            'description': productData['description'],
            'price': productData['price'],
            'categoryId': productData['categoryId'],
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 13. Cập nhật Sản phẩm (PATCH /api/v1/products/{id})
  static Future<bool> updateProduct(
    int productId,
    Map<String, dynamic> productData,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/products/$productId'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'unit': productData['unit'] ?? 'PIECE',
            'name': productData['name'],
            'description': productData['description'],
            'price': productData['price'],
            'categoryId': productData['categoryId'],
          }),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 14. Lấy danh sách Danh mục (GET /api/v1/categories)
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/categories'), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    final data = _unwrapData(res);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 15. Tạo mới Danh mục (POST /api/v1/categories)
  static Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> categoryData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/categories'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'name': categoryData['name'],
            'description': categoryData['description'],
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 16. Cập nhật Danh mục (PATCH /api/v1/categories/{id})
  static Future<bool> updateCategory(
    int categoryId,
    Map<String, dynamic> categoryData,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/categories/$categoryId'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'name': categoryData['name'],
            'description': categoryData['description'],
          }),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 17. Lấy danh sách Nguyên liệu (GET /api/v1/materials)
  static Future<List<Map<String, dynamic>>> fetchMaterials() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/materials'), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    final data = _unwrapData(res);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// 18. Tạo mới Nguyên liệu (POST /api/v1/materials)
  static Future<Map<String, dynamic>> createMaterial(
    Map<String, dynamic> materialData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/materials'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'name': materialData['name'],
            'unit': materialData['unit'] ?? 'KG',
            'isActive': materialData['isActive'] ?? true,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 19. Cập nhật Nguyên liệu (PATCH /api/v1/materials/{id})
  static Future<bool> updateMaterial(
    int materialId,
    Map<String, dynamic> materialData,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/materials/$materialId'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'name': materialData['name'],
            'unit': materialData['unit'] ?? 'KG',
            'isActive': materialData['isActive'] ?? true,
          }),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  // ==========================================
  // 5. NHÓM CHỨC NĂNG ĐƠN HÀNG CỬA HÀNG (STORE ORDERS)
  // ==========================================

  /// 20. Tạo đơn hàng nhượng quyền mới (POST /api/v1/orders)
  static Future<Map<String, dynamic>> createStoreOrder(
    Map<String, dynamic> orderData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/orders'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'items': orderData['items'],
            'deliveryDate':
                orderData['deliveryDate'] ??
                DateTime.now()
                    .add(const Duration(days: 1))
                    .toIso8601String()
                    .split('T')[0],
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 21. Lấy danh sách Đơn hàng của Cửa hàng hiện tại (GET /api/v1/orders/my)
  static Future<List<Map<String, dynamic>>> fetchMyOrders({
    String? status,
    int page = 0,
    int size = 100,
  }) async {
    var urlStr =
        '$_baseUrl/orders/my?page=$page&size=$size&sortBy=orderDate&sortDir=desc';
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      urlStr += '&status=${status.toUpperCase()}';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapPageContent(res);
  }

  /// 21b. Lấy danh sách Đơn hàng với dữ liệu Phân Trang (GET /api/v1/orders/my)
  static Future<Map<String, dynamic>> fetchMyOrdersPaginated({
    String? status,
    int page = 0,
    int size = 10,
  }) async {
    var urlStr =
        '$_baseUrl/orders/my?page=$page&size=$size&sortBy=orderDate&sortDir=desc';
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      urlStr += '&status=${status.toUpperCase()}';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    final data = _unwrapData(res);

    if (data is Map<String, dynamic> && data.containsKey('content')) {
      final List rawContent = data['content'] ?? [];
      return {
        'content': rawContent.cast<Map<String, dynamic>>(),
        'totalPages': data['totalPages'] ?? 1,
        'totalElements': data['totalElements'] ?? rawContent.length,
        'number': data['number'] ?? page,
        'size': data['size'] ?? size,
        'first': data['first'] ?? (page == 0),
        'last': data['last'] ?? true,
      };
    } else if (data is List) {
      return {
        'content': data.cast<Map<String, dynamic>>(),
        'totalPages': 1,
        'totalElements': data.length,
        'number': page,
        'size': size,
        'first': page == 0,
        'last': true,
      };
    }
    return {
      'content': <Map<String, dynamic>>[],
      'totalPages': 1,
      'totalElements': 0,
      'number': page,
      'size': size,
      'first': true,
      'last': true,
    };
  }

  /// 22. Lấy danh sách Tất cả đơn hàng hệ thống (GET /api/v1/orders - dành cho Coordinator)
  static Future<List<Map<String, dynamic>>> fetchOrdersList({
    String? status,
    int page = 0,
    int size = 100,
  }) async {
    var urlStr =
        '$_baseUrl/orders?page=$page&size=$size&sortBy=orderDate&sortDir=desc';
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      urlStr += '&status=${status.toUpperCase()}';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapPageContent(res);
  }

  /// 23. Gửi đơn hàng lên Bếp trung tâm (PATCH /api/v1/orders/{id}/submit)
  static Future<bool> submitStoreOrder(int orderId) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/orders/$orderId/submit'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 24. Phê duyệt / Từ chối Đơn hàng (PATCH /api/v1/orders/{id}/status)
  static Future<bool> updateOrderStatus(int orderId, String status) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/orders/$orderId/status'),
          headers: _getAuthHeaders(),
          body: jsonEncode({'status': status.toUpperCase()}),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 24b. Lấy chi tiết đơn hàng nhượng quyền (GET /api/v1/orders/{id})
  static Future<Map<String, dynamic>> getOrderDetails(int orderId) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/orders/$orderId'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  // ==========================================
  // 6. NHÓM CHỨC NĂNG KẾ HOẠCH SẢN XUẤT (PRODUCTION PLANS)
  // ==========================================

  /// 25. Lấy danh sách Kế hoạch sản xuất (GET /api/v1/production-plans)
  static Future<List<Map<String, dynamic>>> fetchProductionPlans({
    String? status,
    int page = 0,
    int size = 100,
  }) async {
    var urlStr = '$_baseUrl/production-plans?page=$page&size=$size';
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      urlStr += '&status=${status.toUpperCase()}';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapPageContent(res);
  }

  /// 25b. Lấy chi tiết Kế hoạch sản xuất (GET /api/v1/production-plans/{id})
  static Future<Map<String, dynamic>> getProductionPlanDetails(
    int planId,
  ) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/production-plans/$planId'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 25c. Giải mã danh sách sản phẩm thuộc Kế hoạch sản xuất từ Đơn hàng (GET /api/v1/orders/{id})
  static Future<List<Map<String, dynamic>>> resolveProductionPlanItems(
    Map<String, dynamic> plan,
  ) async {
    final List<Map<String, dynamic>> resultItems = [];

    // 1. Direct items check
    if (plan['items'] != null && (plan['items'] as List).isNotEmpty) {
      final List rawItems = plan['items'];
      for (var it in rawItems) {
        if (it is Map<String, dynamic>) {
          resultItems.add(it);
        }
      }
      return resultItems;
    }

    if (plan['orderDetails'] != null && (plan['orderDetails'] as List).isNotEmpty) {
      final List rawDetails = plan['orderDetails'];
      for (var it in rawDetails) {
        if (it is Map<String, dynamic>) {
          resultItems.add({
            'productId': it['productId'] ?? it['id'] ?? 0,
            'productName': it['productName'] ?? it['name'] ?? 'Sản phẩm',
            'plannedQuantity': it['quantity'] ?? it['plannedQuantity'] ?? 0,
            'unit': it['unit'] ?? 'PIECE',
          });
        }
      }
      return resultItems;
    }

    // 2. Extract Order IDs
    final List<int> orderIdsToFetch = [];
    if (plan['orderId'] != null) {
      final idVal = int.tryParse(plan['orderId'].toString());
      if (idVal != null && idVal > 0) orderIdsToFetch.add(idVal);
    }
    if (plan['orderIds'] != null && plan['orderIds'] is List) {
      for (var o in plan['orderIds']) {
        final idVal = int.tryParse(o.toString());
        if (idVal != null && idVal > 0 && !orderIdsToFetch.contains(idVal)) {
          orderIdsToFetch.add(idVal);
        }
      }
    }
    if (plan['orders'] != null && plan['orders'] is List) {
      for (var o in plan['orders']) {
        if (o is Map) {
          final idVal = int.tryParse((o['orderId'] ?? o['id'] ?? '').toString());
          if (idVal != null && idVal > 0 && !orderIdsToFetch.contains(idVal)) {
            orderIdsToFetch.add(idVal);
          }
        } else if (o is num) {
          final idVal = o.toInt();
          if (idVal > 0 && !orderIdsToFetch.contains(idVal)) {
            orderIdsToFetch.add(idVal);
          }
        }
      }
    }

    // 3. Fetch orders via GET /api/v1/orders/{id}
    final Map<int, Map<String, dynamic>> aggregatedMap = {};
    for (int oid in orderIdsToFetch) {
      try {
        final orderData = await getOrderDetails(oid);
        final List details = orderData['orderDetails'] ?? [];
        for (var item in details) {
          final int pid = item['productId'] ?? item['id'] ?? 0;
          final String pName = item['productName'] ?? item['name'] ?? 'Sản phẩm #$pid';
          final int qty = int.tryParse((item['quantity'] ?? item['plannedQuantity'] ?? 0).toString()) ?? 0;
          final String unit = (item['unit'] ?? 'PIECE').toString();

          if (aggregatedMap.containsKey(pid)) {
            aggregatedMap[pid]!['plannedQuantity'] = (aggregatedMap[pid]!['plannedQuantity'] as int) + qty;
          } else {
            aggregatedMap[pid] = {
              'productId': pid,
              'productName': pName,
              'plannedQuantity': qty,
              'unit': unit,
            };
          }
        }
      } catch (e) {
        debugPrint("Error fetching order #$oid for plan: $e");
      }
    }

    if (aggregatedMap.isNotEmpty) {
      return aggregatedMap.values.toList();
    }

    // 4. Fallback to GET /api/v1/production-plans/{id}
    final int planId = int.tryParse((plan['planId'] ?? plan['id'] ?? '').toString()) ?? 0;
    if (planId > 0) {
      try {
        final planDetail = await getProductionPlanDetails(planId);
        if (planDetail['items'] != null && (planDetail['items'] as List).isNotEmpty) {
          for (var it in planDetail['items']) {
            if (it is Map<String, dynamic>) {
              resultItems.add(it);
            }
          }
          return resultItems;
        }
      } catch (_) {}
    }

    return resultItems;
  }

  /// 26. Bắt đầu Kế hoạch sản xuất (POST /api/v1/production-plans/{id}/start)
  static Future<bool> startProductionPlan(int planId) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/production-plans/$planId/start'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 27. Hoàn thành sản xuất / Xuất xưởng (POST /api/v1/production-plans/{id}/yield)
  static Future<bool> finishProductionPlan(
    int planId, {
    List<Map<String, dynamic>>? outputs,
  }) async {
    final payload = {'outputs': outputs ?? [], 'requestVersion': 1};
    final response = await http
        .post(
          Uri.parse('$_baseUrl/production-plans/$planId/yield'),
          headers: _getAuthHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 27b. Đánh dấu Lệnh sản xuất sẵn sàng (PUT /api/v1/production-plans/{id}/ready)
  static Future<bool> markProductionPlanReady(int planId) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/production-plans/$planId/ready'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 27c. Cập nhật Trạng thái Lệnh sản xuất (PATCH /api/v1/production-plans/{id}/status)
  static Future<bool> updateProductionPlanStatus(
    int planId,
    String status,
  ) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/production-plans/$planId/status'),
          headers: _getAuthHeaders(),
          body: jsonEncode({'status': status.toUpperCase()}),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  // ==========================================
  // 7. NHÓM CHỨC NĂNG GIAO HÀNG & LOGISTICS (SHIPMENTS)
  // ==========================================

  /// 28. Lấy danh sách Chuyến xe (GET /api/v1/shipments)
  static Future<List<Map<String, dynamic>>> fetchShipmentsList({
    String? status,
    int page = 0,
    int size = 100,
  }) async {
    var urlStr = '$_baseUrl/shipments?page=$page&size=$size';
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      urlStr += '&status=${status.toUpperCase()}';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapPageContent(res);
  }

  /// Alias fetchShipments() cho màn hình gọi ngắn gọn
  static Future<List<Map<String, dynamic>>> fetchShipments({String? status}) =>
      fetchShipmentsList(status: status);

  /// 29. Lấy chi tiết Chuyến xe (GET /api/v1/shipments/{id})
  static Future<Map<String, dynamic>> getShipmentDetails(int shipmentId) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/shipments/$shipmentId'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 30. Tạo Chuyến xe giao hàng mới (POST /api/v1/shipments)
  static Future<Map<String, dynamic>> createShipment(
    Map<String, dynamic> shipmentData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/shipments'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'ahamoveServiceId': shipmentData['ahamoveServiceId'] ?? 'SGN-BIKE',
            'productionPlanId': shipmentData['productionPlanId'],
            'dropPoints': shipmentData['dropPoints'] ?? [],
            'remarks': shipmentData['remarks'] ?? '',
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 31. Chuẩn bị Chuyến xe (PATCH /api/v1/shipments/{id}/prepare)
  static Future<bool> prepareShipment(int shipmentId) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/shipments/$shipmentId/prepare'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// 32. Xuất kho - Bắt đầu vận chuyển (PATCH /api/v1/shipments/{id}/transit)
  static Future<bool> startShipmentTransit(int shipmentId) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/shipments/$shipmentId/transit'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  static Future<bool> startTransit(int shipmentId) =>
      startShipmentTransit(shipmentId);

  /// 33. Xác nhận nhận hàng tại Điểm dừng (PATCH /api/v1/shipments/{id}/stops/{stopId}/confirm)
  static Future<bool> confirmShipmentDelivery(
    int shipmentId, {
    int? stopId,
    String? feedbackNote,
    int qualityRating = 5,
  }) async {
    int targetStopId = stopId ?? 0;

    // Nếu không truyền stopId, tự động fetch shipment details để tìm stopId của Cửa hàng hiện tại
    if (targetStopId == 0) {
      try {
        final details = await getShipmentDetails(shipmentId);
        final List stops = details['stops'] ?? [];
        for (var s in stops) {
          if (s['storeId'] == currentUser?.storeId) {
            targetStopId = s['stopId'] ?? 0;
            break;
          }
        }
        if (targetStopId == 0 && stops.isNotEmpty) {
          targetStopId = stops.first['stopId'] ?? 0;
        }
      } catch (_) {}
    }

    final response = await http
        .patch(
          Uri.parse(
            '$_baseUrl/shipments/$shipmentId/stops/$targetStopId/confirm',
          ),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'feedbackNote': feedbackNote ?? 'Hàng nhận đủ, nguyên tem',
            'qualityRating': qualityRating,
          }),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  // ==========================================
  // 8. NHÓM CHỨC NĂNG HÓA ĐƠN & THANH TOÁN (BILLING STATEMENTS)
  // ==========================================

  /// 34. Lấy danh sách Hóa đơn (GET /api/v1/billing-statements)
  static Future<List<Map<String, dynamic>>> fetchBillingStatements({
    String? status,
    int? storeId,
    int page = 0,
    int size = 100,
  }) async {
    var urlStr = '$_baseUrl/billing-statements?page=$page&size=$size';
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      urlStr += '&status=${status.toUpperCase()}';
    }
    if (storeId != null) {
      urlStr += '&storeId=$storeId';
    }
    final response = await http
        .get(Uri.parse(urlStr), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapPageContent(res);
  }

  /// 35. Xuất hóa đơn hàng loạt (POST /api/v1/billing-statements/generate/batch)
  static Future<Map<String, dynamic>> generateBatchBilling(
    Map<String, dynamic> batchData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/billing-statements/generate/batch'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'periodStart':
                batchData['periodStart'] ??
                DateTime.now().toIso8601String().split('T')[0],
            'periodEnd':
                batchData['periodEnd'] ??
                DateTime.now().toIso8601String().split('T')[0],
            'cycleName': batchData['cycleName'] ?? 'Chu kỳ mới',
          }),
        )
        .timeout(const Duration(seconds: 15));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// 36. Thanh toán Hóa đơn (PATCH /api/v1/billing-statements/{id}/pay)
  static Future<bool> updateBillingStatementStatus(
    int statementId,
    String status, {
    int paymentMethodId = 1,
    String? transactionReference,
    String? note,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_baseUrl/billing-statements/$statementId/pay'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'paymentMethodId': paymentMethodId,
            'transactionReference':
                transactionReference ??
                'MOB-${DateTime.now().millisecondsSinceEpoch}',
            'note': note ?? 'Paid via Mobile app',
          }),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  // ==========================================
  // 9. NHÓM THỐNG KÊ DASHBOARD (DASHBOARD STATS)
  // ==========================================

  /// 37. Lấy thống kê cho Dashboard
  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    final stats = <String, dynamic>{
      'activeStores': 0,
      'activeUsers': 0,
      'pendingOrders': 0,
      'pendingShipments': 0,
      'productionPlans': 0,
    };

    if (currentUser == null) return stats;

    try {
      if (currentUser!.role == 'ADMIN' || currentUser!.role == 'COORDINATOR') {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/stores?size=1'),
            headers: _getAuthHeaders(),
          );
          final parsed = _handleResponse(res);
          final data = _unwrapData(parsed);
          if (data is Map && data.containsKey('totalElements')) {
            stats['activeStores'] = data['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      if (currentUser!.role == 'ADMIN') {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/users?size=1'),
            headers: _getAuthHeaders(),
          );
          final parsed = _handleResponse(res);
          final data = _unwrapData(parsed);
          if (data is Map && data.containsKey('totalElements')) {
            stats['activeUsers'] = data['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      if (currentUser!.role != 'KITCHEN_STAFF' &&
          currentUser!.role != 'ADMIN') {
        try {
          final endpoint = currentUser!.role == 'COORDINATOR'
              ? '/orders'
              : '/orders/my';
          final res = await http.get(
            Uri.parse('$_baseUrl$endpoint?size=1'),
            headers: _getAuthHeaders(),
          );
          final parsed = _handleResponse(res);
          final data = _unwrapData(parsed);
          if (data is Map && data.containsKey('totalElements')) {
            stats['pendingOrders'] = data['totalElements'] ?? 0;
          } else if (parsed is Map && parsed.containsKey('totalElements')) {
            stats['pendingOrders'] = parsed['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      if (currentUser!.role == 'COORDINATOR' ||
          currentUser!.role == 'KITCHEN_STAFF') {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/shipments?size=1'),
            headers: _getAuthHeaders(),
          );
          final parsed = _handleResponse(res);
          final data = _unwrapData(parsed);
          if (data is Map && data.containsKey('totalElements')) {
            stats['pendingShipments'] = data['totalElements'] ?? 0;
          }
        } catch (_) {}

        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/production-plans?size=1'),
            headers: _getAuthHeaders(),
          );
          final parsed = _handleResponse(res);
          final data = _unwrapData(parsed);
          if (data is Map && data.containsKey('totalElements')) {
            stats['productionPlans'] = data['totalElements'] ?? 0;
          } else if (parsed is Map && parsed.containsKey('totalElements')) {
            stats['productionPlans'] = parsed['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      return stats;
    } catch (e) {
      debugPrint("Failed to fetch dashboard stats: $e");
      return stats;
    }
  }

  /// 38. Lấy hoạt động gần đây cho Dashboard
  static Future<List<Map<String, dynamic>>> fetchRecentActivity() async {
    if (currentUser == null) return [];

    try {
      if (currentUser!.role == 'KITCHEN_STAFF') {
        final list = await fetchShipmentsList(size: 5);
        return list
            .map<Map<String, dynamic>>(
              (s) => {
                'type': 'SHIPMENT',
                'id': s['shipmentId'] ?? s['id'],
                'title': 'Chuyến xe: TRK-${s['shipmentId'] ?? s['id']}',
                'subtitle': s['storeName'] ?? 'Cửa hàng #${s['storeId'] ?? ""}',
                'status': s['status'] ?? 'PENDING',
              },
            )
            .toList();
      } else {
        final list = currentUser!.role == 'COORDINATOR'
            ? await fetchOrdersList(size: 5)
            : await fetchMyOrders(size: 5);

        return list
            .map<Map<String, dynamic>>(
              (o) => {
                'type': 'ORDER',
                'id': o['orderId'] ?? o['id'],
                'title': 'Mã ĐH: #${o['orderId'] ?? o['id']}',
                'subtitle': o['storeName'] ?? 'Cửa hàng #${o['storeId'] ?? ""}',
                'status': o['status'] ?? 'PENDING',
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint("Failed to fetch recent activities: $e");
      return [];
    }
  }

  // ==========================================
  // NHÓM CÔNG THỨC (RECIPES)
  // ==========================================

  /// Lấy công thức đang hoạt động của sản phẩm (GET /api/v1/recipes/product/{productId}/active)
  static Future<Map<String, dynamic>?> fetchActiveRecipe(int productId) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/recipes/product/$productId/active'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    final data = _unwrapData(res);
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  /// Tạo mới Công thức chế biến (POST /api/v1/recipes)
  static Future<Map<String, dynamic>> createRecipe(
    Map<String, dynamic> recipeData,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/recipes'),
          headers: _getAuthHeaders(),
          body: jsonEncode(recipeData),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  // ==========================================
  // NHÓM QUẢN LÝ QUYỀN HẠN (PRIVILEGES) & VAI TRÒ (ROLES) & USER PROFILE & MAPS
  // ==========================================

  /// Lấy thông tin người dùng theo ID (GET /api/v1/users/{id})
  static Future<Map<String, dynamic>?> fetchUserById(int userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/users/$userId'), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 10));

      final data = _handleResponse(response);
      final rawData = (_unwrapData(data) as Map<String, dynamic>?) ?? {};
      return rawData;
    } catch (e) {
      debugPrint("Failed to fetch user by ID ($userId): $e");
      return null;
    }
  }

  /// Tìm kiếm người dùng theo username/email (GET /api/v1/users/search)
  static Future<Map<String, dynamic>?> searchUser({
    String? username,
    String? email,
  }) async {
    try {
      var urlStr = '$_baseUrl/users/search';
      final params = <String>[];
      if (username != null && username.isNotEmpty) {
        params.add('username=${Uri.encodeComponent(username)}');
      }
      if (email != null && email.isNotEmpty) {
        params.add('email=${Uri.encodeComponent(email)}');
      }
      if (params.isNotEmpty) {
        urlStr += '?${params.join('&')}';
      }

      final response = await http
          .get(Uri.parse(urlStr), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 10));

      final data = _handleResponse(response);
      return _unwrapData(data) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint("Failed to search user: $e");
      return null;
    }
  }

  /// Lấy tất cả Quyền hạn (GET /api/v1/privileges)
  static Future<List<Map<String, dynamic>>> fetchPrivileges() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/privileges'), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    final data = _unwrapData(res);
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Lấy chi tiết Quyền hạn (GET /api/v1/privileges/{id})
  static Future<Map<String, dynamic>?> fetchPrivilegeById(int id) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/privileges/$id'), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    final data = _unwrapData(res);
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  /// Tạo mới Quyền hạn (POST /api/v1/privileges)
  static Future<Map<String, dynamic>> createPrivilege(
    String code,
    String description,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/privileges'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'code': code.trim(),
            'description': description.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// Cập nhật Quyền hạn (PUT /api/v1/privileges/{id})
  static Future<Map<String, dynamic>> updatePrivilege(
    int id,
    String code,
    String description,
  ) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/privileges/$id'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'code': code.trim(),
            'description': description.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// Xóa Quyền hạn (DELETE /api/v1/privileges/{id})
  static Future<bool> deletePrivilege(int id) async {
    final response = await http
        .delete(
          Uri.parse('$_baseUrl/privileges/$id'),
          headers: _getAuthHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  // ==========================================
  // NHÓM CHỨC NĂNG VAI TRÒ (ROLES API)
  // ==========================================

  /// Lấy chi tiết Vai trò theo ID (GET /api/v1/roles/{id})
  static Future<Map<String, dynamic>?> fetchRoleById(int id) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/roles/$id'), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return _unwrapData(res) as Map<String, dynamic>?;
  }

  /// Tạo mới Vai trò (POST /api/v1/roles)
  static Future<Map<String, dynamic>> createRole(
    String roleName,
    List<int> privilegeIds,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/roles'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'roleName': roleName.trim(),
            'privilegeIds': privilegeIds,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// Cập nhật Vai trò (PUT /api/v1/roles/{id})
  static Future<Map<String, dynamic>> updateRole(
    int id,
    String roleName,
    List<int> privilegeIds,
  ) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/roles/$id'),
          headers: _getAuthHeaders(),
          body: jsonEncode({
            'roleName': roleName.trim(),
            'privilegeIds': privilegeIds,
          }),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// Xóa Vai trò (DELETE /api/v1/roles/{id})
  static Future<bool> deleteRole(int id) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/roles/$id'), headers: _getAuthHeaders())
        .timeout(const Duration(seconds: 10));

    _handleResponse(response);
    return true;
  }

  /// Gán quyền cho Vai trò (POST /api/v1/roles/{roleId}/privileges)
  static Future<Map<String, dynamic>> assignPrivilegesToRole(
    int roleId,
    List<int> privilegeIds,
  ) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/roles/$roleId/privileges'),
          headers: _getAuthHeaders(),
          body: jsonEncode(privilegeIds),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  /// Gỡ quyền khỏi Vai trò (DELETE /api/v1/roles/{roleId}/privileges)
  static Future<Map<String, dynamic>> removePrivilegesFromRole(
    int roleId,
    List<int> privilegeIds,
  ) async {
    final response = await http
        .delete(
          Uri.parse('$_baseUrl/roles/$roleId/privileges'),
          headers: _getAuthHeaders(),
          body: jsonEncode(privilegeIds),
        )
        .timeout(const Duration(seconds: 10));

    final res = _handleResponse(response);
    return (_unwrapData(res) as Map<String, dynamic>?) ?? {};
  }

  // --- Goong Map APIs ---

  /// Goong Place Autocomplete API
  static Future<List<Map<String, dynamic>>> goongAutoComplete(
    String input,
  ) async {
    final String apiKey =
        dotenv.maybeGet('GOONG_API_KEY') ?? 'YOUR_GOONG_API_KEY';
    final url = Uri.parse(
      'https://rsapi.goong.io/Place/AutoComplete?api_key=$apiKey&input=${Uri.encodeComponent(input)}',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['predictions'] is List) {
          return (data['predictions'] as List).cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint("Goong Autocomplete error: $e");
    }
    return [];
  }

  /// Goong Place Detail API
  static Future<Map<String, dynamic>?> goongPlaceDetail(String placeId) async {
    final String apiKey =
        dotenv.maybeGet('GOONG_API_KEY') ?? 'YOUR_GOONG_API_KEY';
    final url = Uri.parse(
      'https://rsapi.goong.io/Place/Detail?api_key=$apiKey&place_id=${Uri.encodeComponent(placeId)}',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("Goong Place Detail error: $e");
    }
    return null;
  }

  /// Goong Directions API
  static Future<Map<String, dynamic>?> goongDirections(
    String origin,
    String destination,
  ) async {
    final String apiKey =
        dotenv.maybeGet('GOONG_API_KEY') ?? 'YOUR_GOONG_API_KEY';
    final url = Uri.parse(
      'https://rsapi.goong.io/Direction?origin=${Uri.encodeComponent(origin)}&destination=${Uri.encodeComponent(destination)}&vehicle=car&api_key=$apiKey',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint("Goong Directions error: $e");
    }
    return null;
  }
}
