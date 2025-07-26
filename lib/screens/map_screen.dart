import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final String apiKey;
  const MapScreen({super.key, required this.apiKey});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  Position? userPos;
  final Set<Marker> _markers = {};
  Polyline? _route;
  List<Map<String, dynamic>> places = [];

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    userPos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (userPos != null && mounted) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(userPos!.latitude, userPos!.longitude),
          12,
        ),
      );
      await _searchNearby();
    }
  }

  Future<void> _searchNearby() async {
    if (userPos == null) return;

    final endpoint =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${userPos!.latitude},${userPos!.longitude}'
        '&radius=50000'
        '&type=hospital'
        '&key=${widget.apiKey}';

    final resp = await http.get(Uri.parse(endpoint));
    final data = jsonDecode(resp.body);

    if (data['status'] == 'OK') {
      places = (data['results'] as List).take(15).map((p) {
        final dist = Geolocator.distanceBetween(
          userPos!.latitude,
          userPos!.longitude,
          p['geometry']['location']['lat'],
          p['geometry']['location']['lng'],
        );
        return {
          'name': p['name'],
          'address': p['vicinity'] ?? 'Address not available',
          'lat': p['geometry']['location']['lat'],
          'lng': p['geometry']['location']['lng'],
          'distance': dist / 1000,
        };
      }).toList();

      for (var place in places) {
        _markers.add(
          Marker(
            markerId: MarkerId(place['name']),
            position: LatLng(place['lat'], place['lng']),
            infoWindow: InfoWindow(
              title: place['name'],
              snippet: '${place['distance'].toStringAsFixed(1)} km away',
              onTap: () =>
                  _drawRoute(LatLng(place['lat'], place['lng']), place['name']),
            ),
          ),
        );
      }
      setState(() {});
    }
  }

  Future<void> _drawRoute(LatLng dest, String name) async {
    final routeUrl =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${userPos!.latitude},${userPos!.longitude}'
        '&destination=${dest.latitude},${dest.longitude}'
        '&mode=walking'
        '&key=${widget.apiKey}';

    final resp = await http.get(Uri.parse(routeUrl));
    final data = jsonDecode(resp.body);

    if (data['status'] == 'OK') {
      final points = data['routes'][0]['overview_polyline']['points'];
      final decoded = _decodePolyline(points);

      setState(() {
        _route = Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blueAccent,
          width: 5,
          points: decoded,
        );
      });
    }
  }

  List<LatLng> _decodePolyline(String poly) {
    var list = <LatLng>[];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      list.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return list;
  }

  void _showPlaceDetails(Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place['name'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(place['address'], style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Text(
                  'Distance: ${place['distance'].toStringAsFixed(2)} km',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _drawRoute(
                        LatLng(place['lat'], place['lng']),
                        place['name'],
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Show Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: userPos != null
                  ? LatLng(userPos!.latitude, userPos!.longitude)
                  : const LatLng(12.8797, 121.7740),
              zoom: 12,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            markers: _markers,
            polylines: _route != null ? {_route!} : {},
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nearby Safe Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final p = places[i];
                        return GestureDetector(
                          onTap: () {
                            _showPlaceDetails(p);
                          },
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${p['distance'].toStringAsFixed(1)} km away',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: () => _drawRoute(
                                      LatLng(p['lat'], p['lng']),
                                      p['name'],
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      padding: EdgeInsets.zero,
                                      textStyle: const TextStyle(fontSize: 14),
                                    ),
                                    child: const Text('Go'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
