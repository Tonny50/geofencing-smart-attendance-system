import 'package:flutter/material.dart';
import 'registration_page.dart'; 
import 'package:geofence_service/geofence_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart' as loc;
import 'dart:async';

void main() async {
   WidgetsFlutterBinding.ensureInitialized();
   await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: GeofenceHome(),
    );
  }
}

class GeofenceHome extends StatefulWidget {
  
  const GeofenceHome({super.key});

  @override
  _GeofenceHomeState createState() => _GeofenceHomeState();
}

class _GeofenceHomeState extends State<GeofenceHome> {
  late GeofenceService _geofenceService;
  final _geofenceStreamController = StreamController<Geofence>.broadcast();
  final _activityStreamController = StreamController<Activity>.broadcast();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGeofence();
    });
  }

  void _initializeGeofence() async {
    loc.Location location = loc.Location();
    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        // Handle service not enabled case
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        // Handle permission not granted case
        return;
      }
    }

    _geofenceService = GeofenceService.instance.setup(
      interval: 5000,
      accuracy: 100,
      loiteringDelayMs: 60000,
      statusChangeDelayMs: 10000,
      useActivityRecognition: true,
      allowMockLocations: false,
      printDevLog: false,
      geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
    );

    final _geofenceList = <Geofence>[
      Geofence(
        id: 'place_1',
        latitude: 4.18359,
        longitude: 9.31191,
        radius: [
          GeofenceRadius(id: 'radius_100m', length: 100),
          GeofenceRadius(id: 'radius_25m', length: 25),
          GeofenceRadius(id: 'radius_250m', length: 250),
          GeofenceRadius(id: 'radius_200m', length: 200),
        ],
      ),
      Geofence(
        id: 'place_2',
        latitude: 4.18358,
        longitude: 9.31192,
        radius: [
          GeofenceRadius(id: 'radius_25m', length: 25),
          GeofenceRadius(id: 'radius_100m', length: 100),
          GeofenceRadius(id: 'radius_200m', length: 200),
        ],
      ),
    ];

    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
    _geofenceService.addLocationChangeListener(_onLocationChanged);
    _geofenceService.addLocationServicesStatusChangeListener(_onLocationServicesStatusChanged);
    _geofenceService.addActivityChangeListener(_onActivityChanged);
    _geofenceService.addStreamErrorListener(_onError);

    _geofenceService.start(_geofenceList).catchError(_onError);
  }

  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location) async {
  final now = DateTime.now();
  final formattedDate = now.toIso8601String(); // or any date format you prefer

  if (geofenceStatus == GeofenceStatus.ENTER) {
    await FirebaseFirestore.instance.collection('geofence_logs').add({
      'geofenceId': geofence.id,
      'status': 'ENTER',
      'timestamp': formattedDate,
      'userId': 1344, // Replace with actual user ID
    });
  } else if (geofenceStatus == GeofenceStatus.EXIT) {
    await FirebaseFirestore.instance.collection('geofence_logs').add({
      'geofenceId': geofence.id,
      'status': 'EXIT',
      'timestamp': formattedDate,
      'userId': 1344, // Replace with actual user ID
    });
  }

  _geofenceStreamController.sink.add(geofence);
}


  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    print('prevActivity: ${prevActivity.toJson()}');
    print('currActivity: ${currActivity.toJson()}');
    _activityStreamController.sink.add(currActivity);
  }

  void _onLocationChanged(Location location) {
    print('location: ${location.toJson()}');
  }

  void _onLocationServicesStatusChanged(bool status) {
    print('isLocationServicesEnabled: $status');
  }

  void _onError(error) {
    print('Error: $error');
  }

  @override
  void dispose() {
    _geofenceStreamController.close();
    _activityStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Attendance Using Geofencing'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RegistrationPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Geofence>(
        stream: _geofenceStreamController.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final geofence = snapshot.data!;
            return Center(
              child: Text('Geofence ID: ${geofence.id}'),
            );
          } else {
            return const Center(
              child: Text('Waiting for geofence updates...'),
            );
          }
        },
      ),
    );
  }
}
