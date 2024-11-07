import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Measurement {
  final int value;
  final DateTime timestamp;

  Measurement({
    required this.value,
    required this.timestamp,
  });

  // Convert Measurement to a JSON-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create a Measurement from a Map
  static Measurement fromMap(Map<String, dynamic> map) {
    return Measurement(
      value: map['value'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class MeasurementStorage {
  static const int maxItems = 100;

  // Save a new measurement for a specific device
  Future<void> addMeasurement(String device, Measurement measurement) async {
    final prefs = await SharedPreferences.getInstance();

    // Retrieve the existing measurements list for the device
    List<Measurement> measurements = await getMeasurements(device);

    // Add the new measurement
    measurements.add(measurement);

    // If the list exceeds the maxItems, remove the oldest entries
    if (measurements.length > maxItems) {

      measurements = measurements.sublist(measurements.length - maxItems);
    }

    // Convert the measurements to JSON and store it
    final List<Map<String, dynamic>> jsonList =
        measurements.map((m) => m.toMap()).toList();
    await prefs.setString("device-$device", json.encode(jsonList));
    await prefs.commit();
  }

  // Retrieve the list of measurements for a specific device
  Future<List<Measurement>> getMeasurements(String device) async {
    final prefs = await SharedPreferences.getInstance();

    // Get the stored JSON string
    final jsonString = prefs.getString("device-$device");

    if (jsonString == null) {
      return []; // Return an empty list if there's no data
    }

    // Parse the JSON string and convert it to a list of Measurement objects
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => Measurement.fromMap(json)).toList();
  }

  Future<Map<String, List<Measurement>>> getAllMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, List<Measurement>> allMeasurements = {};
    for (String key in prefs.getKeys()) {
      if (key.startsWith("device-")) {
        List<Measurement> measurements = (await getMeasurements(key.substring(7))).reversed.toList();
        allMeasurements[key] = measurements;
      }
    }
    return allMeasurements;
  }

  // Clear all measurements for a specific device
  Future<void> clearMeasurements(String device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("device-$device");
  }
}
