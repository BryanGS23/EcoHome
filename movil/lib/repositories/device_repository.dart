import '../models/device.dart';
import '../services/firestore_service.dart';

class DeviceRepository {
  DeviceRepository({FirestoreService? service})
    : _service = service ?? FirestoreService();
  final FirestoreService _service;
  Stream<List<Device>> watchDevices() => _service.watchDevices().map((docs) {
    final devices = docs.entries
        .map((e) => Device.fromMap(e.key, e.value))
        .toList();
    devices.sort((a, b) => a.name.compareTo(b.name));
    return devices;
  });
  Future<void> control(Device device, {bool? enabled, num? value}) {
    if (!device.online ||
        device.type == DeviceType.sensor ||
        (enabled == null && value == null) ||
        (value != null &&
            (!device.type.adjustable || !device.type.acceptsValue(value)))) {
      throw const FormatException(
        'Control no permitido para este dispositivo.',
      );
    }
    return _service.updateDeviceControls(
      device.id,
      enabled: enabled,
      value: value,
    );
  }
}
