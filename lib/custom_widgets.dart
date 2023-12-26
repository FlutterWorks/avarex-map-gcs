import 'package:flutter/material.dart';

import 'constants.dart';

class CustomWidgets {
  static Widget dropDownButton(BuildContext context, String defaultValue, List<String> items, Alignment align, double bottom, Function (String?) onChange) {
    return Positioned(
        child: Align(
            alignment: align,
            child: items[0].isEmpty ? Container() :
            DropdownButton<String>( // airport selection
              padding: EdgeInsets.fromLTRB(5, 5, 5, bottom),
              underline: Container(),
              iconEnabledColor: Constants.dropDownButtonIconColor,
              value: defaultValue,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: TextStyle(color: Constants.dropDownButtonColor, backgroundColor: Constants.dropDownButtonBackgroundColor)),
                );
              }).toList(),
              onChanged: (value) {
                onChange(value);
              },
            )
        )
    );
  }

  static Widget centerButton(BuildContext context, double bottom, Function() pressed) {
    return Positioned(
      child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, bottom + 40),
            child: CircleAvatar(backgroundColor: Constants.centerButtonBackgroundColor, child:IconButton(
            onPressed: () {
              pressed();
            }, icon: const Icon(Icons.gps_fixed)),
          ))
      ),
    );
  }
}