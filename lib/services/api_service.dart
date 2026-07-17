import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/utils/jwt_parser.dart';
import '../models/user_model.dart';

class ApiService {
  // Base URL for API requests.
  // Using 10.0.2.2 for Android Emulator to connect to localhost, and localhost for other platforms.
  static final String _baseUrl = kIsWeb
      ? ''
      : (Platform.isAndroid
            ? 'http://192.168.2.23:8080/api/v1'
            : 'http://localhost:8080/api/v1');

  // Cache of the currently logged-in user
  static UserModel? currentUser;

  // Track if we are running in Offline/Demo Mock Mode
  static bool isOfflineMockMode = false;

  /// Logs in the user with username and password.
  /// Connects to real API, and falls back to Mock accounts if the connection fails.
  static Future<UserModel> login(String username, String password) async {
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      throw Exception("Vui lòng điền đầy đủ tên đăng nhập và mật khẩu");
    }

    try {
      isOfflineMockMode = false;

      final url = Uri.parse('$_baseUrl/auth/login');
      debugPrint("Connecting to API: $url");

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': cleanUsername,
              'password': cleanPassword,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final token = data['accessToken'] ?? data['token'];

        if (token == null) {
          throw Exception(
            "Không tìm thấy Access Token từ phản hồi của máy chủ",
          );
        }

        final decodedPayload = JwtParser.parse(token);
        if (decodedPayload == null) {
          throw Exception("Không thể giải mã Access Token định dạng JWT");
        }

        currentUser = UserModel.fromResponse(
          responseData: data,
          decodedJwt: decodedPayload,
          token: token,
        );

        debugPrint(
          "Logged in successfully via API. User: ${currentUser!.name}, Role: ${currentUser!.role}",
        );
        return currentUser!;
      } else {
        // Parse error message if available
        String errorMsg = "Đăng nhập thất bại (Mã lỗi: ${response.statusCode})";
        try {
          final errorBody = jsonDecode(response.body);
          errorMsg = errorBody['message'] ?? errorBody['error'] ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("API login failed with error: $e");

      // If error is network-related (e.g. Server down, timeout, SocketException), try mock login fallback
      if (e is SocketException ||
          e is http.ClientException ||
          e.toString().contains("timeout")) {
        debugPrint(
          "Network issues detected. Falling back to local offline mock authentication...",
        );
        return _tryMockLogin(cleanUsername, cleanPassword);
      } else {
        rethrow;
      }
    }
  }

  /// Attempts to authenticate against local mock credentials
  static UserModel _tryMockLogin(String username, String password) {
    // Standard mock accounts mapping
    final mockAccounts = {
      'admin': {
        'pass': 'admin123',
        'name': 'Nguyễn Quản Trị',
        'role': 'ADMIN',
        'email': 'admin@ckms.com',
      },
      'coordinator': {
        'pass': 'coord123',
        'name': 'Trần Điều Phối',
        'role': 'COORDINATOR',
        'email': 'coordinator@ckms.com',
      },
      'kitchen': {
        'pass': 'kitchen123',
        'name': 'Lê Nhân Viên Bếp',
        'role': 'KITCHEN_STAFF',
        'email': 'kitchen@ckms.com',
      },
      'store': {
        'pass': 'store123',
        'name': 'Phạm Nhân Viên Cửa Hàng',
        'role': 'STORE_STAFF',
        'email': 'store@ckms.com',
        'storeId': 1,
        'storeName': 'Cửa hàng Quận 1',
      },
      'manager': {
        'pass': 'manager123',
        'name': 'Hoàng Quản Lý Phân Phối',
        'role': 'MANAGER',
        'email': 'manager@ckms.com',
      },
    };

    final lowerUser = username.toLowerCase();
    if (mockAccounts.containsKey(lowerUser) &&
        mockAccounts[lowerUser]!['pass'] == password) {
      final mockData = mockAccounts[lowerUser]!;

      isOfflineMockMode = true;
      currentUser = UserModel(
        id: 'mock-user-id-${mockData['role']}',
        name: mockData['name'] as String,
        email: mockData['email'] as String,
        role: mockData['role'] as String,
        token: 'mock-jwt-token-string',
        storeId: mockData['storeId'] as int?,
        storeName: mockData['storeName'] as String?,
        kitchenId: mockData['role'] == 'KITCHEN_STAFF' ? 1 : null,
        kitchenName: mockData['role'] == 'KITCHEN_STAFF'
            ? 'Bếp trung tâm số 1'
            : null,
        authorities: ['ROLE_${mockData['role']}', 'VIEW_DASHBOARD'],
      );

      debugPrint(
        "Offline Login Success: ${currentUser!.name} as ${currentUser!.role}",
      );
      return currentUser!;
    } else {
      throw Exception(
        "Tên đăng nhập hoặc mật khẩu không chính xác (Đang ở chế độ Offline/Demo)",
      );
    }
  }

  /// Sends a forgot password request
  static Future<bool> forgotPassword(String email) async {
    if (isOfflineMockMode) {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/forgot-password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      // Fallback for offline demo
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }
  }

  /// Fetches stats for dashboard based on user role
  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    if (currentUser == null) {
      throw Exception("Người dùng chưa đăng nhập");
    }

    if (isOfflineMockMode) {
      await Future.delayed(const Duration(milliseconds: 600)); // Simulate delay
      return _getMockStatsForRole(currentUser!.role);
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${currentUser!.token}',
    };

    final stats = <String, dynamic>{};

    try {
      // 1. Fetch Store Stats (Admin, Coordinator)
      if (currentUser!.role == 'ADMIN' || currentUser!.role == 'COORDINATOR') {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/stores?size=1'),
            headers: headers,
          );
          if (res.statusCode == 200) {
            final page = jsonDecode(res.body);
            stats['activeStores'] = page['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      // 2. Fetch User Stats (Admin only)
      if (currentUser!.role == 'ADMIN') {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/users?size=1'),
            headers: headers,
          );
          if (res.statusCode == 200) {
            final page = jsonDecode(res.body);
            stats['activeUsers'] = page['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      // 3. Fetch Orders (Coordinator: All orders, Store staff / Manager: My orders)
      if (currentUser!.role != 'KITCHEN_STAFF' &&
          currentUser!.role != 'ADMIN') {
        try {
          final endpoint = currentUser!.role == 'COORDINATOR'
              ? '/orders'
              : '/orders/my';
          final res = await http.get(
            Uri.parse('$_baseUrl$endpoint?size=1'),
            headers: headers,
          );
          if (res.statusCode == 200) {
            final page = jsonDecode(res.body);
            stats['pendingOrders'] = page['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      // 4. Fetch Shipments (Coordinator, Kitchen)
      if (currentUser!.role == 'COORDINATOR' ||
          currentUser!.role == 'KITCHEN_STAFF') {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/shipments?size=1'),
            headers: headers,
          );
          if (res.statusCode == 200) {
            final page = jsonDecode(res.body);
            stats['pendingShipments'] = page['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      // 5. Fetch Production Plans (Coordinator, Kitchen Staff)
      if (currentUser!.role == 'COORDINATOR' ||
          currentUser!.role == 'KITCHEN_STAFF') {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/production-plans?size=1'),
            headers: headers,
          );
          if (res.statusCode == 200) {
            final page = jsonDecode(res.body);
            stats['productionPlans'] = page['totalElements'] ?? 0;
          }
        } catch (_) {}
      }

      // Make sure we have defaults for missing role fields to avoid null errors on UI
      return _fillMissingStats(stats, currentUser!.role);
    } catch (e) {
      debugPrint(
        "Failed to fetch dashboard stats from API: $e. Falling back to mock.",
      );
      return _getMockStatsForRole(currentUser!.role);
    }
  }

  /// Fetches recent activities (Orders or Shipments)
  static Future<List<Map<String, dynamic>>> fetchRecentActivity() async {
    if (currentUser == null) return [];

    if (isOfflineMockMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      return _getMockActivitiesForRole(currentUser!.role);
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${currentUser!.token}',
    };

    try {
      // 1. For Kitchen Staff -> Fetch shipments
      if (currentUser!.role == 'KITCHEN_STAFF') {
        final res = await http.get(
          Uri.parse('$_baseUrl/shipments?size=5&page=0'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          final page = jsonDecode(res.body);
          final List content = page['content'] ?? [];
          return content
              .map<Map<String, dynamic>>(
                (s) => {
                  'type': 'SHIPMENT',
                  'id': s['shipmentId'] ?? s['id'],
                  'title': 'Chuyến xe: TRK-${s['shipmentId'] ?? s['id']}',
                  'subtitle':
                      s['storeName'] ?? 'Cửa hàng #${s['storeId'] ?? ""}',
                  'status': s['status'] ?? 'PENDING',
                },
              )
              .toList();
        }
      }

      // 2. For Coordinator, Store Staff, Manager -> Fetch orders
      if (currentUser!.role != 'ADMIN') {
        final endpoint = currentUser!.role == 'COORDINATOR'
            ? '/orders'
            : '/orders/my';
        final res = await http.get(
          Uri.parse('$_baseUrl$endpoint?size=5&page=0'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          final page = jsonDecode(res.body);
          final List content = page['content'] ?? [];
          return content
              .map<Map<String, dynamic>>(
                (o) => {
                  'type': 'ORDER',
                  'id': o['orderId'] ?? o['id'],
                  'title': 'Mã ĐH: #${o['orderId'] ?? o['id']}',
                  'subtitle':
                      o['storeName'] ?? 'Cửa hàng #${o['storeId'] ?? ""}',
                  'status': o['status'] ?? 'PENDING',
                },
              )
              .toList();
        }
      }

      // Admin has no specific activities to show, we can show a general mock list or empty
      return _getMockActivitiesForRole(currentUser!.role);
    } catch (e) {
      debugPrint(
        "Failed to fetch recent activities from API: $e. Falling back to mock.",
      );
      return _getMockActivitiesForRole(currentUser!.role);
    }
  }

  // --- New ADMIN/MANAGER APIs ---

  // Keep a local in-memory list of mock users so that adding a user actually persists during the session!
  static final List<Map<String, dynamic>> _mockUsers = [
    {
      'userId': 1,
      'username': 'admin',
      'email': 'admin@ckms.com',
      'fullName': 'Nguyễn Quản Trị',
      'roleName': 'ADMIN',
      'isActive': true,
      'status': 'ACTIVE',
    },
    {
      'userId': 2,
      'username': 'coordinator',
      'email': 'coordinator@ckms.com',
      'fullName': 'Trần Điều Phối',
      'roleName': 'COORDINATOR',
      'isActive': true,
      'status': 'ACTIVE',
    },
    {
      'userId': 3,
      'username': 'kitchen',
      'email': 'kitchen@ckms.com',
      'fullName': 'Lê Nhân Viên Bếp',
      'roleName': 'KITCHEN_STAFF',
      'isActive': true,
      'status': 'ACTIVE',
      'kitchenName': 'Bếp trung tâm số 1',
      'kitchenId': 1,
    },
    {
      'userId': 4,
      'username': 'store',
      'email': 'store@ckms.com',
      'fullName': 'Phạm Nhân Viên Cửa Hàng',
      'roleName': 'STORE_STAFF',
      'isActive': true,
      'status': 'ACTIVE',
      'storeName': 'Cửa hàng Quận 1',
      'storeId': 1,
    },
    {
      'userId': 5,
      'username': 'manager',
      'email': 'manager@ckms.com',
      'fullName': 'Hoàng Quản Lý Phân Phối',
      'roleName': 'MANAGER',
      'isActive': true,
      'status': 'ACTIVE',
    },
  ];

  static final List<Map<String, dynamic>> _mockStoresList = [
    {
      'id': 1,
      'storeId': 1,
      'name': 'Cửa hàng Quận 1',
      'address': '120 Lê Lợi, Bến Thành, Quận 1, TP. HCM',
      'phone': '0901111111',
      'email': 'q1@steakchain.vn',
      'isActive': true,
      'paymentCycle': 'MONTHLY',
      'latitude': 10.7725,
      'longitude': 106.6980,
    },
    {
      'id': 2,
      'storeId': 2,
      'name': 'Chi nhánh Quận 3',
      'address': '72 Lê Thánh Tôn, Bến Nghé, Quận 1, TP. HCM',
      'phone': '0902222222',
      'email': 'q3@steakchain.vn',
      'isActive': true,
      'paymentCycle': 'WEEKLY',
      'latitude': 10.7782,
      'longitude': 106.7021,
    },
    {
      'id': 3,
      'storeId': 3,
      'name': 'Chi nhánh Bình Thạnh',
      'address': '268 Lý Thường Kiệt, Quận 10, TP. HCM',
      'phone': '0903333333',
      'email': 'bt@steakchain.vn',
      'isActive': true,
      'paymentCycle': 'MONTHLY',
      'latitude': 10.7735,
      'longitude': 106.6601,
    },
    {
      'id': 4,
      'storeId': 4,
      'name': 'Chi nhánh Quận 7',
      'address': '10 Huỳnh Tấn Phát, Tân Thuận Đông, Quận 7, TP. HCM',
      'phone': '0904444444',
      'email': 'q7@steakchain.vn',
      'isActive': true,
      'paymentCycle': 'MONTHLY',
      'latitude': 10.7410,
      'longitude': 106.7230,
    },
    {
      'id': 5,
      'storeId': 5,
      'name': 'Chi nhánh Thủ Đức',
      'address': '1 Võ Văn Ngân, Linh Chiểu, Thủ Đức, TP. HCM',
      'phone': '0905555555',
      'email': 'td@steakchain.vn',
      'isActive': true,
      'paymentCycle': 'QUARTERLY',
      'latitude': 10.8510,
      'longitude': 106.7720,
    },
  ];

  static final List<Map<String, dynamic>> _mockKitchensList = [
    {
      'kitchenId': 1,
      'kitchenName': 'Bếp trung tâm số 1',
      'address': '288 Nguyễn Văn Cừ, Quận 5, TP. HCM',
      'maxDailyCapacity': 1000,
      'isActive': true,
      'latitude': 10.7629,
      'longitude': 106.6822,
    },
  ];

  static final List<Map<String, dynamic>> _mockProducts = [
    {
      'id': 1,
      'name': 'Steak Bò Mỹ (Premium)',
      'description': 'Bò Mỹ nhập khẩu nguyên miếng nướng vừa',
      'price': 249000,
      'unit': 'PIECE',
      'category': {'id': 1, 'name': 'Món Chính', 'description': 'Món ăn chính'},
      'isActive': true,
    },
    {
      'id': 2,
      'name': 'Salad Cá Hồi',
      'description': 'Salad rau xanh kèm cá hồi áp chảo sốt chanh leo',
      'price': 125000,
      'unit': 'PIECE',
      'category': {
        'id': 2,
        'name': 'Khai Vị',
        'description': 'Khai vị nhẹ nhàng',
      },
      'isActive': true,
    },
    {
      'id': 3,
      'name': 'Súp Kem Bí Đỏ',
      'description': 'Súp bí đỏ sánh mịn cùng kem tươi Pháp',
      'price': 75000,
      'unit': 'PIECE',
      'category': {
        'id': 2,
        'name': 'Khai Vị',
        'description': 'Khai vị nhẹ nhàng',
      },
      'isActive': true,
    },
    {
      'id': 4,
      'name': 'Pizza Hải Sản',
      'description':
          'Pizza đế mỏng nhân hải sản tươi tôm mực và phô mai kéo sợi',
      'price': 189000,
      'unit': 'PIECE',
      'category': {'id': 1, 'name': 'Món Chính', 'description': 'Món ăn chính'},
      'isActive': true,
    },
    {
      'id': 5,
      'name': 'Bánh Mì Bơ Tỏi',
      'description': 'Bánh mì nướng giòn rụm thơm bơ tỏi đặc trưng',
      'price': 35000,
      'unit': 'PIECE',
      'category': {'id': 3, 'name': 'Ăn Kèm', 'description': 'Món ăn phụ'},
      'isActive': true,
    },
    {
      'id': 6,
      'name': 'Khoai Tây Chiên Truffle',
      'description': 'Khoai tây cắt múi chiên giòn rắc muối truffle thơm lừng',
      'price': 65000,
      'unit': 'PIECE',
      'category': {'id': 3, 'name': 'Ăn Kèm', 'description': 'Món ăn phụ'},
      'isActive': true,
    },
    {
      'id': 7,
      'name': 'Nước Ép Chanh Dây',
      'description': 'Nước ép chanh dây chua ngọt tươi mát giải nhiệt',
      'price': 40000,
      'unit': 'PIECE',
      'category': {'id': 4, 'name': 'Đồ Uống', 'description': 'Nước giải khát'},
      'isActive': true,
    },
  ];

  static final List<Map<String, dynamic>> _mockBillingStatements = [
    {
      'statementId': 2001,
      'storeName': 'Cửa hàng Quận 1',
      'storeId': 1,
      'cycleName': 'Chu kỳ T7/2026',
      'totalAmount': 18500000,
      'status': 'ISSUED',
      'issuedAt': '2026-07-14T08:00:00Z',
    },
    {
      'statementId': 2002,
      'storeName': 'Chi nhánh Quận 3',
      'storeId': 2,
      'cycleName': 'Chu kỳ T7/2026',
      'totalAmount': 24200000,
      'status': 'PAID',
      'issuedAt': '2026-07-13T09:30:00Z',
    },
    {
      'statementId': 2003,
      'storeName': 'Cửa hàng Bình Thạnh',
      'storeId': 3,
      'cycleName': 'Chu kỳ T7/2026',
      'totalAmount': 12000000,
      'status': 'OVERDUE',
      'issuedAt': '2026-07-05T10:00:00Z',
    },
    {
      'statementId': 2004,
      'storeName': 'Chi nhánh Quận 7',
      'storeId': 4,
      'cycleName': 'Chu kỳ Vừa qua',
      'totalAmount': 31500000,
      'status': 'PAID',
      'issuedAt': '2026-06-15T08:00:00Z',
    },
    {
      'statementId': 2005,
      'storeName': 'Chi nhánh Thủ Đức',
      'storeId': 5,
      'cycleName': 'Chu kỳ T7/2026',
      'totalAmount': 9500000,
      'status': 'DRAFT',
      'issuedAt': '2026-07-14T15:00:00Z',
    },
  ];

  static final List<Map<String, dynamic>> _mockCategoriesList = [
    {
      'id': 1,
      'name': 'Món Chính',
      'description': 'Món ăn chính phục vụ tại bàn',
      'status': 'ACTIVE',
    },
    {
      'id': 2,
      'name': 'Khai Vị',
      'description': 'Món khai vị nhẹ nhàng kích thích vị giác',
      'status': 'ACTIVE',
    },
    {
      'id': 3,
      'name': 'Ăn Kèm',
      'description': 'Món phụ dùng kèm món chính',
      'status': 'ACTIVE',
    },
    {
      'id': 4,
      'name': 'Đồ Uống',
      'description': 'Các loại nước giải khát, rượu vang',
      'status': 'ACTIVE',
    },
  ];

  static final List<Map<String, dynamic>> _mockMaterialsList = [
    {
      'id': 1,
      'name': 'Thịt Thăn Bò Mỹ',
      'unit': 'KG',
      'minStockLevel': 50,
      'isActive': true,
    },
    {
      'id': 2,
      'name': 'Cá Hồi Tươi',
      'unit': 'KG',
      'minStockLevel': 20,
      'isActive': true,
    },
    {
      'id': 3,
      'name': 'Kem Tươi Pháp',
      'unit': 'LITER',
      'minStockLevel': 10,
      'isActive': true,
    },
    {
      'id': 4,
      'name': 'Bột Mì Làm Bánh',
      'unit': 'KG',
      'minStockLevel': 100,
      'isActive': true,
    },
    {
      'id': 5,
      'name': 'Tỏi Lý Sơn',
      'unit': 'KG',
      'minStockLevel': 15,
      'isActive': true,
    },
    {
      'id': 6,
      'name': 'Khoai Tây Đông Lạnh',
      'unit': 'KG',
      'minStockLevel': 80,
      'isActive': true,
    },
    {
      'id': 7,
      'name': 'Chanh Dây Tươi',
      'unit': 'KG',
      'minStockLevel': 25,
      'isActive': true,
    },
  ];

  static final List<Map<String, dynamic>> _mockProductionPlans = [
    {
      'planId': 301,
      'planName': 'Kế hoạch sản xuất sáng T7',
      'batchCode': 'PLAN-20260714-01',
      'status': 'READY_TO_PRODUCE',
      'createdAt': '2026-07-14T07:00:00Z',
      'items': [
        {
          'productId': 1,
          'productName': 'Steak Bò Mỹ (Premium)',
          'plannedQuantity': 50,
          'unit': 'Đĩa',
        },
        {
          'productId': 2,
          'productName': 'Salad Cá Hồi',
          'plannedQuantity': 30,
          'unit': 'Đĩa',
        },
      ],
    },
    {
      'planId': 302,
      'planName': 'Sản xuất bổ sung cuối tuần',
      'batchCode': 'PLAN-20260714-02',
      'status': 'PRODUCING',
      'createdAt': '2026-07-14T09:00:00Z',
      'items': [
        {
          'productId': 4,
          'productName': 'Pizza Hải Sản',
          'plannedQuantity': 40,
          'unit': 'Cái',
        },
        {
          'productId': 5,
          'productName': 'Bánh Mì Bơ Tỏi',
          'plannedQuantity': 60,
          'unit': 'Cái',
        },
      ],
    },
    {
      'planId': 303,
      'planName': 'Sản xuất trưa ngày 13/7',
      'batchCode': 'PLAN-20260713-01',
      'status': 'COMPLETED',
      'createdAt': '2026-07-13T11:00:00Z',
      'items': [
        {
          'productId': 3,
          'productName': 'Súp Kem Bí Đỏ',
          'plannedQuantity': 25,
          'unit': 'Bát',
        },
        {
          'productId': 6,
          'productName': 'Khoai Tây Chiên Truffle',
          'plannedQuantity': 35,
          'unit': 'Đĩa',
        },
      ],
    },
  ];

  static final List<Map<String, dynamic>> _mockOrders = [
    {
      'orderId': 5001,
      'storeName': 'Chi nhánh Quận 1',
      'storeId': 1,
      'status': 'SUBMITTED',
      'totalAmount': 2350000,
      'orderDate': '2026-07-14T08:00:00Z',
      'items': [
        {'name': 'Steak Bò Mỹ (Premium)', 'quantity': 10},
        {'name': 'Salad Cá Hồi', 'quantity': 5},
      ],
    },
    {
      'orderId': 5002,
      'storeName': 'Chi nhánh Quận 3',
      'storeId': 2,
      'status': 'APPROVED',
      'totalAmount': 4150000,
      'orderDate': '2026-07-13T09:30:00Z',
      'items': [
        {'name': 'Pizza Hải Sản', 'quantity': 15},
        {'name': 'Bánh Mì Bơ Tỏi', 'quantity': 20},
      ],
    },
    {
      'orderId': 5003,
      'storeName': 'Chi nhánh Thủ Đức',
      'storeId': 5,
      'status': 'DELIVERED',
      'totalAmount': 1120000,
      'orderDate': '2026-07-12T10:00:00Z',
      'items': [
        {'name': 'Súp Kem Bí Đỏ', 'quantity': 8},
        {'name': 'Khoai Tây Chiên Truffle', 'quantity': 12},
      ],
    },
    {
      'orderId': 5004,
      'storeName': 'Chi nhánh Quận 7',
      'storeId': 4,
      'status': 'REJECTED',
      'totalAmount': 850000,
      'orderDate': '2026-07-11T11:00:00Z',
      'items': [
        {'name': 'Nước Ép Chanh Dây', 'quantity': 10},
      ],
    },
    {
      'orderId': 5005,
      'storeName': 'Cửa hàng Quận 1',
      'storeId': 1,
      'status': 'APPROVED',
      'totalAmount': 1890000,
      'orderDate': '2026-07-14T09:00:00Z',
      'items': [
        {'name': 'Pizza Hải Sản', 'quantity': 10},
      ],
    },
    {
      'orderId': 5006,
      'storeName': 'Cửa hàng Quận 1',
      'storeId': 1,
      'status': 'APPROVED',
      'totalAmount': 2490000,
      'orderDate': '2026-07-14T09:15:00Z',
      'items': [
        {'name': 'Steak Bò Mỹ (Premium)', 'quantity': 10},
      ],
    },
    {
      'orderId': 5007,
      'storeName': 'Cửa hàng Quận 1',
      'storeId': 1,
      'status': 'DELIVERED',
      'totalAmount': 750000,
      'orderDate': '2026-07-13T10:00:00Z',
      'items': [
        {'name': 'Súp Kem Bí Đỏ', 'quantity': 10},
      ],
    },
  ];

  static final List<Map<String, dynamic>> _mockShipments = [
    {
      'shipmentId': 101,
      'storeId': 3,
      'storeName': 'Chi nhánh Quận 3',
      'status': 'PREPARED',
      'driverName': 'Nguyễn Văn Tài',
      'driverPhone': '0901234567',
      'vehicleInfo': 'Xe Tải - 29C-12345',
      'ahamoveServiceId': 'SGN-TRUCK-500',
      'createdAt': '2026-07-14T08:00:00Z',
      'stops': [
        {
          'stopId': 1,
          'storeId': 3,
          'storeName': 'Chi nhánh Quận 3',
          'storeOrderIds': [5002],
        },
      ],
    },
    {
      'shipmentId': 102,
      'storeId': 2,
      'storeName': 'Chi nhánh Bình Thạnh',
      'status': 'IN_TRANSIT',
      'driverName': 'Trần Văn Xế',
      'driverPhone': '0987654321',
      'vehicleInfo': 'Xe Máy - 59A-99999',
      'ahamoveServiceId': 'SGN-BIKE',
      'createdAt': '2026-07-14T09:30:00Z',
      'stops': [
        {
          'stopId': 2,
          'storeId': 2,
          'storeName': 'Chi nhánh Bình Thạnh',
          'storeOrderIds': [5003],
        },
      ],
    },
    {
      'shipmentId': 103,
      'storeId': 5,
      'storeName': 'Chi nhánh Gò Vấp',
      'status': 'DELIVERED',
      'driverName': 'Lê Văn Giao',
      'driverPhone': '0912345678',
      'vehicleInfo': 'Xe Tải - 29C-54321',
      'ahamoveServiceId': 'SGN-TRUCK-1000',
      'createdAt': '2026-07-13T10:00:00Z',
      'stops': [
        {
          'stopId': 3,
          'storeId': 5,
          'storeName': 'Chi nhánh Gò Vấp',
          'storeOrderIds': [5004],
        },
      ],
    },
    {
      'shipmentId': 104,
      'storeId': 1,
      'storeName': 'Cửa hàng Quận 1',
      'status': 'PENDING',
      'driverName': '',
      'driverPhone': '',
      'vehicleInfo': '',
      'ahamoveServiceId': 'SGN-BIKE',
      'createdAt': '2026-07-14T10:15:00Z',
      'stops': [
        {
          'stopId': 4,
          'storeId': 1,
          'storeName': 'Cửa hàng Quận 1',
          'storeOrderIds': [5001],
        },
      ],
    },
    {
      'shipmentId': 105,
      'storeId': 1,
      'storeName': 'Cửa hàng Quận 1',
      'status': 'PREPARED',
      'driverName': 'Tài Xế AhaMove SGN',
      'driverPhone': '0901234888',
      'vehicleInfo': 'Xe Máy AhaMove',
      'ahamoveServiceId': 'SGN-BIKE',
      'createdAt': '2026-07-14T09:00:00Z',
      'stops': [
        {
          'stopId': 5,
          'storeId': 1,
          'storeName': 'Cửa hàng Quận 1',
          'storeOrderIds': [5005],
        },
      ],
    },
    {
      'shipmentId': 106,
      'storeId': 1,
      'storeName': 'Cửa hàng Quận 1',
      'status': 'IN_TRANSIT',
      'driverName': 'Nguyễn Văn Hùng',
      'driverPhone': '0901234777',
      'vehicleInfo': 'Xe Máy AhaMove - 59A-11111',
      'ahamoveServiceId': 'SGN-BIKE',
      'ahamoveOrderId': 'AHA-KITCHEN-106',
      'ahamoveStatus': 'IN_TRANSIT',
      'createdAt': '2026-07-14T09:15:00Z',
      'stops': [
        {
          'stopId': 6,
          'storeId': 1,
          'storeName': 'Cửa hàng Quận 1',
          'storeOrderIds': [5006],
        },
      ],
    },
    {
      'shipmentId': 107,
      'storeId': 1,
      'storeName': 'Cửa hàng Quận 1',
      'status': 'DELIVERED',
      'driverName': 'Trần Minh Hải',
      'driverPhone': '0909999888',
      'vehicleInfo': 'Xe Tải - 29C-55555',
      'ahamoveServiceId': 'SGN-TRUCK-500',
      'ahamoveOrderId': 'AHA-KITCHEN-107',
      'ahamoveStatus': 'DELIVERED',
      'createdAt': '2026-07-13T10:00:00Z',
      'stops': [
        {
          'stopId': 7,
          'storeId': 1,
          'storeName': 'Cửa hàng Quận 1',
          'storeOrderIds': [5007],
        },
      ],
    },
  ];

  /// Get headers with access token
  static Map<String, String> _getAuthHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${currentUser?.token ?? ""}',
    };
  }

  /// Fetch users (with optional query parameters)
  static Future<List<Map<String, dynamic>>> fetchUsers({String? search}) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        return _mockUsers
            .where(
              (u) =>
                  u['username'].toString().toLowerCase().contains(query) ||
                  u['fullName'].toString().toLowerCase().contains(query) ||
                  u['email'].toString().toLowerCase().contains(query),
            )
            .toList();
      }
      return List.from(_mockUsers);
    }

    try {
      var urlStr = '$_baseUrl/users';
      if (search != null && search.isNotEmpty) {
        urlStr += '?search=${Uri.encodeComponent(search)}';
      }

      final res = await http
          .get(Uri.parse(urlStr), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List content = data['content'] ?? [];
        return content.cast<Map<String, dynamic>>();
      }
      throw Exception(
        "Lấy danh sách người dùng thất bại (Mã lỗi: ${res.statusCode})",
      );
    } catch (e) {
      debugPrint("API fetchUsers failed, using fallback mock users: $e");
      return fetchUsers(search: search);
    }
  }

  /// Create a new user (roleId: 1 for ADMIN, etc.)
  static Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> userData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 500));

      // Map roleName from roleId
      final int roleId = userData['roleId'] ?? 0;
      String roleName = 'STORE_STAFF';
      if (roleId == 1)
        roleName = 'ADMIN';
      else if (roleId == 2)
        roleName = 'MANAGER';
      else if (roleId == 3)
        roleName = 'COORDINATOR';
      else if (roleId == 4)
        roleName = 'KITCHEN_STAFF';
      else if (roleId == 5)
        roleName = 'STORE_STAFF';

      // Generate a mock user response
      final String email = userData['email'] ?? '';
      final String fullName = userData['fullName'] ?? 'Người dùng mới';
      final String username = email.split('@')[0];

      final newUser = {
        'userId': _mockUsers.length + 1,
        'username': username,
        'email': email,
        'fullName': fullName,
        'roleName': roleName,
        'isActive': true,
        'status': 'ACTIVE',
        if (userData['storeId'] != null) 'storeId': userData['storeId'],
        if (userData['storeId'] != null)
          'storeName': 'Chi nhánh #${userData['storeId']}',
        if (userData['kitchenId'] != null) 'kitchenId': userData['kitchenId'],
        if (userData['kitchenId'] != null)
          'kitchenName': 'Bếp #${userData['kitchenId']}',
      };

      _mockUsers.insert(0, newUser); // Add to local mock list (at beginning)
      return {
        'username': username,
        'email': email,
        'fullName': fullName,
        'message': 'Khởi tạo tài khoản thành công! (Chế độ Demo)',
      };
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/users'),
            headers: _getAuthHeaders(),
            body: jsonEncode(userData),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        return body as Map<String, dynamic>;
      } else {
        String errorMsg = "Tạo tài khoản thất bại";
        try {
          final errorBody = jsonDecode(res.body);
          errorMsg = errorBody['message'] ?? errorBody['error'] ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("API createUser failed: $e. Falling back to mock.");
      isOfflineMockMode = true;
      return createUser(userData);
    }
  }

  /// Fetch products list
  static Future<List<Map<String, dynamic>>> fetchProducts({
    String? search,
  }) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (search != null && search.isNotEmpty) {
        final query = search.toLowerCase();
        return _mockProducts
            .where(
              (p) =>
                  p['name'].toString().toLowerCase().contains(query) ||
                  (p['description'] ?? '').toString().toLowerCase().contains(
                    query,
                  ),
            )
            .toList();
      }
      return _mockProducts;
    }

    try {
      var urlStr = '$_baseUrl/products?size=100';
      if (search != null && search.isNotEmpty) {
        urlStr += '&search=${Uri.encodeComponent(search)}';
      }

      final res = await http
          .get(Uri.parse(urlStr), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List content = data['content'] ?? [];
        return content.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách sản phẩm thất bại");
    } catch (e) {
      debugPrint("API fetchProducts failed, using mock data: $e");
      return fetchProducts(search: search);
    }
  }

  /// Fetch billing statements (filtered by status)
  static Future<List<Map<String, dynamic>>> fetchBillingStatements({
    String? status,
  }) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (status != null &&
          status.isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        return _mockBillingStatements
            .where(
              (b) =>
                  b['status'].toString().toUpperCase() == status.toUpperCase(),
            )
            .toList();
      }
      return _mockBillingStatements;
    }

    try {
      var urlStr = '$_baseUrl/billing-statements?size=100&page=0';
      if (status != null &&
          status.isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        urlStr += '&status=${status.toUpperCase()}';
      }

      final res = await http
          .get(Uri.parse(urlStr), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List content = data['content'] ?? [];
        return content.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách hóa đơn thất bại");
    } catch (e) {
      debugPrint("API fetchBillingStatements failed, using mock data: $e");
      return fetchBillingStatements(status: status);
    }
  }

  /// Fetch roles dropdown (Admin creates user)
  static Future<List<Map<String, dynamic>>> fetchRoles() async {
    if (isOfflineMockMode || currentUser == null) {
      return [
        {'roleId': 1, 'roleName': 'ROLE_ADMIN'},
        {'roleId': 2, 'roleName': 'ROLE_MANAGER'},
        {'roleId': 3, 'roleName': 'ROLE_COORDINATOR'},
        {'roleId': 4, 'roleName': 'ROLE_KITCHEN_STAFF'},
        {'roleId': 5, 'roleName': 'ROLE_STORE_STAFF'},
      ];
    }

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/roles'), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách vai trò thất bại");
    } catch (_) {
      return [
        {'roleId': 1, 'roleName': 'ROLE_ADMIN'},
        {'roleId': 2, 'roleName': 'ROLE_MANAGER'},
        {'roleId': 3, 'roleName': 'ROLE_COORDINATOR'},
        {'roleId': 4, 'roleName': 'ROLE_KITCHEN_STAFF'},
        {'roleId': 5, 'roleName': 'ROLE_STORE_STAFF'},
      ];
    }
  }

  /// Fetch stores list dropdown
  static Future<List<Map<String, dynamic>>> fetchStores() async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      return List.from(_mockStoresList);
    }

    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/stores?size=100'),
            headers: _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List content = data['content'] ?? [];
        return content.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách cửa hàng thất bại");
    } catch (_) {
      return List.from(_mockStoresList);
    }
  }

  /// Fetch kitchens list dropdown
  static Future<List<Map<String, dynamic>>> fetchKitchens() async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      return List.from(_mockKitchensList);
    }

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/kitchens'), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách bếp thất bại");
    } catch (_) {
      return List.from(_mockKitchensList);
    }
  }

  // --- New COORDINATOR APIs ---

  /// Fetch all system orders list
  static Future<List<Map<String, dynamic>>> fetchOrdersList({
    String? status,
  }) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (status != null &&
          status.isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        return _mockOrders
            .where(
              (o) =>
                  o['status'].toString().toUpperCase() == status.toUpperCase(),
            )
            .toList();
      }
      return List.from(_mockOrders);
    }

    try {
      var urlStr = '$_baseUrl/orders?size=100&page=0';
      if (status != null &&
          status.isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        urlStr += '&status=${status.toUpperCase()}';
      }

      final res = await http
          .get(Uri.parse(urlStr), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List content = body['content'] ?? [];
        return content.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách đơn hàng thất bại");
    } catch (e) {
      debugPrint("API fetchOrdersList failed, using mock data: $e");
      return fetchOrdersList(status: status);
    }
  }

  /// Update order status (Duyệt / Từ chối)
  static Future<bool> updateOrderStatus(int orderId, String status) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      final index = _mockOrders.indexWhere((o) => o['orderId'] == orderId);
      if (index != -1) {
        _mockOrders[index]['status'] = status.toUpperCase();
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/orders/$orderId/status'),
            headers: _getAuthHeaders(),
            body: jsonEncode({'status': status.toUpperCase()}),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API updateOrderStatus failed: $e. Updating local mock.");
      final index = _mockOrders.indexWhere((o) => o['orderId'] == orderId);
      if (index != -1) {
        _mockOrders[index]['status'] = status.toUpperCase();
        return true;
      }
      return false;
    }
  }

  /// Fetch shipments list
  static Future<List<Map<String, dynamic>>> fetchShipmentsList({
    String? status,
  }) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (status != null &&
          status.isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        return _mockShipments
            .where(
              (s) =>
                  s['status'].toString().toUpperCase() == status.toUpperCase(),
            )
            .toList();
      }
      return List.from(_mockShipments);
    }

    try {
      var urlStr = '$_baseUrl/shipments?size=100&page=0';
      if (status != null &&
          status.isNotEmpty &&
          status.toUpperCase() != 'ALL') {
        urlStr += '&status=${status.toUpperCase()}';
      }

      final res = await http
          .get(Uri.parse(urlStr), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List content = data['content'] ?? [];
        return content.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách chuyến xe thất bại");
    } catch (e) {
      debugPrint("API fetchShipmentsList failed, using mock data: $e");
      return fetchShipmentsList(status: status);
    }
  }

  /// Create a new shipment
  static Future<Map<String, dynamic>> createShipment(
    Map<String, dynamic> shipmentData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 500));

      final int storeId = shipmentData['storeId'] ?? 1;
      final List orderIds = shipmentData['storeOrderIds'] ?? [];

      // Update linked orders to ALLOCATED (or approved)
      for (final orderId in orderIds) {
        final idx = _mockOrders.indexWhere((o) => o['orderId'] == orderId);
        if (idx != -1) {
          _mockOrders[idx]['status'] = 'ALLOCATED';
        }
      }

      final newShipment = {
        'shipmentId': _mockShipments.length + 101,
        'storeId': storeId,
        'storeName': shipmentData['storeName'] ?? 'Cửa hàng liên kết',
        'status': 'PENDING',
        'driverName': shipmentData['driverName'] ?? 'Chưa gán',
        'driverPhone': shipmentData['driverPhone'] ?? 'Chưa gán',
        'vehicleInfo': shipmentData['vehicleInfo'] ?? 'Chưa gán',
        'ahamoveServiceId': shipmentData['ahamoveServiceId'] ?? 'SGN-BIKE',
        'createdAt': DateTime.now().toIso8601String(),
        'stops': [
          {
            'stopId': _mockShipments.length + 1,
            'storeId': storeId,
            'storeName': shipmentData['storeName'] ?? 'Cửa hàng liên kết',
            'storeOrderIds': orderIds,
          },
        ],
      };

      _mockShipments.insert(0, newShipment);
      return newShipment;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/shipments'),
            headers: _getAuthHeaders(),
            body: jsonEncode(shipmentData),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        return body as Map<String, dynamic>;
      } else {
        String errorMsg = "Tạo chuyến xe thất bại";
        try {
          final errorBody = jsonDecode(res.body);
          errorMsg = errorBody['message'] ?? errorBody['error'] ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("API createShipment failed: $e. Falling back to mock.");
      isOfflineMockMode = true;
      return createShipment(shipmentData);
    }
  }

  /// Start shipment transit (Xuất kho -> Đang giao)
  static Future<bool> startShipmentTransit(int shipmentId) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      final index = _mockShipments.indexWhere(
        (s) => s['shipmentId'] == shipmentId,
      );
      if (index != -1) {
        _mockShipments[index]['status'] = 'IN_TRANSIT';
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/shipments/$shipmentId/transit'),
            headers: _getAuthHeaders(),
            body: null,
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API startShipmentTransit failed: $e. Falling back to mock.");
      final index = _mockShipments.indexWhere(
        (s) => s['shipmentId'] == shipmentId,
      );
      if (index != -1) {
        _mockShipments[index]['status'] = 'IN_TRANSIT';
        return true;
      }
      return false;
    }
  }

  // --- Mock helper methods ---

  static Map<String, dynamic> _getMockStatsForRole(String role) {
    switch (role) {
      case 'ADMIN':
        return {'activeStores': 12, 'activeUsers': 45};
      case 'COORDINATOR':
        return {'pendingOrders': 8, 'pendingShipments': 4, 'activeStores': 12};
      case 'KITCHEN_STAFF':
        return {'productionPlans': 3, 'pendingShipments': 5};
      case 'STORE_STAFF':
      case 'MANAGER':
        return {'pendingOrders': 6};
      default:
        return {};
    }
  }

  /// Update central kitchen details
  static Future<bool> updateKitchen(
    int kitchenId,
    Map<String, dynamic> kitchenData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _mockKitchensList.indexWhere(
        (k) => k['kitchenId'] == kitchenId,
      );
      if (index != -1) {
        _mockKitchensList[index]['kitchenName'] =
            kitchenData['name'] ?? _mockKitchensList[index]['kitchenName'];
        _mockKitchensList[index]['address'] =
            kitchenData['address'] ?? _mockKitchensList[index]['address'];
        _mockKitchensList[index]['maxDailyCapacity'] =
            kitchenData['maxDailyCapacity'] ??
            _mockKitchensList[index]['maxDailyCapacity'];
        _mockKitchensList[index]['isActive'] =
            kitchenData['isActive'] ?? _mockKitchensList[index]['isActive'];
        _mockKitchensList[index]['latitude'] =
            kitchenData['latitude'] ?? _mockKitchensList[index]['latitude'];
        _mockKitchensList[index]['longitude'] =
            kitchenData['longitude'] ?? _mockKitchensList[index]['longitude'];
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/kitchens/$kitchenId'),
            headers: _getAuthHeaders(),
            body: jsonEncode(kitchenData),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API updateKitchen failed: $e. Falling back to mock.");
      final index = _mockKitchensList.indexWhere(
        (k) => k['kitchenId'] == kitchenId,
      );
      if (index != -1) {
        _mockKitchensList[index]['kitchenName'] = kitchenData['name'];
        _mockKitchensList[index]['address'] = kitchenData['address'];
        _mockKitchensList[index]['maxDailyCapacity'] =
            kitchenData['maxDailyCapacity'];
        _mockKitchensList[index]['isActive'] = kitchenData['isActive'];
        _mockKitchensList[index]['latitude'] = kitchenData['latitude'];
        _mockKitchensList[index]['longitude'] = kitchenData['longitude'];
        return true;
      }
      return false;
    }
  }

  /// Create a new franchise store
  static Future<Map<String, dynamic>> createStore(
    Map<String, dynamic> storeData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final newId = _mockStoresList.length + 1;
      final newStore = {
        'id': newId,
        'storeId': newId,
        'name': storeData['name'],
        'address': storeData['address'],
        'phone': storeData['phone'] ?? '',
        'email': storeData['email'] ?? '',
        'isActive': storeData['isActive'] ?? true,
        'paymentCycle': storeData['paymentCycle'] ?? 'MONTHLY',
        'latitude': storeData['latitude'],
        'longitude': storeData['longitude'],
      };
      _mockStoresList.add(newStore);
      return newStore;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/stores'),
            headers: _getAuthHeaders(),
            body: jsonEncode(storeData),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        return body as Map<String, dynamic>;
      } else {
        throw Exception("Không thể tạo cửa hàng");
      }
    } catch (e) {
      debugPrint("API createStore failed: $e. Falling back to mock.");
      isOfflineMockMode = true;
      return createStore(storeData);
    }
  }

  /// Update franchise store
  static Future<bool> updateStore(
    int storeId,
    Map<String, dynamic> storeData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _mockStoresList.indexWhere(
        (s) => s['id'] == storeId || s['storeId'] == storeId,
      );
      if (index != -1) {
        _mockStoresList[index]['name'] =
            storeData['name'] ?? _mockStoresList[index]['name'];
        _mockStoresList[index]['address'] =
            storeData['address'] ?? _mockStoresList[index]['address'];
        _mockStoresList[index]['phone'] =
            storeData['phone'] ?? _mockStoresList[index]['phone'];
        _mockStoresList[index]['email'] =
            storeData['email'] ?? _mockStoresList[index]['email'];
        _mockStoresList[index]['isActive'] =
            storeData['isActive'] ?? _mockStoresList[index]['isActive'];
        _mockStoresList[index]['paymentCycle'] =
            storeData['paymentCycle'] ?? _mockStoresList[index]['paymentCycle'];
        _mockStoresList[index]['latitude'] =
            storeData['latitude'] ?? _mockStoresList[index]['latitude'];
        _mockStoresList[index]['longitude'] =
            storeData['longitude'] ?? _mockStoresList[index]['longitude'];
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .put(
            Uri.parse('$_baseUrl/stores/$storeId'),
            headers: _getAuthHeaders(),
            body: jsonEncode(storeData),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API updateStore failed: $e. Falling back to mock.");
      final index = _mockStoresList.indexWhere(
        (s) => s['id'] == storeId || s['storeId'] == storeId,
      );
      if (index != -1) {
        _mockStoresList[index]['name'] = storeData['name'];
        _mockStoresList[index]['address'] = storeData['address'];
        _mockStoresList[index]['phone'] = storeData['phone'];
        _mockStoresList[index]['email'] = storeData['email'];
        _mockStoresList[index]['isActive'] = storeData['isActive'];
        _mockStoresList[index]['paymentCycle'] = storeData['paymentCycle'];
        _mockStoresList[index]['latitude'] = storeData['latitude'];
        _mockStoresList[index]['longitude'] = storeData['longitude'];
        return true;
      }
      return false;
    }
  }

  /// Generate batch billing statements
  static Future<Map<String, dynamic>> generateBatchBilling(
    Map<String, dynamic> batchData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 800));

      final cycle = batchData['cycleName'] ?? 'Chu kỳ T7/2026';
      int count = 0;
      for (final s in _mockStoresList) {
        final existingIdx = _mockBillingStatements.indexWhere(
          (b) => b['storeId'] == s['id'] && b['cycleName'] == cycle,
        );
        if (existingIdx == -1) {
          final newInvoiceId = _mockBillingStatements.length + 2001;
          _mockBillingStatements.add({
            'statementId': newInvoiceId,
            'storeName': s['name'],
            'storeId': s['id'],
            'cycleName': cycle,
            'totalAmount': (120 + s['id'] * 35) * 100000,
            'status': 'ISSUED',
            'issuedAt': DateTime.now().toIso8601String(),
          });
          count++;
        }
      }

      return {
        'processedStoresCount': _mockStoresList.length,
        'generatedStatementsCount': count,
        'skippedStoresCount': _mockStoresList.length - count,
        'cycleName': cycle,
        'status': 'SUCCESS',
      };
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/billing-statements/generate/batch'),
            headers: _getAuthHeaders(),
            body: jsonEncode(batchData),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        throw Exception("Xuất hóa đơn hàng loạt thất bại");
      }
    } catch (e) {
      debugPrint("API generateBatchBilling failed: $e. Falling back to mock.");
      isOfflineMockMode = true;
      return generateBatchBilling(batchData);
    }
  }

  /// Update single billing statement status
  static Future<bool> updateBillingStatementStatus(
    int statementId,
    String status,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockBillingStatements.indexWhere(
        (b) => b['statementId'] == statementId,
      );
      if (idx != -1) {
        _mockBillingStatements[idx]['status'] = status.toUpperCase();
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/billing-statements/$statementId/pay'),
            headers: _getAuthHeaders(),
            body: jsonEncode({
              'paymentMethodId': 1,
              'transactionReference':
                  'MOB-${DateTime.now().millisecondsSinceEpoch}',
              'note':
                  'Paid via mobile app status update to ${status.toUpperCase()}',
            }),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint(
        "API updateBillingStatementStatus failed: $e. Falling back to mock.",
      );
      final idx = _mockBillingStatements.indexWhere(
        (b) => b['statementId'] == statementId,
      );
      if (idx != -1) {
        _mockBillingStatements[idx]['status'] = status.toUpperCase();
        return true;
      }
      return false;
    }
  }

  // --- New MANAGER APIs ---

  /// Create a new product
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> productData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final newId = _mockProducts.length + 1;

      final category = _mockCategoriesList.firstWhere(
        (c) => c['id'] == productData['categoryId'],
        orElse: () => {'id': 1, 'name': 'Danh mục mẫu'},
      );

      final newProduct = {
        'id': newId,
        'name': productData['name'],
        'description': productData['description'] ?? '',
        'price': productData['price'] ?? 0,
        'unit': productData['unit'] ?? 'Đĩa',
        'category': {
          'id': category['id'],
          'name': category['name'],
          'description': category['description'] ?? '',
        },
        'isActive': true,
      };

      _mockProducts.add(newProduct);
      return newProduct;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/products'),
            headers: _getAuthHeaders(),
            body: jsonEncode(productData),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        return body as Map<String, dynamic>;
      } else {
        throw Exception("Không thể tạo sản phẩm");
      }
    } catch (e) {
      debugPrint("API createProduct failed: $e. Falling back to mock.");
      isOfflineMockMode = true;
      return createProduct(productData);
    }
  }

  /// Update an existing product
  static Future<bool> updateProduct(
    int productId,
    Map<String, dynamic> productData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _mockProducts.indexWhere((p) => p['id'] == productId);
      if (index != -1) {
        final category = _mockCategoriesList.firstWhere(
          (c) => c['id'] == productData['categoryId'],
          orElse: () => _mockProducts[index]['category'],
        );

        _mockProducts[index]['name'] =
            productData['name'] ?? _mockProducts[index]['name'];
        _mockProducts[index]['description'] =
            productData['description'] ?? _mockProducts[index]['description'];
        _mockProducts[index]['price'] =
            productData['price'] ?? _mockProducts[index]['price'];
        _mockProducts[index]['unit'] =
            productData['unit'] ?? _mockProducts[index]['unit'];
        _mockProducts[index]['category'] = {
          'id': category['id'],
          'name': category['name'],
          'description': category['description'] ?? '',
        };
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/products/$productId'),
            headers: _getAuthHeaders(),
            body: jsonEncode(productData),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API updateProduct failed: $e. Falling back to mock.");
      final index = _mockProducts.indexWhere((p) => p['id'] == productId);
      if (index != -1) {
        _mockProducts[index]['name'] = productData['name'];
        _mockProducts[index]['description'] = productData['description'];
        _mockProducts[index]['price'] = productData['price'];
        _mockProducts[index]['unit'] = productData['unit'];
        return true;
      }
      return false;
    }
  }

  /// Fetch materials/ingredients list
  static Future<List<Map<String, dynamic>>> fetchMaterials() async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      return List.from(_mockMaterialsList);
    }

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/materials'), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách nguyên liệu thất bại");
    } catch (e) {
      debugPrint("API fetchMaterials failed, using mock data: $e");
      return List.from(_mockMaterialsList);
    }
  }

  /// Create a new material
  static Future<Map<String, dynamic>> createMaterial(
    Map<String, dynamic> materialData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final newId = _mockMaterialsList.length + 1;
      final newMaterial = {
        'id': newId,
        'name': materialData['name'],
        'unit': materialData['unit'] ?? 'KG',
        'minStockLevel': 10,
        'isActive': true,
      };
      _mockMaterialsList.add(newMaterial);
      return newMaterial;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/materials'),
            headers: _getAuthHeaders(),
            body: jsonEncode(materialData),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        return body as Map<String, dynamic>;
      } else {
        throw Exception("Không thể tạo nguyên liệu");
      }
    } catch (e) {
      debugPrint("API createMaterial failed: $e. Falling back to mock.");
      isOfflineMockMode = true;
      return createMaterial(materialData);
    }
  }

  /// Update a material
  static Future<bool> updateMaterial(
    int materialId,
    Map<String, dynamic> materialData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _mockMaterialsList.indexWhere((m) => m['id'] == materialId);
      if (index != -1) {
        _mockMaterialsList[index]['name'] =
            materialData['name'] ?? _mockMaterialsList[index]['name'];
        _mockMaterialsList[index]['unit'] =
            materialData['unit'] ?? _mockMaterialsList[index]['unit'];
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/materials/$materialId'),
            headers: _getAuthHeaders(),
            body: jsonEncode(materialData),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API updateMaterial failed: $e. Falling back to mock.");
      final index = _mockMaterialsList.indexWhere((m) => m['id'] == materialId);
      if (index != -1) {
        _mockMaterialsList[index]['name'] = materialData['name'];
        _mockMaterialsList[index]['unit'] = materialData['unit'];
        return true;
      }
      return false;
    }
  }

  /// Fetch categories list
  static Future<List<Map<String, dynamic>>> fetchCategories() async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      return List.from(_mockCategoriesList);
    }

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/categories'), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        return list.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách danh mục thất bại");
    } catch (e) {
      debugPrint("API fetchCategories failed, using mock data: $e");
      return List.from(_mockCategoriesList);
    }
  }

  /// Create a new category
  static Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> categoryData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final newId = _mockCategoriesList.length + 1;
      final newCategory = {
        'id': newId,
        'name': categoryData['name'],
        'description': categoryData['description'] ?? '',
        'status': 'ACTIVE',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      _mockCategoriesList.add(newCategory);
      return newCategory;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/categories'),
            headers: _getAuthHeaders(),
            body: jsonEncode(categoryData),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        return body as Map<String, dynamic>;
      } else {
        throw Exception("Không thể tạo danh mục");
      }
    } catch (e) {
      debugPrint("API createCategory failed: $e. Falling back to mock.");
      isOfflineMockMode = true;
      return createCategory(categoryData);
    }
  }

  /// Update category details
  static Future<bool> updateCategory(
    int categoryId,
    Map<String, dynamic> categoryData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final index = _mockCategoriesList.indexWhere(
        (c) => c['id'] == categoryId,
      );
      if (index != -1) {
        _mockCategoriesList[index]['name'] =
            categoryData['name'] ?? _mockCategoriesList[index]['name'];
        _mockCategoriesList[index]['description'] =
            categoryData['description'] ??
            _mockCategoriesList[index]['description'];
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/categories/$categoryId'),
            headers: _getAuthHeaders(),
            body: jsonEncode(categoryData),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API updateCategory failed: $e. Falling back to mock.");
      final index = _mockCategoriesList.indexWhere(
        (c) => c['id'] == categoryId,
      );
      if (index != -1) {
        _mockCategoriesList[index]['name'] = categoryData['name'];
        _mockCategoriesList[index]['description'] = categoryData['description'];
        return true;
      }
      return false;
    }
  }

  // --- KITCHEN STAFF APIs ---

  /// Fetch production plans assigned to the kitchen
  static Future<List<Map<String, dynamic>>> fetchProductionPlans() async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      return List.from(_mockProductionPlans);
    }

    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/production-plans'),
            headers: _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List content = body['content'] ?? body;
        return content.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách lệnh sản xuất thất bại");
    } catch (e) {
      debugPrint("API fetchProductionPlans failed: $e. Falling back to mock.");
      return List.from(_mockProductionPlans);
    }
  }

  /// Start production plan
  static Future<bool> startProductionPlan(int planId) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockProductionPlans.indexWhere((p) => p['planId'] == planId);
      if (idx != -1) {
        _mockProductionPlans[idx]['status'] = 'PRODUCING';
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/production-plans/$planId/start'),
            headers: _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API startProductionPlan failed: $e. Falling back to mock.");
      final idx = _mockProductionPlans.indexWhere((p) => p['planId'] == planId);
      if (idx != -1) {
        _mockProductionPlans[idx]['status'] = 'PRODUCING';
        return true;
      }
      return false;
    }
  }

  /// Finish/yield production plan
  static Future<bool> finishProductionPlan(
    int planId, {
    List<Map<String, dynamic>>? outputs,
  }) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockProductionPlans.indexWhere((p) => p['planId'] == planId);
      if (idx != -1) {
        _mockProductionPlans[idx]['status'] = 'COMPLETED';
        return true;
      }
      return false;
    }

    try {
      final payload = outputs != null ? {'outputs': outputs} : {};
      final res = await http
          .post(
            Uri.parse('$_baseUrl/production-plans/$planId/yield'),
            headers: _getAuthHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API finishProductionPlan failed: $e. Falling back to mock.");
      final idx = _mockProductionPlans.indexWhere((p) => p['planId'] == planId);
      if (idx != -1) {
        _mockProductionPlans[idx]['status'] = 'COMPLETED';
        return true;
      }
      return false;
    }
  }

  /// Fetch shipments / delivery schedules
  static Future<List<Map<String, dynamic>>> fetchShipments() async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 200));
      return List.from(_mockShipments);
    }

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/shipments'), headers: _getAuthHeaders())
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List content = body['content'] ?? body;
        return content.cast<Map<String, dynamic>>();
      }
      throw Exception("Lấy danh sách chuyến giao hàng thất bại");
    } catch (e) {
      debugPrint("API fetchShipments failed: $e. Falling back to mock.");
      return List.from(_mockShipments);
    }
  }

  /// Confirm shipment prepared (ready)
  static Future<bool> prepareShipment(int shipmentId) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockShipments.indexWhere(
        (s) => s['shipmentId'] == shipmentId,
      );
      if (idx != -1) {
        _mockShipments[idx]['status'] = 'PREPARED';
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/shipments/$shipmentId/prepare'),
            headers: _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API prepareShipment failed: $e. Falling back to mock.");
      final idx = _mockShipments.indexWhere(
        (s) => s['shipmentId'] == shipmentId,
      );
      if (idx != -1) {
        _mockShipments[idx]['status'] = 'PREPARED';
        return true;
      }
      return false;
    }
  }

  /// Confirm shipment in transit (ship with Ahamove)
  static Future<bool> startTransit(int shipmentId) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      final idx = _mockShipments.indexWhere(
        (s) => s['shipmentId'] == shipmentId,
      );
      if (idx != -1) {
        _mockShipments[idx]['status'] = 'IN_TRANSIT';
        _mockShipments[idx]['driverName'] = 'Tài xế Ahamove';
        _mockShipments[idx]['driverPhone'] = '0909000888';
        _mockShipments[idx]['vehicleInfo'] = 'Xe Máy (Ahamove SGN-BIKE)';
        _mockShipments[idx]['ahamoveOrderId'] = 'AHA-KITCHEN-${shipmentId}';
        _mockShipments[idx]['ahamoveStatus'] = 'ASSIGNING';
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/shipments/$shipmentId/transit'),
            headers: _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API startTransit failed: $e. Falling back to mock.");
      final idx = _mockShipments.indexWhere(
        (s) => s['shipmentId'] == shipmentId,
      );
      if (idx != -1) {
        _mockShipments[idx]['status'] = 'IN_TRANSIT';
        _mockShipments[idx]['driverName'] = 'Tài xế Ahamove';
        _mockShipments[idx]['driverPhone'] = '0909000888';
        _mockShipments[idx]['vehicleInfo'] = 'Xe Máy (Ahamove SGN-BIKE)';
        _mockShipments[idx]['ahamoveOrderId'] = 'AHA-KITCHEN-${shipmentId}';
        _mockShipments[idx]['ahamoveStatus'] = 'ASSIGNING';
      }
      return false;
    }
  }

  // --- STORE STAFF APIs ---

  /// Create a new Store Order (initial status is DRAFT)
  static Future<Map<String, dynamic>> createStoreOrder(
    Map<String, dynamic> orderData,
  ) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final newOrderId = _mockOrders.length + 5001;
      final List itemsPayload = orderData['items'] ?? [];
      final List<Map<String, dynamic>> itemsList = [];
      int total = 0;

      for (var it in itemsPayload) {
        final prod = _mockProducts.firstWhere(
          (p) => p['id'] == it['productId'],
          orElse: () => {},
        );
        if (prod.isNotEmpty) {
          final price = prod['price'] ?? 0;
          final name = prod['name'] ?? 'Món';
          final qty = it['quantity'] ?? 1;
          total += (price * qty) as int;
          itemsList.add({'name': name, 'quantity': qty});
        }
      }

      final newOrder = {
        'orderId': newOrderId,
        'storeId': orderData['storeId'] ?? currentUser?.storeId ?? 1,
        'storeName': currentUser?.storeName ?? 'Cửa hàng của tôi',
        'status': 'DRAFT',
        'totalAmount': total,
        'orderDate': DateTime.now().toIso8601String(),
        'items': itemsList,
      };

      _mockOrders.add(newOrder);
      return newOrder;
    }

    try {
      final payload = {
        'items': orderData['items'],
        'deliveryDate':
            orderData['deliveryDate'] ??
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      };
      final res = await http
          .post(
            Uri.parse('$_baseUrl/orders'),
            headers: _getAuthHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body);
        return body as Map<String, dynamic>;
      } else {
        throw Exception("Không thể tạo đơn hàng nhượng quyền");
      }
    } catch (e) {
      debugPrint("API createStoreOrder failed: $e. Falling back to mock.");
      isOfflineMockMode = true;
      return createStoreOrder(orderData);
    }
  }

  /// Submit a draft order to the Central Kitchen (status DRAFT -> SUBMITTED)
  static Future<bool> submitStoreOrder(int orderId) async {
    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      final idx = _mockOrders.indexWhere((o) => o['orderId'] == orderId);
      if (idx != -1) {
        _mockOrders[idx]['status'] = 'SUBMITTED';
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse('$_baseUrl/orders/$orderId/submit'),
            headers: _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint("API submitStoreOrder failed: $e. Falling back to mock.");
      final idx = _mockOrders.indexWhere((o) => o['orderId'] == orderId);
      if (idx != -1) {
        _mockOrders[idx]['status'] = 'SUBMITTED';
        return true;
      }
      return false;
    }
  }

  /// Confirm shipment delivery receipt by the store (transitions status to DELIVERED)
  static Future<bool> confirmShipmentDelivery(
    int shipmentId, {
    int? stopId,
  }) async {
    int finalStopId = stopId ?? 0;

    // Resolve stopId internally if not provided and in online mode
    if (finalStopId == 0 && !isOfflineMockMode && currentUser != null) {
      try {
        final res = await http.get(
          Uri.parse('$_baseUrl/shipments/$shipmentId'),
          headers: _getAuthHeaders(),
        );
        if (res.statusCode == 200) {
          final shipment = jsonDecode(res.body);
          final List stops = shipment['stops'] ?? [];
          final userStop = stops.firstWhere(
            (stop) => stop['storeId'] == currentUser?.storeId,
            orElse: () => null,
          );
          if (userStop != null) {
            finalStopId = userStop['stopId'] ?? 0;
          }
        }
      } catch (e) {
        debugPrint("Error fetching shipment to resolve stopId: $e");
      }
    }

    if (isOfflineMockMode || currentUser == null) {
      await Future.delayed(const Duration(milliseconds: 400));
      final sIdx = _mockShipments.indexWhere(
        (s) => s['shipmentId'] == shipmentId,
      );
      if (sIdx != -1) {
        _mockShipments[sIdx]['status'] = 'DELIVERED';
        _mockShipments[sIdx]['deliveredAt'] = DateTime.now().toIso8601String();
        _mockShipments[sIdx]['ahamoveStatus'] = 'DELIVERED';

        // Update all related orders to DELIVERED for the matching stop
        final List stopsList = _mockShipments[sIdx]['stops'] ?? [];
        var targetStops = stopsList;
        if (finalStopId != 0) {
          targetStops = stopsList
              .where((stop) => stop['stopId'] == finalStopId)
              .toList();
        } else if (currentUser?.storeId != null) {
          targetStops = stopsList
              .where((stop) => stop['storeId'] == currentUser?.storeId)
              .toList();
        }

        for (var stop in targetStops) {
          final List orderIds = stop['storeOrderIds'] ?? [];
          for (var oId in orderIds) {
            final oIdx = _mockOrders.indexWhere((o) => o['orderId'] == oId);
            if (oIdx != -1) {
              _mockOrders[oIdx]['status'] = 'DELIVERED';
            }
          }
        }
        return true;
      }
      return false;
    }

    try {
      final res = await http
          .patch(
            Uri.parse(
              '$_baseUrl/shipments/$shipmentId/stops/$finalStopId/confirm',
            ),
            headers: _getAuthHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200 || res.statusCode == 204;
    } catch (e) {
      debugPrint(
        "API confirmShipmentDelivery failed: $e. Falling back to mock.",
      );
      final sIdx = _mockShipments.indexWhere(
        (s) => s['shipmentId'] == shipmentId,
      );
      if (sIdx != -1) {
        _mockShipments[sIdx]['status'] = 'DELIVERED';
        _mockShipments[sIdx]['deliveredAt'] = DateTime.now().toIso8601String();
        _mockShipments[sIdx]['ahamoveStatus'] = 'DELIVERED';

        final List stopsList = _mockShipments[sIdx]['stops'] ?? [];
        var targetStops = stopsList;
        if (finalStopId != 0) {
          targetStops = stopsList
              .where((stop) => stop['stopId'] == finalStopId)
              .toList();
        } else if (currentUser?.storeId != null) {
          targetStops = stopsList
              .where((stop) => stop['storeId'] == currentUser?.storeId)
              .toList();
        }

        for (var stop in targetStops) {
          final List orderIds = stop['storeOrderIds'] ?? [];
          for (var oId in orderIds) {
            final oIdx = _mockOrders.indexWhere((o) => o['orderId'] == oId);
            if (oIdx != -1) {
              _mockOrders[oIdx]['status'] = 'DELIVERED';
            }
          }
        }
        return true;
      }
      return false;
    }
  }

  static Map<String, dynamic> _fillMissingStats(
    Map<String, dynamic> stats,
    String role,
  ) {
    final mock = _getMockStatsForRole(role);
    mock.forEach((key, value) {
      stats.putIfAbsent(key, () => value);
    });
    return stats;
  }

  static List<Map<String, dynamic>> _getMockActivitiesForRole(String role) {
    if (role == 'KITCHEN_STAFF') {
      return _mockShipments
          .map<Map<String, dynamic>>(
            (s) => {
              'type': 'SHIPMENT',
              'id': s['shipmentId'],
              'title': 'Chuyến xe: TRK-${s['shipmentId']}',
              'subtitle': s['storeName'] ?? 'Cửa hàng',
              'status': s['status'] ?? 'PENDING',
            },
          )
          .toList();
    } else {
      return _mockOrders
          .map<Map<String, dynamic>>(
            (o) => {
              'type': 'ORDER',
              'id': o['orderId'],
              'title': 'Mã ĐH: #${o['orderId']}',
              'subtitle': o['storeName'] ?? 'Cửa hàng',
              'status': o['status'] ?? 'PENDING',
            },
          )
          .toList();
    }
  }
}
