import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'device_screen.dart';
import '../utils/snackbar.dart';
import '../widgets/system_device_tile.dart';
import '../widgets/scan_result_tile.dart';
import '../utils/extra.dart';
import '../utils/measurement.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<String, List<Measurement>> _history = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    _history = await MeasurementStorage().getAllMeasurements();
    if (mounted) {
      setState(() {});
    }
  }

  List<Widget> buildHistoryTile(BuildContext context) {
    // Retrieve and print the measurements
    List<ListTile> result = [];

    for (var key in _history.keys) {
      var measurements = _history[key]!;
      for (var m in measurements) {
        result.add(ListTile(
          leading: const Icon(Icons.flare, size: 30, color: Colors.red),
          title:
          Row(
            children: <Widget>[
              Text('${m.value} FPS', style: const TextStyle(fontSize: 30)),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: <Widget>[
                Text('${m.timestamp}'.substring(0, 19), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                Text(key.substring(7), style: const TextStyle(color: Colors.grey, fontSize: 10))
              ],
            ),
          )
        ));
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("History")
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              ...buildHistoryTile(context),
            ],
          ),
        ),
      ),
    );
  }
}
