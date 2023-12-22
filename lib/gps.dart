import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';


class Gps {

  static LatLng positionToLatLong(Position position) {
    LatLng l;
    l = LatLng(position.latitude, position.longitude);
    return(l);
  }

  // if position is null, return lat/lon to center of USA, otherwise return same position back
  static Position _orCenterOfUsa(Position? position) {
    if(null == position) {
      return Position(longitude: -97, latitude: 38, accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0, timestamp: DateTime.now());
    }
    return(position);
  }

  Future<LocationPermission> checkPermissions() async {
    final GeolocatorPlatform platform = GeolocatorPlatform.instance;
    LocationPermission permission = await platform.checkPermission();
    if(permission != LocationPermission.always) {
      permission = await platform.requestPermission();
    }
    return permission;
  }

  Future<bool> checkEnabled() async {
    final GeolocatorPlatform platform = GeolocatorPlatform.instance;
    return await platform.isLocationServiceEnabled();
  }

  Future<Position> getCurrentPosition() async {
    try {
      return Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    }
    catch(e) {
      return getLastPosition();
    }
  }

  Future<Position> getLastPosition() async {
    try {
      Position? p = await Geolocator.getLastKnownPosition();
      return(_orCenterOfUsa(p));
    }
    catch(e) {
      return (_orCenterOfUsa(null));
    }
  }

}

