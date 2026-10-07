import 'package:control_leaves_web/features/map/data/geocoding_service.dart';
import 'package:control_leaves_web/features/map/models/lat_lng.dart';
import 'package:control_leaves_web/features/map/presentation/location_picker.dart';
import 'package:control_leaves_web/features/premises/data/premise_service.dart';
import 'package:control_leaves_web/features/premises/models/premise.dart';
import 'package:control_leaves_web/features/premises/models/reason.dart';
import 'package:control_leaves_web/features/premises/presentation/premise_form_dialog.dart';
import 'package:control_leaves_web/features/users/data/user_admin_service.dart';
import 'package:control_leaves_web/features/users/models/managed_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePremises implements PremiseService {
  Map<String, dynamic>? saved;
  bool created = false;

  @override
  Future<List<Reason>> getAllReasons() async => [Reason(name: 'Cita médica')];

  @override
  Future<Premise> createPremise({
    required String name,
    required double latitude,
    required double longitude,
    List<String> reasonNames = const [],
    int? managerUserId,
  }) async {
    created = true;
    saved = {'name': name, 'lat': latitude, 'lng': longitude, 'manager': managerUserId, 'reasons': reasonNames};
    return Premise(id: 9, name: name, reasonNames: []);
  }

  @override
  Future<Premise> updatePremise(
    int premiseId, {
    required String name,
    required double latitude,
    required double longitude,
    required List<String> reasonNames,
    required int? managerUserId,
  }) async {
    saved = {'id': premiseId, 'name': name, 'lat': latitude, 'lng': longitude, 'manager': managerUserId, 'reasons': reasonNames};
    return Premise(id: premiseId, name: name, reasonNames: []);
  }

  /// Gestiona metodos no implementados.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUsers implements UserAdminService {
  @override
  Future<List<ManagedUser>> getUsers() async => [
    ManagedUser(id: 7, name: 'Ana Gestora', item: '1', role: AppRole(id: 3, name: 'MANAGE_PREMISE')),
    ManagedUser(id: 8, name: 'Luis Empleado', item: '2', role: AppRole(id: 1, name: 'EMPLOYEE')),
  ];

  /// Gestiona metodos no implementados.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(Widget dialog) => MaterialApp(
  home: Scaffold(body: Builder(builder: (c) => TextButton(
    onPressed: () => showDialog(context: c, builder: (_) => dialog),
    child: const Text('abrir'),
  ))),
);

Future<void> _open(WidgetTester t, Widget dialog) async {
  t.view.physicalSize = const Size(1000, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(_host(dialog));
  await t.tap(find.text('abrir'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _tapMap(WidgetTester t, {double dx = 60}) async {
  await t.tapAt(t.getCenter(find.byType(FlutterMap)) + Offset(dx, 0));
  await t.pump(const Duration(milliseconds: 600)); // espera del doble toque
}

/// Inicia la aplicacion.
void main() {
  testWidgets('un predio nuevo no se guarda hasta tocar el mapa', (t) async {
    final premises = _FakePremises();
    await _open(t, PremiseFormDialog(premiseService: premises, userService: _FakeUsers()));

    expect(find.text('Toca en el mapa el lugar donde está el predio.'), findsOneWidget);
    expect(find.text('Pegar coordenadas o enlace de un mapa'), findsNothing);
    await t.enterText(find.widgetWithText(TextFormField, 'Nombre del predio'), 'Sede');
    await t.tap(find.text('Crear predio'));
    await t.pump();

    expect(premises.created, isFalse);
    expect(find.text('Toca el mapa para fijar la ubicación del predio.'), findsOneWidget);
  });

  testWidgets('tocar el mapa fija el punto, elige responsable y crea', (t) async {
    final premises = _FakePremises();
    await _open(t, PremiseFormDialog(premiseService: premises, userService: _FakeUsers()));

    await t.enterText(find.widgetWithText(TextFormField, 'Nombre del predio'), 'Sede Prado');
    await _tapMap(t);
    expect(find.textContaining('Ubicación fijada'), findsOneWidget);

    await t.tap(find.text('Sin responsable'));
    await t.pump();
    expect(find.text('Ana Gestora'), findsOneWidget);
    expect(find.text('Luis Empleado'), findsNothing);
    await t.tap(find.text('Ana Gestora').last);
    await t.pump();
    await t.tap(find.text('Crear predio'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    expect(premises.saved!['name'], 'Sede Prado');
    expect(premises.saved!['manager'], 7);
    expect(premises.saved!['lng'], greaterThan(-66.1570));
  });

  testWidgets('editar precarga datos y envia una sola actualizacion', (t) async {
    final premises = _FakePremises();
    final premise = Premise(
      id: 4, name: 'Central', reasonNames: [Reason(name: 'Cita médica')],
      latitude: -17.39, longitude: -66.15, manager: const PremiseManager(userId: 7, name: 'Ana Gestora'),
    );
    await _open(t, PremiseFormDialog(premise: premise, premiseService: premises, userService: _FakeUsers()));

    expect(find.text('Editar predio'), findsOneWidget);
    expect(find.textContaining('Ubicación fijada (-17.39000, -66.15000)'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'Nombre del predio'), 'Central 2');
    await t.tap(find.text('Guardar cambios'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    expect(premises.saved, {'id': 4, 'name': 'Central 2', 'lat': -17.39, 'lng': -66.15, 'manager': 7, 'reasons': ['Cita médica']});
  });

  testWidgets('buscar un lugar y usar mi ubicación mueven el marcador', (t) async {
    LatLng? chosen;
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LocationPicker(
            initial: null,
            onChanged: (p) => chosen = p,
            placeSearch: (q) async => [
              PlaceResult(name: 'Plaza 14 de Septiembre', position: const LatLng(-17.3938, -66.1568)),
            ],
            locateMe: () async => const LatLng(-17.5, -66.2),
          ),
        ),
      ),
    ));

    await t.enterText(find.byType(TextField), 'plaza');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.text('Plaza 14 de Septiembre'));
    await t.pump(const Duration(milliseconds: 100));
    expect(chosen, const LatLng(-17.3938, -66.1568));

    await t.tap(find.text('Mi ubicación'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(chosen, const LatLng(-17.5, -66.2));
  });

  testWidgets('si no se puede obtener la ubicación se avisa', (t) async {
    t.view.physicalSize = const Size(1000, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: LocationPicker(initial: null, onChanged: (_) {}, locateMe: () async => null),
      )),
    ));
    await t.tap(find.text('Mi ubicación'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('No se pudo obtener tu ubicación'), findsOneWidget);
  });
}
