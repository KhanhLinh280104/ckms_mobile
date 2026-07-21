import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/api_service.dart';

class GoongMapViewWidget extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String title;
  final String address;
  final bool showSearch;
  final double height;

  const GoongMapViewWidget({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.title,
    required this.address,
    this.showSearch = true,
    this.height = 300,
  });

  @override
  State<GoongMapViewWidget> createState() => _GoongMapViewWidgetState();
}

class _GoongMapViewWidgetState extends State<GoongMapViewWidget> {
  late MapController _mapController;
  late LatLng _currentCenter;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  LatLng? _destinationPoint;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    final lat = (widget.initialLat == 0.0) ? 21.028511 : widget.initialLat;
    final lng = (widget.initialLng == 0.0) ? 105.804817 : widget.initialLng;
    _currentCenter = LatLng(lat, lng);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await ApiService.goongAutoComplete(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    final placeId = place['place_id'];
    if (placeId == null) return;

    setState(() {
      _searchResults = [];
      _searchController.text = place['description'] ?? '';
    });

    final detail = await ApiService.goongPlaceDetail(placeId);
    if (detail != null && detail['geometry'] != null && detail['geometry']['location'] != null) {
      final loc = detail['geometry']['location'];
      final double lat = double.tryParse(loc['lat'].toString()) ?? _currentCenter.latitude;
      final double lng = double.tryParse(loc['lng'].toString()) ?? _currentCenter.longitude;

      final newTarget = LatLng(lat, lng);
      setState(() {
        _destinationPoint = newTarget;
      });

      _mapController.move(newTarget, 15.0);

      // Fetch direction from initial point to target point
      final originStr = "${_currentCenter.latitude},${_currentCenter.longitude}";
      final destStr = "$lat,$lng";
      final dir = await ApiService.goongDirections(originStr, destStr);
      if (dir != null && dir['routes'] != null && (dir['routes'] as List).isNotEmpty) {
        final route = dir['routes'][0];
        if (route['overview_polyline'] != null && route['overview_polyline']['points'] != null) {
          final polylineStr = route['overview_polyline']['points'].toString();
          final decoded = _decodePolyline(polylineStr);
          if (mounted) {
            setState(() {
              _routePoints = decoded;
            });
          }
        }
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  @override
  Widget build(BuildContext context) {
    final String goongMapKey = dotenv.maybeGet('GOONG_MAP_KEY') ?? '';

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xff1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ckms.app',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.orangeAccent,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentCenter,
                      width: 60,
                      height: 50,
                      child: Tooltip(
                        message: widget.title,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.title,
                                style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 26),
                          ],
                        ),
                      ),
                    ),
                    if (_destinationPoint != null)
                      Marker(
                        point: _destinationPoint!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.pin_drop_rounded, color: Colors.blueAccent, size: 30),
                      ),
                  ],
                ),
              ],
            ),

            if (widget.showSearch)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xff1A1A1A).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        onChanged: (val) => _performSearch(val),
                        decoration: InputDecoration(
                          hintText: "Tìm địa điểm Goong Map (Autocomplete)...",
                          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, color: Colors.orange, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _destinationPoint = null;
                                      _routePoints = [];
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),

                    if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(4),
                          itemCount: _searchResults.length,
                          separatorBuilder: (ctx, i) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (ctx, i) {
                            final item = _searchResults[i];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                item['description'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectPlace(item),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_rounded, color: Colors.orange, size: 10),
                    SizedBox(width: 4),
                    Text(
                      "Goong Map SDK",
                      style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
