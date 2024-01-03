// destination base class

import 'package:latlong2/latlong.dart';

class Destination {

  final String locationID;
  final String type;
  final String facilityName;
  final LatLng coordinate;

  const Destination({
    required this.locationID,
    required this.type,
    required this.facilityName,
    required this.coordinate,
  });

  static const String typeGps = "GPS";

  static bool isNav(String type) {
    return type == "TACAN" ||
        type == "NDB/DME" ||
        type == "MARINE NDB" ||
        type == "UHF/NDB" ||
        type == "NDB" ||
        type == "VOR/DME" ||
        type == "VOT" ||
        type == "VORTAC" ||
        type == "FAN MARKER" ||
        type == "VOR";
  }

  static String formatSexagesimal(String input) {
    return input.replaceAll("'", " ").replaceAll("\"", " ").replaceAll("\u00b0", " ");
  }

  static bool isAirport(String type) {
    return type == "AIRPORT" ||
        type == "SEAPLANE BAS" ||
        type == "HELIPORT" ||
        type == "ULTRALIGHT" ||
        type == "GLIDERPORT" ||
        type == "BALLOONPORT" ||
        type == "OUR-AP";
  }

  static bool isFix(String type) {
    return type == "YREP-PT" ||
        type == "YRNAV-WP" ||
        type == "NARTCC-BDRY" ||
        type == "NAWY-INTXN" ||
        type == "NTURN-PT" ||
        type == "YWAYPOINT" ||
        type == "YMIL-REP-PT" ||
        type == "YCOORDN-FIX" ||
        type == "YMIL-WAYPOINT" ||
        type == "YNRS-WAYPOINT" ||
        type == "YVFR-WP" ||
        type == "YGPS-WP" ||
        type == "YCNF" ||
        type == "YRADAR" ||
        type == "NDME-FIX" ||
        type == "NNOT-ASSIGNED" ||
        type == "NDP-TRANS-XING" ||
        type == "NSTAR-TRANS-XIN" ||
        type == "NBRG-INTXN";
  }

  static bool isGps(String type) {
    return type == "GPS";
  }

  static Destination dummy(LatLng coordinate) {
    return Destination(locationID: "", type: "", facilityName: "", coordinate: coordinate);
  }
}

class NavDestination extends Destination {

  double elevation;
  String class_;
  String hiwas;
  int variation;

  NavDestination({
  required super.locationID,
  required super.type,
  required super.facilityName,
  required super.coordinate,
  required this.elevation,
  required this.class_,
  required this.hiwas,
  required this.variation});
}

class FixDestination extends Destination {
  FixDestination({
    required super.locationID,
    required super.type,
    required super.facilityName,
    required super.coordinate,});
}

class GpsDestination extends Destination {
  GpsDestination({
    required super.locationID,
    required super.type,
    required super.facilityName,
    required super.coordinate,});
}

class NonFaaDestination extends Destination {
  NonFaaDestination({
    required super.locationID,
    required super.type,
    required super.facilityName,
    required super.coordinate,});
}

class AirportDestination extends Destination {

  final double elevation;
  final List<Map<String, dynamic>> frequencies;
  final List<Map<String, dynamic>> runways;
  final List<Map<String, dynamic>> awos;
  final String unicom;
  final String ctaf;

  AirportDestination({
    required super.locationID,
    required super.type,
    required super.facilityName,
    required super.coordinate,
    required this.elevation,
    required this.frequencies,
    required this.awos,
    required this.runways,
    required this.unicom,
    required this.ctaf
  });
}

