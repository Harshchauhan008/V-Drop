import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:location/location.dart' as loc;
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const MapScreen({super.key, required this.latitude, required this.longitude});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _locationController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _route = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
    _destination = LatLng(widget.latitude, widget.longitude);
  }

  Future<void> _initCurrentLocation() async {
    final location = loc.Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final loc.LocationData locationData = await location.getLocation();
    setState(() {
      _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      _isLoading = false;
    });
  }

  Future<void> _searchLocation() async {
    final query = _locationController.text.trim();
    if (query.isEmpty) return;

    try {
      List<geo.Location> locations = await geo.locationFromAddress(query);
      if (locations.isNotEmpty) {
        final lat = locations.first.latitude;
        final lng = locations.first.longitude;

        setState(() {
          _destination = LatLng(lat, lng);
          _route = []; // Clear route for now
        });

        _mapController.move(LatLng(lat, lng), 14);
      }
    } catch (e) {
      print('Location search error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not found")),
      );
    }
  }

  Future<void> _drawRoute() async {
    if (_currentLocation == null || _destination == null) return;

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
          '${_currentLocation!.longitude},${_currentLocation!.latitude};'
          '${_destination!.longitude},${_destination!.latitude}?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final List<dynamic> coords = data['routes'][0]['geometry']['coordinates'];
        final List<LatLng> routePoints = coords
            .map((point) => LatLng(point[1], point[0]))
            .toList();

        setState(() {
          _route = routePoints;
        });
      } else {
        print('No route found.');
      }
    } catch (e) {
      print('Error fetching route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load route')),
      );
    }
  }


  void _goToUserLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MapScreen')),
      body: _isLoading || (_currentLocation == null && _destination == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
      children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      hintText: "Search location...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchLocation,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _destination ?? _currentLocation!,
                initialZoom: 14,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.spotvibes',
                ),
                CurrentLocationLayer(
                  style: LocationMarkerStyle(
                    marker: const DefaultLocationMarker(
                      child: Icon(Icons.my_location, color: Colors.white),
                    ),
                    markerSize: const Size(35, 35),
                    markerDirection: MarkerDirection.heading,
                  ),
                ),
                
                IconButton(onPressed: _drawRoute,
                    icon: Icon(Icons.explore)),
                
                if (_destination != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _destination!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_pin, color: Colors.red),
                      ),
                    ],
                  ),
                if (_route.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route,
                        color: Colors.blue,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'route_btn',
            onPressed: _drawRoute,
            backgroundColor: Colors.orange,
            tooltip: "Show Route",
            child: const Icon(Icons.alt_route, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'location_btn',
            onPressed: _goToUserLocation,
            backgroundColor: Colors.blue,
            tooltip: "My Location",
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }
}