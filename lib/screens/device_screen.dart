import 'dart:async';

import 'package:caldwell_reader/utils/measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../utils/snackbar.dart';
import '../utils/extra.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  int? _mtuSize;

  String _payload = "";
  int _resultFps = 0;
  DateTime? _resultTime;
  List<Measurement> _resultHistory = [];

  final _storage = MeasurementStorage();

  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;
  late StreamSubscription<dynamic> _meassurementSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        //_services = []; // must rediscover services
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }
      if (state == BluetoothConnectionState.connected) {
        var device = widget.device;
        List<BluetoothService> services = await device.discoverServices();

        BluetoothService meassurementService = services.firstWhere((service) =>
            service.uuid.toString() == '49535343-fe7d-4ae5-8fa9-9fafd205e455');
        BluetoothCharacteristic meassurementCharacteristic =
            meassurementService.characteristics.firstWhere((characteristic) =>
                characteristic.uuid.toString() ==
                '49535343-1e4d-4bd9-ba61-23c647249616');

        _meassurementSubscription =
            meassurementCharacteristic.onValueReceived.listen((value) async {
          _payload = String.fromCharCodes(value);
          _resultFps = int.parse(_payload.split(",")[2]);
          _resultTime = DateTime.now();

          await _storage.addMeasurement(widget.device.remoteId.str, Measurement(value: _resultFps, timestamp: DateTime.now()));
          _resultHistory = (await _storage.getMeasurements(widget.device.remoteId.str)).reversed.toList();

          if (mounted) {
            setState(() {});
          }
        });

        widget.device.cancelWhenDisconnected(_meassurementSubscription);
        await meassurementCharacteristic.setNotifyValue(true);
        _resultHistory = (await _storage.getMeasurements(widget.device.remoteId.str)).reversed.toList();
      }
      if (mounted) {
        setState(() {});
      }
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isDisconnectingSubscription =
        widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    _meassurementSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connectAndUpdateStream();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e) {
      if (e is FlutterBluePlusException &&
          e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
      }
    }
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e),
          success: false);
    }
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223, predelay: 0);
      Snackbar.show(ABC.c, "Request Mtu: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e),
          success: false);
    }
  }

  List<Widget> buildHistoryTile(BuildContext context, String device) {

    // Retrieve and print the measurements
    return _resultHistory.map((m) {
      return ListTile(
        leading: const Icon(Icons.flare, size: 30, color: Colors.red),
        title: Text('${m.value} FPS', style: const TextStyle(fontSize: 30)),
        trailing: Container(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: <Widget>[
                Text('${m.timestamp}'.substring(0, 19), style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          )
      );
    }).toList();
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildSpinner(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildFPSTile(BuildContext context) {
    return ListTile(
        leading: const Icon(Icons.flare, size: 80, color: Colors.red),
        title: Align(
            alignment: Alignment.centerRight,
            child:
                Text("${_resultFps} FPS", style: const TextStyle(fontSize: 70))),
        subtitle: Align(
          alignment: Alignment.centerRight,
          child: Text(
              _resultTime != null ? '$_resultTime'.substring(11, 19) : 'no meassurement yet',
              style: const TextStyle(fontSize: 15, color: Colors.grey)),
        ));
  }

  Widget buildMtuTile(BuildContext context) {
    return ListTile(
        title: const Text('MTU Size'),
        subtitle: Text('$_mtuSize bytes'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onRequestMtuPressed,
        ));
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      if (_isConnecting || _isDisconnecting) buildSpinner(context),
      TextButton(
          onPressed: _isConnecting
              ? onCancelPressed
              : (isConnected ? onDisconnectPressed : onConnectPressed),
          child: Text(_isConnecting
              ? "CANCEL"
              : (isConnected ? "DISCONNECT" : "CONNECT")))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              "${widget.device.platformName} ${widget.device.remoteId.str}"),
          actions: [buildConnectButton(context)],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              buildFPSTile(context),
              const Row(children: <Widget>[
                Expanded(child: Divider(color: Colors.grey)),
                Text(" payload ", style: TextStyle(color: Colors.grey)),
                Expanded(child: Divider(color: Colors.grey)),
              ]),
              Text(_payload),
              const Row(children: <Widget>[
                Expanded(child: Divider(color: Colors.grey)),
                Text(" history ", style: TextStyle(color: Colors.grey)),
                Expanded(child: Divider(color: Colors.grey)),
              ]),
              ...buildHistoryTile(context, widget.device.remoteId.str),
            ],
          ),
        ),
      ),
    );
  }
}
