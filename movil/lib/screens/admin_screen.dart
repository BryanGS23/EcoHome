import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/app_user.dart';
import '../providers/admin_provider.dart';
import '../providers/user_provider.dart';
import '../repositories/admin_repository.dart';

const _entityLabels = {
  'users': 'perfil',
  'areas': 'área',
  'devices': 'dispositivo',
  'scenes': 'escena',
};

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.user,
    required this.onBack,
    this.repository,
  });
  final UserProvider user;
  final VoidCallback onBack;
  final AdminRepository? repository;
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminProvider admin = AdminProvider(
    user: widget.user,
    repository: widget.repository ?? AdminRepository(),
  );
  String section = 'users';
  static const labels = {
    'users': 'Usuarios',
    'areas': 'Áreas',
    'devices': 'Dispositivos',
    'scenes': 'Escenas',
    'activity': 'Actividad global',
  };
  @override
  void dispose() {
    admin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: admin,
    builder: (context, _) {
      if (!admin.allowed) {
        return Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: widget.onBack)),
          body: const Center(child: Text('Acceso administrativo revocado.')),
        );
      }
      final rows = admin.data[section];
      return Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          leading: BackButton(onPressed: widget.onBack),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final e in labels.entries)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: section == e.key,
                        onSelected: admin.busy
                            ? null
                            : (_) => setState(() => section = e.key),
                      ),
                    ),
                ],
              ),
            ),
            if (admin.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  admin.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (admin.busy) const LinearProgressIndicator(),
            if (!['users', 'activity'].contains(section))
              FilledButton.icon(
                onPressed: admin.busy ? null : () => _edit(null, {}),
                icon: const Icon(Icons.add),
                label: Text('Crear ${_entityLabels[section]}'),
              ),
            Expanded(
              child: rows == null
                  ? const Center(child: CircularProgressIndicator())
                  : rows.isEmpty
                  ? const Center(child: Text('Sin registros.'))
                  : ListView(
                      children: [
                        for (final e in rows.entries) _row(e.key, e.value),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
  Widget _row(String id, Map<String, dynamic> d) {
    final date = (d['createdAt'] as Timestamp?)?.toDate().toLocal();
    final subtitle = switch (section) {
      'users' =>
        '${d['email']}\n${d['role']} · ${d['active'] == true ? 'Activo' : 'Inactivo'}',
      'devices' =>
        '${d['type']} · ${admin.data['areas']?[d['areaId']]?['name'] ?? d['areaId']} · ${d['energyConsumption']} W',
      'scenes' =>
        '${d['enabled'] == true ? 'Habilitada' : 'Deshabilitada'} · ${(d['actions'] as List).length} acciones',
      'activity' => '${d['userId']} · ${d['entityType']}\n$date',
      _ => id,
    };
    return Card(
      child: ListTile(
        title: Text('${d['name'] ?? d['description']}'),
        subtitle: Text(subtitle),
        isThreeLine: section == 'users' || section == 'activity',
        trailing: section == 'activity'
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    onPressed:
                        admin.busy ||
                            (section == 'users' && id == widget.user.uid)
                        ? null
                        : () => _edit(id, d),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (section != 'users')
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: admin.busy ? null : () => _delete(id, d),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _delete(String id, Map<String, dynamic> data) async {
    final collection = section;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: admin,
        builder: (context, _) => AlertDialog(
          title: Text(
            admin.allowed ? 'Eliminar ${data['name']}' : 'Acceso revocado',
          ),
          content: const Text(
            'Se comprobarán las referencias antes de eliminar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: admin.allowed
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
    if (yes == true) await admin.save(collection, id, null);
  }

  Future<void> _edit(String? id, Map<String, dynamic> data) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          _Editor(admin: admin, collection: section, id: id, initial: data),
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.admin,
    required this.collection,
    required this.id,
    required this.initial,
  });
  final AdminProvider admin;
  final String collection;
  final String? id;
  final Map<String, dynamic> initial;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.initial['name'] as String? ?? '',
  );
  late final power = TextEditingController(
    text: '${widget.initial['energyConsumption'] ?? 0}',
  );
  late final value = TextEditingController(
    text: '${widget.initial['value'] ?? 0}',
  );
  late String type = widget.initial['type'] as String? ?? 'light';
  late String? area = widget.initial['areaId'] as String?;
  late String role = widget.initial['role'] as String? ?? 'user';
  late bool enabled = widget.initial['enabled'] as bool? ?? true;
  late bool online = widget.initial['online'] as bool? ?? true;
  late bool active = widget.initial['active'] as bool? ?? true;
  late final actions = <String, Map<String, dynamic>>{
    for (final a in widget.initial['actions'] as List? ?? [])
      a['deviceId'] as String: Map<String, dynamic>.from(a),
  };
  @override
  void dispose() {
    name.dispose();
    power.dispose();
    value.dispose();
    super.dispose();
  }

  Widget field(
    String label,
    TextEditingController controller, {
    bool numeric = false,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true, signed: true)
        : TextInputType.text,
    validator: numeric
        ? (s) =>
              num.tryParse(s ?? '')?.isFinite == true ? null : 'Número inválido'
        : AppUser.validateName,
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.admin,
    builder: (context, _) {
      final allowed = widget.admin.allowed;
      return AlertDialog(
        title: Text(
          allowed
              ? '${widget.id == null ? 'Crear' : 'Editar'} ${_entityLabels[widget.collection]}'
              : 'Acceso revocado',
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: !allowed
                ? const Text('Cierra esta ventana.')
                : Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.collection != 'users') field('Nombre', name),
                        if (widget.collection == 'users') ...[
                          Text(
                            '${widget.initial['name']} · ${widget.initial['email']}',
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: role,
                            items: [
                              for (final r in ['user', 'admin'])
                                DropdownMenuItem(value: r, child: Text(r)),
                            ],
                            onChanged: (s) => role = s!,
                            decoration: const InputDecoration(labelText: 'Rol'),
                          ),
                          SwitchListTile(
                            title: const Text('Cuenta activa'),
                            value: active,
                            onChanged: (s) => setState(() => active = s),
                          ),
                        ],
                        if (widget.collection == 'devices') ...[
                          DropdownButtonFormField<String>(
                            initialValue: type,
                            items: [
                              for (final t in DeviceType.values)
                                DropdownMenuItem(
                                  value: t.name,
                                  child: Text(t.label),
                                ),
                            ],
                            onChanged: (s) => setState(() {
                              type = s!;
                              value.text =
                                  '${DeviceType.values.byName(type).minimum}';
                            }),
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                            ),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue:
                                widget.admin.data['areas']?.containsKey(area) ==
                                    true
                                ? area
                                : null,
                            items: [
                              for (final e
                                  in widget.admin.data['areas']?.entries ??
                                      <
                                        MapEntry<String, Map<String, dynamic>>
                                      >[])
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text('${e.value['name']}'),
                                ),
                            ],
                            onChanged: (s) => area = s,
                            validator: (s) =>
                                s == null ? 'Selecciona un área' : null,
                            decoration: const InputDecoration(
                              labelText: 'Área',
                            ),
                          ),
                          field('Consumo (W)', power, numeric: true),
                          field('Valor', value, numeric: true),
                          SwitchListTile(
                            title: const Text('En línea'),
                            value: online,
                            onChanged: (s) => setState(() => online = s),
                          ),
                        ],
                        if (['devices', 'scenes'].contains(widget.collection))
                          SwitchListTile(
                            title: const Text('Habilitado'),
                            value: enabled,
                            onChanged: (s) => setState(() => enabled = s),
                          ),
                        if (widget.collection == 'scenes') ...[
                          const Text(
                            'Selecciona entre 1 y 20 dispositivos. El valor es opcional.',
                          ),
                          for (final e
                              in widget.admin.data['devices']?.entries ??
                                  <MapEntry<String, Map<String, dynamic>>>[])
                            if (e.value['type'] != 'sensor')
                              Column(
                                children: [
                                  CheckboxListTile(
                                    title: Text('${e.value['name']}'),
                                    value: actions.containsKey(e.key),
                                    onChanged: (yes) => setState(() {
                                      if (yes == true) {
                                        actions[e.key] = {
                                          'deviceId': e.key,
                                          'enabled': true,
                                        };
                                      } else {
                                        actions.remove(e.key);
                                      }
                                    }),
                                  ),
                                  if (actions.containsKey(e.key)) ...[
                                    SwitchListTile(
                                      title: const Text('Encender / activar'),
                                      value: actions[e.key]!['enabled'] as bool,
                                      onChanged: (s) => setState(
                                        () => actions[e.key]!['enabled'] = s,
                                      ),
                                    ),
                                    if (DeviceType.values
                                        .byName(e.value['type'])
                                        .adjustable)
                                      TextFormField(
                                        key: ValueKey('action-${e.key}'),
                                        initialValue:
                                            actions[e.key]!['value']
                                                ?.toString() ??
                                            '',
                                        decoration: const InputDecoration(
                                          labelText: 'Valor opcional',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (s) {
                                          if (s.trim().isEmpty) {
                                            actions[e.key]!.remove('value');
                                          } else {
                                            actions[e.key]!['value'] =
                                                num.tryParse(s) ?? double.nan;
                                          }
                                        },
                                        validator: (s) =>
                                            s == null ||
                                                s.isEmpty ||
                                                num.tryParse(s)?.isFinite ==
                                                    true
                                            ? null
                                            : 'Número inválido',
                                      ),
                                  ],
                                ],
                              ),
                        ],
                        if (widget.admin.error != null)
                          Text(widget.admin.error!),
                      ],
                    ),
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.admin.busy ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: !allowed || widget.admin.busy ? null : _save,
            child: Text(widget.admin.busy ? 'Guardando…' : 'Guardar'),
          ),
        ],
      );
    },
  );
  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    final data = <String, dynamic>{
      if (widget.collection != 'users') 'name': name.text.trim(),
    };
    switch (widget.collection) {
      case 'users':
        data.addAll({'role': role, 'active': active});
      case 'devices':
        data.addAll({
          'type': type,
          'areaId': area,
          'energyConsumption': num.parse(power.text),
          'value': num.parse(value.text),
          'enabled': enabled,
          'online': online,
        });
      case 'scenes':
        data.addAll({'enabled': enabled, 'actions': actions.values.toList()});
    }
    if (await widget.admin.save(widget.collection, widget.id, data) &&
        mounted) {
      Navigator.pop(context);
    }
  }
}
