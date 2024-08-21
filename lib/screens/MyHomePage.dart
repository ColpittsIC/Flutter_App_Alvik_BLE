import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

const ballSize = 20.0;
const step = 10.0;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _ble = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectSub;
  StreamSubscription<List<int>>? _notifySub;

  //IMU Data Variables
  var _found = false;
  var _value = '';
  var acc = [0.0, 0.0, 0.0];
  var gyro = [0.0, 0.0, 0.0];
  var orient = [0.0, 0.0, 0.0];
  //End IMU Data Variables

  //Controls variables
  double _x = 100;
  double _y = 100;
  double joystick_position_x = 0;
  double joystick_position_y = 0;
  double joystick_angle = 0;
  int converted_joystick_angle = 0;
  int joystick_position_x_norm = 0;
  int joystick_position_y_norm = 0;
  JoystickMode _joystickMode = JoystickMode.all;

  bool _buttonAPressed = false;
  Color buttonAColor = Colors.blue;
  //End Controls Variables

  @override
  initState() {
    super.initState();
    _scanSub = _ble.scanForDevices(withServices: []).listen(_onScanUpdate);
  }

  @override
  void dispose() {
    _notifySub?.cancel();
    _connectSub?.cancel();
    _scanSub?.cancel();
    super.dispose();
  }

  void _onScanUpdate(DiscoveredDevice d) {
    if (d.name == 'Arduino_Alvik' && !_found) {
      _found = true;
      _connectSub = _ble.connectToDevice(id: d.id).listen((update) {
        if (update.connectionState == DeviceConnectionState.connected) {
          _onConnected(d.id);
          print('DEVICE CONNECTED');
        }

        if (update.connectionState == DeviceConnectionState.disconnecting ||
            update.connectionState == DeviceConnectionState.disconnected) {
          setState(() {
            _found = false;
          });
        }
      });
    }
  }

  late QualifiedCharacteristic characteristicControls;
  late QualifiedCharacteristic characteristicButtons;
  void _onConnected(String deviceId) {
    characteristicControls = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: Uuid.parse('19b10003-e8f2-537e-4f6c-d104768a1214'),
        characteristicId: Uuid.parse('19b10004-e8f2-537e-4f6c-d104768a1214'));

    characteristicButtons = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: Uuid.parse('19b10003-e8f2-537e-4f6c-d104768a1214'),
        characteristicId: Uuid.parse('19b10005-e8f2-537e-4f6c-d104768a1214'));

    final characteristicAcc = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214'),
        characteristicId: Uuid.parse('19b10001-e8f2-537e-4f6c-d104768a1214'));

    final characteristicGyro = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: Uuid.parse('19b10000-e8f2-537e-4f6c-d104768a1214'),
        characteristicId: Uuid.parse('19b10002-e8f2-537e-4f6c-d104768a1214'));

    _notifySub =
        _ble.subscribeToCharacteristic(characteristicAcc).listen((bytes) {
      setState(() {
        final bytes_conv = Uint8List.fromList(bytes);
        final byteData = ByteData.sublistView(bytes_conv);
        int j = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          acc[j++] = byteData.getFloat32(i, Endian.little);
        }

        _value = bytes.toString();
        //print('VALUE READ IN BLE    $_value');
      });
    });

    _notifySub =
        _ble.subscribeToCharacteristic(characteristicGyro).listen((bytes) {
      setState(() {
        final bytes_conv = Uint8List.fromList(bytes);
        final byteData = ByteData.sublistView(bytes_conv);
        int j = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          gyro[j++] = byteData.getFloat32(i, Endian.little);
        }

        _value = bytes.toString();
        //print('VALUE READ IN BLE    $_value');
      });
    });
  }

  @override
  void didChangeDependencies() {
    _x = MediaQuery.of(context).size.width / 2 - ballSize / 2;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: OrientationBuilder(builder: (context,orientation){
            return orientation == Orientation.portrait ?   screenPortraitMode() : screenLandscapeMode();

        }));  
  }

  Widget screenPortraitMode() {
    return Center(
        child: !_found
            ? Column(
                children: [
                  Text('Searching Device',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  CircularProgressIndicator()
                ],
              )
            : Column(
                children: [
                  Text('IMU Sensors Data',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text('Accelerometer',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Asse X"),
                      SizedBox(width: 50), // give it width
                      Text("Asse Y"),
                      SizedBox(width: 50), // give it width
                      Text("Asse Z"),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(acc[0].toStringAsFixed(2)),
                      SizedBox(width: 50), // give it width
                      Text(acc[1].toStringAsFixed(2)),
                      SizedBox(width: 50), // give it width
                      Text(acc[2].toStringAsFixed(2)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text('Gyroscope',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Asse X"),
                      SizedBox(width: 50), // give it width
                      Text("Asse Y"),
                      SizedBox(width: 50), // give it width
                      Text("Asse Z"),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(gyro[0].toStringAsFixed(2)),
                      SizedBox(width: 50), // give it width
                      Text(gyro[1].toStringAsFixed(2)),
                      SizedBox(width: 50), // give it width
                      Text(gyro[2].toStringAsFixed(2)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text('Alvik Data',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Joystick Position X"),
                      SizedBox(width: 50), // give it width
                      Text("Joystick Position Y"),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(joystick_position_x_norm.toStringAsFixed(2)),
                      SizedBox(width: 50), // give it width
                      Text(joystick_position_y_norm.toStringAsFixed(2)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Angle Calculation For Alvik"),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(converted_joystick_angle.toStringAsFixed(0)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(width: 10),
                      Center(
                          child: SafeArea(
                        child: Stack(
                          children: [
                            //Ball(_x, _y),
                            Align(
                              alignment: const Alignment(0, 0.8),
                              child: Joystick(
                                mode: _joystickMode,
                                period: Duration(milliseconds: 500),
                                listener: (details) {
                                  setState(() {
                                    _x = _x + step * details.x;
                                    _y = _y + step * details.y;
                                    joystick_position_x = details.x;
                                    joystick_position_y = details.y;
                                    joystick_angle = atan2(joystick_position_x,
                                            joystick_position_y) *
                                        (180 / pi);

                                    /*Round angle data*/
                                    converted_joystick_angle =
                                        joystick_angle.round();
                                    joystick_position_x_norm =
                                        (joystick_position_x * 100).round();
                                    joystick_position_y_norm =
                                        (joystick_position_y * 100).round();

                                    /*Create ByteData*/
                                    ByteData bytes = ByteData(6);
                                    bytes.setInt16(0, converted_joystick_angle);
                                    bytes.setInt16(2, joystick_position_x_norm);
                                    bytes.setInt16(4, joystick_position_y_norm);

                                    //if (joystick_position_x != 0 && joystick_position_y != 0)
                                    //{
                                    _ble.writeCharacteristicWithoutResponse(
                                        characteristicControls,
                                        value:
                                            bytes.buffer.asInt8List().toList());
                                    //}
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      )),
                  SizedBox(width: 50),
                      Listener(
                        onPointerDown: (details) {
                          _buttonAPressed = true;
                          buttonAColor = Colors.red;
                          ByteData bytes = ByteData(2);
                          bytes.setInt16(0, 10);
                          _ble.writeCharacteristicWithoutResponse(
                              characteristicButtons,
                              value: bytes.buffer.asInt8List().toList());
                        },
                        onPointerUp: (details) {
                          _buttonAPressed = false;
                          buttonAColor = Colors.blue;
                          ByteData bytes = ByteData(2);
                          bytes.setInt16(0, 0);
                          _ble.writeCharacteristicWithoutResponse(
                              characteristicButtons,
                              value: bytes.buffer.asInt8List().toList());
                        },
                        child: Container(
                          decoration: BoxDecoration(
                              color: buttonAColor,
                              border: Border.all(),
                              shape: BoxShape.circle),
                          padding: EdgeInsets.all(16.0),
                          child: Icon(Icons.adjust),
                        ),
                      ),
                    ],
                  ),
                ],
              )

        /*_value.isEmpty
              ? const CircularProgressIndicator()
              : Text(_value, style: Theme.of(context).textTheme.titleLarge)),*/
        );
  }



  Widget screenLandscapeMode() {
    return Center(
        child: !_found
            ? Column(
                children: [
                  Text('Searching Device',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  CircularProgressIndicator()
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(width: 50),
                  SafeArea(
                    child: Stack(
                      children: [
                        //Ball(_x, _y),
                        Align(
                          alignment: const Alignment(0, 0),
                          child: Joystick(
                            mode: _joystickMode,
                            period: Duration(milliseconds: 500),
                            listener: (details) {
                              setState(() {
                                _x = _x + step * details.x;
                                _y = _y + step * details.y;
                                joystick_position_x = details.x;
                                joystick_position_y = details.y;
                                joystick_angle = atan2(joystick_position_x,
                                        joystick_position_y) *
                                    (180 / pi);

                                /*Round angle data*/
                                converted_joystick_angle =
                                    joystick_angle.round();
                                joystick_position_x_norm =
                                    (joystick_position_x * 100).round();
                                joystick_position_y_norm =
                                    (joystick_position_y * 100).round();

                                /*Create ByteData*/
                                ByteData bytes = ByteData(6);
                                bytes.setInt16(0, converted_joystick_angle);
                                bytes.setInt16(2, joystick_position_x_norm);
                                bytes.setInt16(4, joystick_position_y_norm);

                                //if (joystick_position_x != 0 && joystick_position_y != 0)
                                //{
                                _ble.writeCharacteristicWithoutResponse(
                                    characteristicControls,
                                    value: bytes.buffer.asInt8List().toList());
                                //}
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 50),
                  Column(
                    children: [
                      Text('IMU Sensors Data',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Accelerometer',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Asse X"),
                          SizedBox(width: 50), // give it width
                          Text("Asse Y"),
                          SizedBox(width: 50), // give it width
                          Text("Asse Z"),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(acc[0].toStringAsFixed(2)),
                          SizedBox(width: 50), // give it width
                          Text(acc[1].toStringAsFixed(2)),
                          SizedBox(width: 50), // give it width
                          Text(acc[2].toStringAsFixed(2)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text('Gyroscope',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Asse X"),
                          SizedBox(width: 50), // give it width
                          Text("Asse Y"),
                          SizedBox(width: 50), // give it width
                          Text("Asse Z"),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(gyro[0].toStringAsFixed(2)),
                          SizedBox(width: 50), // give it width
                          Text(gyro[1].toStringAsFixed(2)),
                          SizedBox(width: 50), // give it width
                          Text(gyro[2].toStringAsFixed(2)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text('Alvik Data',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Joystick Position X"),
                          SizedBox(width: 50), // give it width
                          Text("Joystick Position Y"),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(joystick_position_x_norm.toStringAsFixed(2)),
                          SizedBox(width: 50), // give it width
                          Text(joystick_position_y_norm.toStringAsFixed(2)),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Angle Calculation For Alvik"),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(converted_joystick_angle.toStringAsFixed(0)),
                        ],
                      ),
                      SizedBox(height: 2)
                    ],
                  ),
                  SizedBox(width: 50),
                  Listener(
                    onPointerDown: (details) {
                      _buttonAPressed = true;
                      buttonAColor = Colors.red;
                      ByteData bytes = ByteData(2);
                      bytes.setInt16(0, 10);                      
                      _ble.writeCharacteristicWithoutResponse(
                          characteristicButtons,
                          value: bytes.buffer.asInt8List().toList());
                    },
                    onPointerUp: (details) {
                      _buttonAPressed = false;
                      buttonAColor = Colors.blue;
                      ByteData bytes = ByteData(2);
                      bytes.setInt16(0, 0);
                      _ble.writeCharacteristicWithoutResponse(
                          characteristicButtons,
                          value: bytes.buffer.asInt8List().toList());
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          color: buttonAColor, border: Border.all(),
                          shape: BoxShape.circle),
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.adjust),
                    ),
                  ),
                ],
              ));
  }
}

class Ball extends StatelessWidget {
  final double x;
  final double y;

  const Ball(this.x, this.y, {super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: ballSize,
        height: ballSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              spreadRadius: 2,
              blurRadius: 3,
              offset: Offset(0, 3),
            )
          ],
        ),
      ),
    );
  }
}
