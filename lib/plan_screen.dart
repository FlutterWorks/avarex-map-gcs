import 'package:avaremp/constants.dart';
import 'package:avaremp/plan_route.dart';
import 'package:avaremp/storage.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import 'destination.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<StatefulWidget> createState() => PlanScreenState();

}




class PlanScreenState extends State<PlanScreen> {

  Widget makeWaypoint(List<Destination> items, int index) {
      return Dismissible( // able to delete with swipe
        background: Container(alignment: Alignment.centerRight,child: const Icon(Icons.delete_forever),),
        key: Key(items[index].facilityName),
        direction: DismissDirection.endToStart,
        onDismissed:(direction) {
          items.removeAt(index);
        },
        child: ListTile(
          title: Text(items[index].locationID),
          subtitle: Text("${items[index].facilityName} ( ${items[index].type} )"),
          dense: true,
          isThreeLine: true,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final PlanRoute? route = Storage().route;
    if(null == route) {
      return Container();
    }
    Destination? origin = route.origin;
    List<Destination>? waypoints = route.route;
    Destination? destination = route.destination;
    double? height = Constants.appbarMaxSize(context);
    double? bottom = Constants.bottomPaddingSize(context);


    // user can rearrange widgets
    return Container(padding: EdgeInsets.fromLTRB(5, height!, 5, bottom),
        child:Column(
          children:[
            Expanded(flex: 1, child: Divider()),
            Expanded(flex: 10, child:ListTile(leading: Icon(MdiIcons.rayStartArrow), subtitle: Text(origin!.facilityName), title: Text(origin.locationID))),
            Expanded(flex: 1, child: Divider()),

            Expanded(flex: 60,
                child:ReorderableListView(
                scrollDirection: Axis.vertical,
                buildDefaultDragHandles: false,
                children: <Widget>[
                ],
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final Destination item = waypoints!.removeAt(oldIndex);
                  waypoints.insert(newIndex, item);
                  });
                }
              )
            ),

            Expanded(flex: 1, child: Divider()),
            Expanded(flex: 10, child: ListTile(leading: Icon(Icons.pin_end), subtitle: Text(destination!.facilityName), title: Text(destination.locationID))),
            Expanded(flex: 1, child: Divider()),
    ]));

  }
}
