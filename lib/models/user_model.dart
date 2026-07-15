class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String token;
  final int? storeId;
  final String? storeName;
  final int? kitchenId;
  final String? kitchenName;
  final List<String> authorities;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    this.storeId,
    this.storeName,
    this.kitchenId,
    this.kitchenName,
    required this.authorities,
  });

  /// Factory constructor to parse user model from LoginResponse and decoded JWT token details.
  factory UserModel.fromResponse({
    required Map<String, dynamic> responseData,
    required Map<String, dynamic> decodedJwt,
    required String token,
  }) {
    // Determine the role
    String userRole = '';
    if (decodedJwt['roles'] != null && decodedJwt['roles'] is List && (decodedJwt['roles'] as List).isNotEmpty) {
      userRole = decodedJwt['roles'][0].toString();
    } else if (responseData['roleName'] != null) {
      userRole = responseData['roleName'].toString();
    } else if (responseData['roles'] != null && responseData['roles'] is List && (responseData['roles'] as List).isNotEmpty) {
      userRole = responseData['roles'][0].toString();
    }

    // Clean up role prefix if any (e.g. ROLE_ADMIN -> ADMIN)
    final roleClean = userRole.toUpperCase().replaceAll('ROLE_', '');

    // Extract store and kitchen info
    final storeIdVal = decodedJwt['storeId'] ?? responseData['storeId'];
    int? storeId;
    if (storeIdVal != null) {
      storeId = int.tryParse(storeIdVal.toString());
    }

    final storeName = responseData['storeName'] ?? (storeId != null ? 'Cửa hàng $storeId' : null);

    final kitchenIdVal = decodedJwt['coordinatorId'] ?? responseData['kitchenId'];
    int? kitchenId;
    if (kitchenIdVal != null) {
      kitchenId = int.tryParse(kitchenIdVal.toString());
    }
    
    final kitchenName = responseData['kitchenName'];

    // Extract authorities/privileges
    final List<String> authoritiesList = [];
    if (decodedJwt['roles'] != null && decodedJwt['roles'] is List) {
      authoritiesList.addAll((decodedJwt['roles'] as List).map((e) => e.toString()));
    }
    if (responseData['authorities'] != null && responseData['authorities'] is List) {
      authoritiesList.addAll((responseData['authorities'] as List).map((e) => e.toString()));
    }
    if (responseData['privileges'] != null && responseData['privileges'] is List) {
      authoritiesList.addAll((responseData['privileges'] as List).map((e) => e.toString()));
    }

    return UserModel(
      id: (responseData['id'] ?? responseData['userId'] ?? decodedJwt['userId'] ?? 'default-user-id').toString(),
      name: responseData['fullName'] ?? responseData['username'] ?? 'User',
      email: responseData['email'] ?? '',
      role: roleClean,
      token: token,
      storeId: storeId,
      storeName: storeName,
      kitchenId: kitchenId,
      kitchenName: kitchenName,
      authorities: authoritiesList.toSet().toList(), // Deduplicate
    );
  }

  /// Get role in Vietnamese for displaying on UI
  String get vietnameseRole {
    switch (role) {
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
        return role;
    }
  }
}
