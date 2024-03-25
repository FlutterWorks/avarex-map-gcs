import 'dart:core';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:avaremp/gdl90/traffic_report_message.dart';
import 'package:avaremp/geo_calculations.dart';
import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:avaremp/gdl90/audible_traffic_alerts.dart';

import '../gps.dart';

const double _kDivBy180 = 1.0 / 180.0;

class Traffic {

  final TrafficReportMessage message;

  Traffic(this.message);

  bool isOld() {
    // old if more than 1 min
    return DateTime.now().difference(message.time).inMinutes > 0;
  }

  Widget getIcon() {
    // return Transform.rotate(angle: message.heading * pi / 180,
    //      child: Container(
    //        decoration: BoxDecoration(
    //            borderRadius: BorderRadius.circular(5),
    //            color: Colors.black),
    //        child:const Icon(Icons.arrow_upward_rounded, color: Colors.white,)));
    return Transform.rotate(angle: (message.heading + 180.0 /* Image painted down on coordinate plane */) * pi  * _kDivBy180,
      child: CustomPaint(painter: TrafficPainter(this)));
  }

  LatLng getCoordinates() {
    return message.coordinates;
  }

  @override
  String toString() {
    return "${message.callSign}\n${message.altitude.toInt()} ft\n"
    "${(message.velocity * 1.94384).toInt()} knots\n"
    "${(message.verticalSpeed * 3.28).toInt()} fpm";
  }
}


class TrafficCache {
  static const int maxEntries = 20;
  final List<Traffic?> _traffic = List.filled(maxEntries + 1, null); // +1 is the empty slot where new traffic is added

  double findDistance(LatLng coordinate, double altitude) {
    // find 3d distance between current position and airplane
    // treat 1 mile of horizontal distance as 500 feet of vertical distance (C182 120kts, 1000 fpm)
    LatLng current = Gps.toLatLng(Storage().position);
    double horizontalDistance = GeoCalculations().calculateDistance(current, coordinate) * 500;
    double verticalDistance   = (Storage().position.altitude * 3.28084 - altitude).abs();
    double fac = horizontalDistance + verticalDistance;
    return fac;
  }

  void putTraffic(TrafficReportMessage message) {

    // filter own report
    if(message.icao == Storage().myIcao) {
      // do not add ourselves
      return;
    }

    for(Traffic? traffic in _traffic) {
      int index = _traffic.indexOf(traffic);
      if(traffic == null) {
        continue;
      }
      if(traffic.isOld()) {
        _traffic[index] = null;
        // purge old
        continue;
      }

      // update
      if(traffic.message.icao == message.icao) {
        // call sign not available. use last one
        if(message.callSign.isEmpty) {
          message.callSign = traffic.message.callSign;
        }
        final Traffic trafficNew = Traffic(message);
        _traffic[index] = trafficNew;

        // process any audible alerts from traffic (if enabled)
        handleAudibleAlerts();

        return;
      }
    }

    // put it in the end
    final Traffic trafficNew = Traffic(message);
    _traffic[maxEntries] = trafficNew;

    // sort
    _traffic.sort(_trafficSort);

    // process any audible alerts from traffic (if enabled)
    handleAudibleAlerts();

  }

  int _trafficSort(Traffic? left, Traffic? right) {
    if(null == left && null != right) {
      return 1;
    }
    if(null != left && null == right) {
      return -1;
    }
    if(null == left && null == right) {
      return 0;
    }
    if(null != left && null != right) {
      double l = findDistance(left.message.coordinates, left.message.altitude);
      double r = findDistance(right.message.coordinates, right.message.altitude);
      if(l > r) {
        return 1;
      }
      if(l < r) {
        return -1;
      }
    }
    return 0;
  }

  void handleAudibleAlerts() {
    if (Storage().settings.isAudibleAlertsEnabled()) {
      AudibleTrafficAlerts.getAndStartAudibleTrafficAlerts().then((value) {
        // TODO: Set all of the "pref" settings from new Storage params (which in turn have a config UI?)
        value?.processTrafficForAudibleAlerts(_traffic, Storage().position, Storage().lastMsGpsSignal, Storage().vspeed, Storage().airborne);
      });
    } else {
      AudibleTrafficAlerts.stopAudibleTrafficAlerts();
    }
  }

  List<Traffic> getTraffic() {
    List<Traffic> ret = [];

    for(Traffic? check in _traffic) {
      if(null != check) {
        ret.add(check);
      }
    }
    return ret;
  }
}

enum _TrafficAircraftIconType { unmapped, light, large, rotorcraft }

/// Icon painter for different traffic aircraft types (ADSB emitter category) and flight status
class TrafficPainter extends CustomPainter {

  // Preference control variables
  static bool prefSpeedBarb = false;                        // Shows line/barb at tip of icon based on speed/velocity
  static bool prefAltDiffOpacityGraduation = true;          // Gradually vary opacity of icon based on altitude diff from ownship
  static bool prefUseDifferentDefaultIconThanLight = false; // Use a different default icon for unmapped or "0" emitter category ID traffic
  static bool prefShowBoundingBox = true;                   // Display outlined bounding box around icon for higher visibility
  static bool prefShowShadow = false;                       // Display shadow effect "under" aircraft for higher visibility

  // Static picture cache, for faster rendering of the same image for another marker, based on flight state
  static final Map<String,ui.Picture> _pictureCache = {};

  // Const's for magic #'s and division speedup
  static const double _kMetersToFeetCont = 3.28084;
  static const double _kMetersPerSecondToKnots = 1.94384;
  static const double _kDivBy60Mult = 1.0 / 60.0;
  static const double _kDivBy1000Mult = 1.0 / 1000.0;
  // UI Default constants
  static const double _kTrafficOpacityMin = 0.2;
  static const double _kFlyingTrafficOpacityMax = 1.0;
  static const double _kGroundTrafficOpacityMax = 0.5;
  static const double _kFlightLevelOpacityReduction = 0.1;
  static const int _kShadowDrawPasses = 2;
  static const double _kShadowElevation = 5.0;
  // Colors for different aircraft heights, and contrasting overlays
  static const Color _kLevelColor = Color(0xFFBDAED1);           // Level traffic = Purple
  static const Color _kHighColor = Color(0xFF00DFFF);            // High traffic = Cyanish
  static const Color _kLowColor = Color(0xFF65FE08);             // Low traffic = Lime Green
  static const Color _kGroundColor = Color(0xFF836539);          // Ground traffic = Brown
  static const Color _kDarkForegroundColor = Color(0xFF000000);  // Overlay color = Black

  // Aircraft type outlines
  static final ui.Path _largeAircraft = ui.Path()
    // body
    ..addOval(const Rect.fromLTRB(12, 5, 19, 31))
    ..addRect(const Rect.fromLTRB(12, 11, 19, 20))..addRect(const Rect.fromLTRB(12, 11, 19, 20)) // duped, for forcing opacity
    ..addOval(const Rect.fromLTRB(12, 0, 19, 25))..addOval(const Rect.fromLTRB(12, 0, 19, 25)) // duped, for forcing opacity
    // left wing
    ..addPolygon([ const Offset(0, 13), const Offset(0, 16), const Offset(15, 22), const Offset(15, 14) ], true) 
    ..addRect(const Rect.fromLTRB(12, 14, 16, 17))  // splash of paint to cover an odd alias artifact
    ..addPolygon([ const Offset(0, 13), const Offset(0, 16), const Offset(15, 22), const Offset(15, 14) ], true) // duped, for forcing opacity
    // left engine
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(6, 17, 10, 24), const Radius.circular(1)))  
    // left h-stabilizer
    ..addPolygon([ const Offset(9, 0), const Offset(9, 3), const Offset(15, 7), const Offset(15, 1) ], true) 
    // right wing
    ..addPolygon([ const Offset(31, 13), const Offset(31, 16), const Offset(17, 22), const Offset(17, 14) ], true)
    ..addPolygon([ const Offset(31, 13), const Offset(31, 16), const Offset(17, 22), const Offset(17, 14) ], true) // duped, for forcing opacity
    // right engine
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(21, 17, 25, 24), const Radius.circular(1)))  
    // right h-stabilizer
    ..addPolygon([ const Offset(22, 0), const Offset(22, 3), const Offset(16, 7), const Offset(16, 1) ], true);       
  static final ui.Path _defaultAircraft = ui.Path()  // old default icon if no ICAO ID--just a triangle
    ..addPolygon([ const Offset(0, 0), const Offset(15, 31), const Offset(16, 31), const Offset(31, 0), 
      const Offset(16, 5), const Offset(15, 5) ], true);
  static final ui.Path _lightAircraft = ui.Path()
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(12, 18, 19, 31), const Radius.circular(2))) // body
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0, 18, 31, 25), const Radius.circular(1))) // wings
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(10, 0, 21, 5), const Radius.circular(1)))  // h-stabilizer
    ..addPolygon([ const Offset(12, 20), const Offset(14, 4), const Offset(17, 4), const Offset(19, 20)], true); // rear body
  static final ui.Path _rotorcraft = ui.Path()
    // body
    ..addOval(const Rect.fromLTRB(9, 11, 22, 31))
    // rotor blades
    ..addPolygon([const Offset(27, 11), const Offset(29, 13), const Offset(4, 31), const Offset(2, 29)], true)
    ..addPolygon([const Offset(27, 11), const Offset(29, 13), const Offset(4, 31), const Offset(2, 29)], true) // duped, for forcing opacity
    ..addPolygon([const Offset(4, 11), const Offset(2, 13), const Offset(27, 31), const Offset(29, 29) ], true)
    ..addPolygon([const Offset(4, 11), const Offset(2, 13), const Offset(27, 31), const Offset(29, 29) ], true) // duped, for forcing opacity
    // tail
    ..addRect(const Rect.fromLTRB(15, 0, 16, 12))
    // horizontal stabilizer
    ..addRRect(RRect.fromLTRBR(10, 3, 21, 7, const Radius.circular(1))); 
  // vertical speed plus/minus overlays
  static final ui.Path _plusSign = ui.Path()
    ..addPolygon([ const Offset(14, 13), const Offset(14, 22), const Offset(17, 22), const Offset(17, 13) ], true)
    ..addPolygon([ const Offset(11, 16), const Offset(20, 16), const Offset(20, 19), const Offset(11, 19) ], true)
    ..addPolygon([ const Offset(11, 16), const Offset(20, 16), const Offset(20, 19), const Offset(11, 19) ], true);  // duped, for forcing opacity
  static final ui.Path _minusSign = ui.Path()
    ..addPolygon([ const Offset(11, 16), const Offset(20, 16), const Offset(20, 19), const Offset(11, 19) ], true);
  static final ui.Path _lowerPlusSign = ui.Path()
    ..addPolygon([ const Offset(14, 17), const Offset(14, 26), const Offset(17, 26), const Offset(17, 17) ], true)
    ..addPolygon([ const Offset(11, 20), const Offset(20, 20), const Offset(20, 23), const Offset(11, 23) ], true)
    ..addPolygon([ const Offset(11, 20), const Offset(20, 20), const Offset(20, 23), const Offset(11, 23) ], true);  // duped, for forcing opacity
  static final ui.Path _lowerMinusSign = ui.Path()
    ..addPolygon([ const Offset(11, 20), const Offset(20, 20), const Offset(20, 23), const Offset(11, 23) ], true);
  static final ui.Path _boundingBox = ui.Path()
    ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0, 0, 31, 31), const Radius.circular(3)));    
 
  final _TrafficAircraftIconType _aircraftType;
  final bool _isAirborne;
  final int _flightLevelDiff;
  final int _vspeedDirection;
  final int _velocityLevel;
  /// Unique key of icon state based on flight properties that define the icon appearance, per the current
  /// configuration of enabled features.  This is used to determine UI-relevant state changes for repainting,
  /// as well as the key to the picture cache  
  String _iconStateKey = "";

  TrafficPainter(Traffic traffic) 
    : _aircraftType = _getAircraftIconType(traffic.message.emitter), 
      _isAirborne = traffic.message.airborne,
      _flightLevelDiff = prefAltDiffOpacityGraduation ? _getGrossFlightLevelDiff(traffic.message.altitude) : -999999, 
      _vspeedDirection = _getVerticalSpeedDirection(traffic.message.verticalSpeed),
      _velocityLevel = prefSpeedBarb ? _getVelocityLevel(traffic.message.velocity) : -999999 
    {
      _iconStateKey = "$_vspeedDirection^$_flightLevelDiff^$_velocityLevel^$_isAirborne";
    }

  /// Paint arcraft, vertical speed direction overlay, and (horizontal) speed barb--using 
  /// cached picture if possible (if not, draw and cache a new one)
  @override paint(Canvas canvas, Size size) {
    // Use pre-painted picture from cache based on relevant icon UI-driving parameters, if possible
    final ui.Picture? cachedPicture = _pictureCache[_iconStateKey];
      canvas.drawPicture(cachedPicture);
    } else {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas drawingCanvas = Canvas(recorder);

      final double opacity;
      if (prefAltDiffOpacityGraduation) {
        // Decide opacity, based on vertical distance from ownship and whether traffic is on the ground. 
        // Traffic far above or below ownship will be quite transparent, to avoid clutter, and 
        // ground traffic has a 50% max opacity / min transparency to avoid taxiing or stationary (ADSB-initilized)
        // traffic from flooding the map. Opacity decrease is 10% for every 1000 foot diff above or below, with a 
        // floor of 20% total opacity (i.e., max 80% transparency)        
        opacity = min(
          max(_kTrafficOpacityMin, 
            (_isAirborne ? _kFlyingTrafficOpacityMax : _kGroundTrafficOpacityMax) - _flightLevelDiff.abs() * _kFlightLevelOpacityReduction
          ), 
          _isAirborne ? _kFlyingTrafficOpacityMax : _kGroundTrafficOpacityMax
        );
      } else {
        opacity = 1.0;
      }

      // Define aircraft, barb, accent/overlay colors and paint using above flight-level diff opacity
      final Paint aircraftPaint;
      if (!_isAirborne) {
        aircraftPaint = Paint()..color = Color.fromRGBO(_kGroundColor.red, _kGroundColor.green, _kGroundColor.blue, opacity);
      } else if (_flightLevelDiff > 0) {
        aircraftPaint = Paint()..color = Color.fromRGBO(_kHighColor.red, _kHighColor.green, _kHighColor.blue, opacity);
      } else if (_flightLevelDiff < 0) {
        aircraftPaint = Paint()..color = Color.fromRGBO(_kLowColor.red, _kLowColor.green, _kLowColor.blue, opacity);
      } else {
        aircraftPaint = Paint()..color = Color.fromRGBO(_kLevelColor.red, _kLevelColor.green, _kLevelColor.blue, opacity);
      }
      final Color darkAccentColor = Color.fromRGBO(_kDarkForegroundColor.red, _kDarkForegroundColor.green, _kDarkForegroundColor.blue, opacity);
      final Paint vspeedOverlayPaint = Paint()..color = darkAccentColor;

      // Set aircraft shape
      final ui.Path baseIconShape;
      switch(_aircraftType) {
        case _TrafficAircraftIconType.light:
          baseIconShape = ui.Path.from(_lightAircraft);
          break;           
        case _TrafficAircraftIconType.large:
          baseIconShape = ui.Path.from(_largeAircraft);
          break;
        case _TrafficAircraftIconType.rotorcraft:
          baseIconShape = ui.Path.from(_rotorcraft);
          break;
        default:
          baseIconShape = (prefUseDifferentDefaultIconThanLight ? ui.Path.from(_defaultAircraft) : ui.Path.from(_lightAircraft));
      }            

      if (prefSpeedBarb) {
        // Create speed barb based on current velocity and add to plane shape, for one-shot rendering (saves time/resources)
        baseIconShape.addPath(ui.Path()..addRect(Rect.fromLTWH(14, 31, 3, _velocityLevel*2.0)), const Offset(0, 0));
      }

      if (prefShowBoundingBox) {
        // Draw transluscent bounding box for greater visibility (especially sectionals)
        drawingCanvas.drawPath(_boundingBox, 
          Paint()..color = Color.fromRGBO(_kDarkForegroundColor.red, _kDarkForegroundColor.green, _kDarkForegroundColor.blue,
            // Have box fill opacity be 30% less, but track main icon, with a floor of 10% less than regular opacity
            max(opacity - .3, _kTrafficOpacityMin - .1)));                 
      }

      if (prefShowShadow) {
        // Draw shadow for contrast on detailed backgrounds (especially secitionals)
        for (int i = 0; i < _kShadowDrawPasses; i++) {
          drawingCanvas.drawShadow(baseIconShape, darkAccentColor, _kShadowElevation, true);  
        }
      }

      // Draw aircraft (and speed barb, if feature enabled)
      drawingCanvas.drawPath(baseIconShape, aircraftPaint);

      // Draw vspeed overlay (if not level)
      if (_vspeedDirection != 0) {
        if (_aircraftType == _TrafficAircraftIconType.light || _aircraftType == _TrafficAircraftIconType.rotorcraft 
          || (!prefUseDifferentDefaultIconThanLight && _aircraftType == _TrafficAircraftIconType.unmapped)
        ) {
          drawingCanvas.drawPath(_vspeedDirection > 0 ? _lowerPlusSign : _lowerMinusSign, vspeedOverlayPaint);
        } else {
          drawingCanvas.drawPath(_vspeedDirection > 0 ? _plusSign : _minusSign, vspeedOverlayPaint);    
        }
      }  

      // store this fresh image to the cache for quick and efficient rendering next time
      final ui.Picture newPicture = recorder.endRecording();
      _pictureCache[_iconStateKey] = newPicture;

      // now draw the new picture to this widget's canvas
      canvas.drawPicture(newPicture);
    }
  }

  /// Only repaint this traffic marker if one of the flight properties affecting the icon changes
  @override
  bool shouldRepaint(covariant TrafficPainter oldDelegate) {
    return _iconStateKey == oldDelegate._iconStateKey;
  }

  @pragma("vm:prefer-inline")
  static _TrafficAircraftIconType _getAircraftIconType(int adsbEmitterCategoryId) {
    switch(adsbEmitterCategoryId) {
      case 1: // Light (ICAO) < 15,500 lbs 
      case 2: // Small - 15,500 to 75,000 lbs 
        return _TrafficAircraftIconType.light;
      case 3: // Large - 75,000 to 300,000 lbs
      case 4: // High Vortex Large (e.g., aircraft such as B757) 
      case 5: // Heavy (ICAO) - > 300,000 lbs
        return _TrafficAircraftIconType.large;
      case 7: // Rotorcraft 
        return _TrafficAircraftIconType.rotorcraft;
      default:
        return _TrafficAircraftIconType.unmapped;
    }
  }

  /// Break flight levels into 1K chunks (bounding upper/lower to relevent opcacity limits to make image caching more efficient)
  @pragma("vm:prefer-inline")
  static int _getGrossFlightLevelDiff(double trafficAltitude) {
    return max(min(((trafficAltitude - Storage().position.altitude * _kMetersToFeetCont) * _kDivBy1000Mult).round(), 8), -8);
  }

  @pragma("vm:prefer-inline")
  static int _getVerticalSpeedDirection(double verticalSpeedMps) {
    if (verticalSpeedMps*_kMetersToFeetCont < -100) {
      return -1;
    } else if (verticalSpeedMps*_kMetersToFeetCont > 100) {
      return 1;
    } else {
      return 0;
    }
  }

  @pragma("vm:prefer-inline")
  static int _getVelocityLevel(double veloMps) {
    return (veloMps * _kMetersPerSecondToKnots * _kDivBy60Mult).round();
  }  
}