import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:avaremp/path_utils.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_settings.dart';
import 'db_general.dart';
import 'destination.dart';
import 'download_list.dart';
import 'gps.dart';

class Storage {
  static final Storage _instance = Storage._internal();

  factory Storage() {
    return _instance;
  }

  Storage._internal();

  // on gps update
  final gpsChange = ValueNotifier<Position>(Gps.centerUSAPosition());
  // when plate changes
  final plateChange = ValueNotifier<int>(0);
  // when destination changes
  final destinationChange = ValueNotifier<Destination?>(null);
  final timeChange = ValueNotifier<int>(0);
  final warningChange = ValueNotifier<bool>(false);


  // gps
  final _gps = Gps();
  // where all data is place. This is set on init in main
  String dataDir = "";
  Position position = Gps.centerUSAPosition();
  final AppSettings settings = AppSettings();

  Destination? currentDestination;

  // make it double buffer to get rid of plate load flicker
  ui.Image? imagePlate;
  // to move the plate
  String lastPlateAirport = "";
  String currentPlate = "";
  List<double>? matrixPlate;
  bool dataExpired = false;
  bool chartsMissing = false;
  bool gpsNotPermitted = false;
  bool gpsDisabled = false;

  // for navigation on tabs
  final GlobalKey globalKeyBottomNavigationBar = GlobalKey();

  setDestination(Destination? destination) {
    currentDestination = destination;
    destinationChange.value = destination;
  }

  Future<void> init() async {
    DbGeneral.set(); // set database platform
    WidgetsFlutterBinding.ensureInitialized();
    await WakelockPlus.enable(); // keep screen on
    // ask for GPS permission
    await _gps.checkPermissions();
    position = await Gps().getLastPosition();
    Directory dir = await getApplicationDocumentsDirectory();
    dataDir = dir.path;
    await settings.initSettings();
    // GPS data receive
    _gps.getStream().onData((data) {
        position = data;
        gpsChange.value = position; // tell everyone
      });
    await checkChartsExist();
    await checkDataExpiry();

    String path = join(dataDir, "256.png");
    ByteData data = await rootBundle.load("assets/images/256.png");
    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes);
    await FlutterMapTileCaching.initialise();
    await FMTC.instance('mapStore').manage.createAsync(); // cache tiles

    Timer.periodic(const Duration(seconds: 1), (tim) async {
      // this provides time to apps
      timeChange.value++;

      if(timeChange.value % 5 == 0) {
        // check system for any issues
        LocationPermission permission = await Gps().checkPermissions();
        gpsNotPermitted = (LocationPermission.denied == permission ||
            LocationPermission.deniedForever == permission ||
            LocationPermission.unableToDetermine == permission);

        gpsDisabled = !(await Gps().checkEnabled());
        warningChange.value = gpsNotPermitted || gpsDisabled || dataExpired || chartsMissing;

      }

      // check GPS enabled
    });
  }

  Future<void> checkDataExpiry() async {
    dataExpired = await DownloadListState.isAnyChartExpired();
  }

  Future<void> checkChartsExist() async {
    chartsMissing = !(await DownloadListState.doesAnyChartExists());
  }

  Future<void> loadPlate() async {
    String path = PathUtils.getPlatePath(dataDir, settings.getCurrentPlateAirport(), currentPlate);
    File file = File(path);
    Completer<ui.Image> completerPlate = Completer();
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    }
    catch(e) {
      ByteData bd = await rootBundle.load('assets/images/black.png');
      // file bad or not found
      bytes = bd.buffer.asUint8List();
    }
    Map<String, IfdTag> exif = await readExifFromBytes(bytes);
    matrixPlate = null;
    IfdTag? tag = exif["EXIF UserComment"];
    if(null != tag) {
      List<String> tokens = tag.toString().split("|");
      if(tokens.length == 4) {
        matrixPlate = [];
        matrixPlate!.add(double.parse(tokens[0]));
        matrixPlate!.add(double.parse(tokens[1]));
        matrixPlate!.add(double.parse(tokens[2]));
        matrixPlate!.add(double.parse(tokens[3]));
      }
    }

    ui.decodeImageFromList(bytes, (ui.Image img) {
      return completerPlate.complete(img);
    });
    ui.Image? image = await completerPlate.future; // double buffering
    if(imagePlate != null) {
      imagePlate!.dispose();
      imagePlate = null;
    }
    imagePlate = image;
    plateChange.value++; // change in storage
  }
}
