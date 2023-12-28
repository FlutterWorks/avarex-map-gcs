import 'dart:math';

import 'package:avaremp/destination.dart';
import 'package:flutter/material.dart';

import 'constants.dart';

class Airport {

  static bool isAirport(String type) {
    return type == "AIRPORT" ||
        type == "SEAPLANE BAS" ||
        type == "HELIPORT" ||
        type == "ULTRALIGHT" ||
        type == "GLIDERPORT" ||
        type == "BALLOONPORT";
  }

  static String parseFrequencies(AirportDestination airport) {

    List<Map<String, dynamic>> frequencies = airport.frequencies;
    List<Map<String, dynamic>> awos = airport.awos;

    List<String> atis = [];
    List<String> clearance = [];
    List<String> ground = [];
    List<String> tower = [];
    List<String> automated = [];

    for(Map<String, dynamic> f in frequencies) {
      try {
        // Type, Freq
        String type = f['Type'];
        String freq = f['Freq'];
        if (type == 'LCL/P') {
          tower.add(freq);
        }
        else if (type == 'GND/P') {
          ground.add(freq);
        }
        else if (type.contains('ATIS')) {
          atis.add(freq);
        }
        else if (type == 'CD/P' || type.contains('CLNC')) {
          clearance.add(freq);
        }
        else {
          continue;
        }
      }
      catch(e) {}
    }

    for(Map<String, dynamic> f in awos) {
      try {
        // Type, Freq
        automated.add("${f['Type']} ${f['Frequency1']} ${f['Telephone1']}");
      }
      catch(e) {}
    }

    String ret = "Coordinates ${airport.coordinate.toString()}\n";
    ret += "Elevation ${airport.elevation.toString()}\n\n";

    if(tower.isNotEmpty) {
      ret += "Tower\n    ";
      ret += tower.join("\n    ");
    }
    if(ground.isNotEmpty) {
      ret += "\nGround\n    ";
      ret += ground.join("\n    ");
    }
    if(clearance.isNotEmpty) {
      ret += "\nClearance\n    ";
      ret += clearance.join("\n    ");
    }
    if(atis.isNotEmpty) {
      ret += "\nATIS\n    ";
      ret += atis.join("\n    ");
    }
    if(airport.ctaf.isNotEmpty) {
      ret += "\nCTAF\n    ";
      ret += airport.ctaf;
    }
    if(airport.unicom.isNotEmpty) {
      ret += "\nUNICOM\n    ";
      ret += airport.unicom;
    }
    if(automated.isNotEmpty) {
      ret += "\nAutomated\n    ";
      ret += automated.join("\n    ");
    }

    return ret;
  }

  static Widget runwaysWidget(AirportDestination airport) {
    return CustomPaint(painter : RunwayPainter(airport));
  }

  static Widget frequenciesWidget(String frequencies) {
    return CustomPaint(painter : FrequencyPainter(frequencies));
  }

}

class FrequencyPainter extends CustomPainter {

  String frequencies;

  FrequencyPainter(this.frequencies);

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width > size.height ? size.height : size.width;

    TextSpan span = TextSpan(
        style: TextStyle(color: Colors.white, fontSize: scale / 30),
        text: frequencies);
    TextPainter tp = TextPainter(text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, const Offset(0, 0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class RunwayPainter extends CustomPainter {

  AirportDestination airport;

  RunwayPainter(this.airport);

  @override
  void paint(Canvas canvas, Size size) {

    List<Map<String, dynamic>> runways = airport.runways;
    String info = "";
    double scale = size.width > size.height ? size.height : size.width;

    double maxLat = -180;
    double minLat = 180;
    double maxLon = -180;
    double minLon = 180;
    for(Map<String, dynamic> r in runways) {

      try {
        double leLat = double.parse(r['LELatitude']);
        double heLat = double.parse(r['HELatitude']);
        double leLon = double.parse(r['LELongitude']);
        double heLon = double.parse(r['HELongitude']);
        maxLat = leLat > maxLat ? leLat : maxLat;
        maxLat = heLat > maxLat ? heLat : maxLat;
        minLat = leLat < minLat ? leLat : minLat;
        minLat = heLat < minLat ? heLat : minLat;
        maxLon = leLon > maxLon ? leLon : maxLon;
        maxLon = heLon > maxLon ? heLon : maxLon;
        minLon = leLon < minLon ? leLon : minLon;
        minLon = heLon < minLon ? heLon : minLon;
      }
      catch (e) {}
    }

    Rect bounds = Rect.fromLTRB(minLon, maxLat, maxLon, minLat);
    double avg = max(bounds.width.abs(), bounds.height.abs()) / 1.6; // give margin for airport off center, ideally 2 if in center

    for(Map<String, dynamic> r in runways) {

      try {

        if(r['Length'] == "0") { // odd stuff like 0 length runways
          continue;
        }
        info += "${r['LEIdent']}/${r['HEIdent']} ${r['Length']}x${r['Width']} ${r['Surface']}\n";
        info += "    ${r['LEIdent']} ${r['LEPattern'] == 'Y' ? '*R' : ''} ${r['LELights']} ${r['LEILS']} ${r['LEVGSI']}\n";
        info += "    ${r['HEIdent']} ${r['HEPattern'] == 'Y' ? '*R' : ''} ${r['HELights']} ${r['HEILS']} ${r['HEVGSI']}\n";

      }
      catch(e) {}
    }

    TextSpan span = TextSpan(style: TextStyle(color: Colors.white, fontSize: scale / 30), text: info);
    TextPainter tp = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, const Offset(0, 0));

    double offsetX = size.width > size.height ? tp.size.width : 0;
    double offsetY = size.height > size.width ? tp.size.height : 0;

    for(Map<String, dynamic> r in runways) {

      double width = 0; // draw runways to width
      try {
        String w = r['Width'];
        width = double.parse(w);
      }
      catch (e) {
        width = 50;
      }
      width = width / 20;


      try {
        double leLat = double.parse(r['LELatitude']);
        double heLat = double.parse(r['HELatitude']);
        double leLon = double.parse(r['LELongitude']);
        double heLon = double.parse(r['HELongitude']);


        double apLat = airport.coordinate.latitude.value;
        double apLon = airport.coordinate.longitude.value;

        // adding this factor should cover all airport in US from center of the airport.
        double left = apLon - avg;
        double right = apLon + avg;
        double top = apLat + avg;
        double bottom = apLat - avg;

        // move down and to the side

        double px = scale / (left - right);
        double py = scale / (top - bottom);

        double lx = (left - leLon) * px;
        double ly = (top - leLat) * py;
        double hx = (left - heLon) * px;
        double hy = (top - heLat) * py;

        final paintLine = Paint()
          ..strokeWidth = width
          ..color = Constants.runwayColor; // runway color

        canvas.drawLine(Offset(lx + offsetX, ly + offsetY), Offset(hx + offsetX, hy + offsetY), paintLine);

        TextSpan span = TextSpan(style: TextStyle(color: Colors.white, fontSize: scale / 30), text: "${r['LEIdent']}");
        TextPainter tp = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(lx + offsetX, ly + offsetY));
        span = TextSpan(style: TextStyle(color: Colors.white, fontSize: scale / 30), text: "${r['HEIdent']}");
        tp = TextPainter(text: span, textAlign: TextAlign.left, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(hx + offsetX, hy + offsetY));

      }
      catch(e) {}
    }

  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
  return false;
  }


}
