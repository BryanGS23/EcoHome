import 'package:cloud_firestore/cloud_firestore.dart';

/// One explicitly requested simulated hour per device per UTC day, in Wh.
class EnergyRecord {
  const EnergyRecord({
    required this.id,
    required this.deviceId,
    required this.areaId,
    required this.consumption,
    required this.powerWatts,
    required this.recordedAt,
  });
  final String id, deviceId, areaId;
  final double consumption, powerWatts;
  final DateTime recordedAt;
  static double estimateWh(num watts, num hours) => watts.toDouble() * hours;
  static int dayKey(DateTime date) =>
      date.toUtc().millisecondsSinceEpoch ~/ 86400000;
  factory EnergyRecord.fromMap(String id, Map<String, dynamic> data) {
    if (data['deviceId'] is! String ||
        data['areaId'] is! String ||
        data['consumption'] is! num ||
        data['powerWatts'] is! num ||
        data['durationHours'] != 1 ||
        !(data['consumption'] as num).isFinite ||
        (data['consumption'] as num) < 0 ||
        data['consumption'] != data['powerWatts'] ||
        data['recordedAt'] is! Timestamp) {
      throw const FormatException('Registro energético inválido.');
    }
    return EnergyRecord(
      id: id,
      deviceId: data['deviceId'] as String,
      areaId: data['areaId'] as String,
      consumption: (data['consumption'] as num).toDouble(),
      powerWatts: (data['powerWatts'] as num).toDouble(),
      recordedAt: (data['recordedAt'] as Timestamp).toDate(),
    );
  }
  Map<String, dynamic> toMap() => {
    'deviceId': deviceId,
    'areaId': areaId,
    'consumption': consumption,
    'powerWatts': powerWatts,
    'durationHours': 1,
    'recordedAt': Timestamp.fromDate(recordedAt),
  };
}
