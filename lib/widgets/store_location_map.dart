import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart' as geo;

import '../secrets.dart';

const String kMapboxAccessToken = String.fromEnvironment(
  'ACCESS_TOKEN',
  defaultValue: AppSecrets.mapboxAccessToken,
);

class StoreLocation {
  final double latitude;
  final double longitude;
  final String? address;

  const StoreLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });
}

class StoreLocationPickerPage extends StatefulWidget {
  final StoreLocation? initialLocation;
  final String queryAddress;
  final String title;

  const StoreLocationPickerPage({
    super.key,
    this.initialLocation,
    this.queryAddress = '',
    this.title = 'Ubicación en el mapa',
  });

  static Future<StoreLocation?> show(
    BuildContext context, {
    StoreLocation? initialLocation,
    String queryAddress = '',
    String title = 'Ubicación en el mapa',
  }) {
    return Navigator.of(context).push<StoreLocation>(
      MaterialPageRoute(
        builder: (_) => StoreLocationPickerPage(
          initialLocation: initialLocation,
          queryAddress: queryAddress,
          title: title,
        ),
      ),
    );
  }

  @override
  State<StoreLocationPickerPage> createState() =>
      _StoreLocationPickerPageState();
}

class _StoreLocationPickerPageState extends State<StoreLocationPickerPage> {
  static const _violeta = Color(0xFF6C4AB6);
  MapboxMap? _map;
  bool _listo = false;
  bool _buscandoDireccion = false;
  bool _resolviendoDireccion = false;
  bool _obteniendoGps = false;
  String? _mensajeDireccion;
  late final TextEditingController _busquedaController;

  @override
  void initState() {
    super.initState();
    _busquedaController = TextEditingController(text: widget.queryAddress);
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap map) {
    setState(() {
      _map = map;
      _listo = true;
    });

    final direccion = widget.queryAddress.trim();
    if (direccion.isNotEmpty) {
      _buscarDireccion(direccion);
    } else if (widget.initialLocation != null) {
      _map?.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(
              widget.initialLocation!.longitude,
              widget.initialLocation!.latitude,
            ),
          ),
          zoom: 16,
        ),
      );
    } else {
      // Si no hay dirección previa ni ubicación inicial, solicitar permiso y ubicar por GPS en tiempo real
      _obtenerUbicacionActualGPS(animarCamara: true, mostrarFeedback: true);
    }
  }

  /// Solicita permisos de ubicación y obtiene la posición GPS en tiempo real
  Future<void> _obtenerUbicacionActualGPS({
    bool animarCamara = true,
    bool mostrarFeedback = true,
  }) async {
    if (_obteniendoGps) return;

    setState(() {
      _obteniendoGps = true;
      if (mostrarFeedback) {
        _mensajeDireccion = 'Solicitando permiso y detectando tu ubicación actual (GPS)…';
      }
    });

    try {
      final servicioHabilitado = await geo.Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        if (mounted) {
          setState(() {
            _obteniendoGps = false;
            _mensajeDireccion =
                'El servicio GPS está desactivado. Actívalo para ubicarte automáticamente.';
          });
          if (mostrarFeedback) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'El servicio de ubicación (GPS) está apagado en tu teléfono.',
                ),
              ),
            );
          }
        }
        return;
      }

      geo.LocationPermission permiso = await geo.Geolocator.checkPermission();
      if (permiso == geo.LocationPermission.denied) {
        permiso = await geo.Geolocator.requestPermission();
        if (permiso == geo.LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _obteniendoGps = false;
              _mensajeDireccion =
                  'Permiso de ubicación denegado. Puedes mover el mapa manualmente o buscar por dirección.';
            });
          }
          return;
        }
      }

      if (permiso == geo.LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _obteniendoGps = false;
            _mensajeDireccion =
                'Permiso de ubicación denegado en Ajustes. Puedes mover el mapa manualmente.';
          });
        }
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (_map != null && animarCamara) {
        await _map?.setCamera(
          CameraOptions(
            center: Point(
              coordinates: Position(position.longitude, position.latitude),
            ),
            zoom: 16.5,
          ),
        );
      }

      final direccionDetectada = await _obtenerNombreDireccion(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (mounted) {
        setState(() {
          _busquedaController.text = direccionDetectada;
          _mensajeDireccion = '📍 Ubicación GPS detectada: $direccionDetectada';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensajeDireccion =
              'No se pudo obtener el GPS actual. Puedes mover el marcador en el mapa.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _obteniendoGps = false);
      }
    }
  }

  Future<void> _buscarDireccion(String direccion) async {
    final token = kMapboxAccessToken;
    if (token.isEmpty || _map == null) return;

    setState(() {
      _buscandoDireccion = true;
      _mensajeDireccion = 'Buscando la dirección…';
    });

    try {
      double? longitude;
      double? latitude;

      // 1. Intentar con Mapbox Geocoding v6 (sin permanent: true)
      try {
        final uriV6 = Uri.https(
          'api.mapbox.com',
          '/search/geocode/v6/forward',
          {
            'q': '$direccion, Riobamba, Ecuador',
            'access_token': token,
            'country': 'EC',
            'language': 'es',
            'limit': '1',
            'proximity': '-78.65887,-1.66506',
          },
        );
        final response = await http.get(uriV6);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>? ?? const [];
          if (features.isNotEmpty) {
            final feature = features.first as Map<String, dynamic>;
            final geometry = feature['geometry'] as Map<String, dynamic>;
            final coordinates = geometry['coordinates'] as List<dynamic>;
            longitude = (coordinates[0] as num).toDouble();
            latitude = (coordinates[1] as num).toDouble();
          }
        }
      } catch (_) {}

      // 2. Fallback con Mapbox Geocoding v5
      if (longitude == null || latitude == null) {
        try {
          final query = Uri.encodeComponent('$direccion, Riobamba, Ecuador');
          final uriV5 = Uri.https(
            'api.mapbox.com',
            '/geocoding/v5/mapbox.places/$query.json',
            {
              'access_token': token,
              'country': 'EC',
              'language': 'es',
              'limit': '1',
              'proximity': '-78.65887,-1.66506',
            },
          );
          final responseV5 = await http.get(uriV5);
          if (responseV5.statusCode == 200) {
            final data = jsonDecode(responseV5.body) as Map<String, dynamic>;
            final features = data['features'] as List<dynamic>? ?? const [];
            if (features.isNotEmpty) {
              final center =
                  (features.first as Map<String, dynamic>)['center']
                      as List<dynamic>;
              longitude = (center[0] as num).toDouble();
              latitude = (center[1] as num).toDouble();
            }
          }
        } catch (_) {}
      }

      if (longitude == null || latitude == null) {
        if (mounted) {
          setState(
            () => _mensajeDireccion = 'No encontramos esa dirección exacta. Puedes mover el marcador en el mapa.',
          );
        }
        return;
      }

      await _map?.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(longitude, latitude)),
          zoom: 16,
        ),
      );
      if (mounted) {
        setState(
          () => _mensajeDireccion =
              'Ubicación encontrada. Puedes ajustar el marcador si lo deseas.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _mensajeDireccion =
              'Puedes mover el mapa manualmente para situar el marcador.',
        );
      }
    } finally {
      if (mounted) setState(() => _buscandoDireccion = false);
    }
  }

  Future<String> _obtenerNombreDireccion({
    required double latitude,
    required double longitude,
  }) async {
    final token = kMapboxAccessToken;

    // 1. Intentar con Mapbox Geocoding v6 (sin 'permanent: true')
    if (token.isNotEmpty) {
      try {
        final uriV6 = Uri.https(
          'api.mapbox.com',
          '/search/geocode/v6/reverse',
          {
            'longitude': longitude.toString(),
            'latitude': latitude.toString(),
            'access_token': token,
            'country': 'EC',
            'language': 'es',
          },
        );
        final responseV6 = await http
            .get(uriV6)
            .timeout(const Duration(seconds: 4));
        if (responseV6.statusCode == 200) {
          final data = jsonDecode(responseV6.body) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>? ?? const [];
          if (features.isNotEmpty) {
            final feature = features.first as Map<String, dynamic>;
            final properties =
                feature['properties'] as Map<String, dynamic>? ?? {};
            final fullAddress = properties['full_address']?.toString().trim();
            if (fullAddress != null && fullAddress.isNotEmpty) {
              return fullAddress;
            }

            final name = properties['name']?.toString().trim() ?? '';
            final place =
                properties['place_formatted']?.toString().trim() ?? '';
            if (name.isNotEmpty && place.isNotEmpty) return '$name, $place';
            if (name.isNotEmpty) return name;
            if (place.isNotEmpty) return place;
          }
        }
      } catch (_) {}

      // 2. Fallback con Mapbox Geocoding v5
      try {
        final uriV5 = Uri.https(
          'api.mapbox.com',
          '/geocoding/v5/mapbox.places/$longitude,$latitude.json',
          {
            'access_token': token,
            'country': 'EC',
            'language': 'es',
            'limit': '1',
          },
        );
        final responseV5 = await http
            .get(uriV5)
            .timeout(const Duration(seconds: 4));
        if (responseV5.statusCode == 200) {
          final data = jsonDecode(responseV5.body) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>? ?? const [];
          if (features.isNotEmpty) {
            final first = features.first as Map<String, dynamic>;
            final placeName = first['place_name']?.toString().trim();
            if (placeName != null && placeName.isNotEmpty) return placeName;
            final text = first['text']?.toString().trim();
            if (text != null && text.isNotEmpty) return text;
          }
        }
      } catch (_) {}
    }

    // 3. Fallback con OpenStreetMap Nominatim
    try {
      final uriOSM = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'es',
      });
      final responseOSM = await http
          .get(uriOSM, headers: {'User-Agent': 'VendixApp/1.0 (flutter)'})
          .timeout(const Duration(seconds: 4));
      if (responseOSM.statusCode == 200) {
        final data = jsonDecode(responseOSM.body) as Map<String, dynamic>;
        final displayName = data['display_name']?.toString().trim();
        if (displayName != null && displayName.isNotEmpty) {
          // Extraer las primeras partes más relevantes
          final partes = displayName.split(',').map((p) => p.trim()).toList();
          if (partes.length >= 3) {
            return '${partes[0]}, ${partes[1]}, ${partes[2]}';
          }
          return displayName;
        }
      }
    } catch (_) {}

    // 4. Si ningún servicio externo respondió, retornar ubicación con coordenadas legibles
    return 'Ubicación (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
  }

  @override
  Widget build(BuildContext context) {
    // Centro aproximado de Riobamba; el emprendedor mueve el mapa hasta su tienda.
    final initial =
        widget.initialLocation ??
        const StoreLocation(latitude: -1.66506, longitude: -78.65887);
    final hasToken = kMapboxAccessToken.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        foregroundColor: _violeta,
        actions: [
          IconButton(
            icon: _obteniendoGps
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _violeta,
                    ),
                  )
                : const Icon(Icons.my_location_rounded),
            tooltip: 'Detectar mi ubicación GPS actual',
            onPressed: _obteniendoGps
                ? null
                : () => _obtenerUbicacionActualGPS(
                      animarCamara: true,
                      mostrarFeedback: true,
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextField(
              controller: _busquedaController,
              textInputAction: TextInputAction.search,
              onSubmitted: (texto) {
                if (texto.trim().isNotEmpty) {
                  _buscarDireccion(texto.trim());
                }
              },
              decoration: InputDecoration(
                hintText: 'Buscar dirección, calle o referencia…',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 20, color: _violeta),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_busquedaController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _busquedaController.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      tooltip: 'Buscar dirección',
                      icon: const Icon(Icons.arrow_forward_rounded, color: _violeta),
                      onPressed: () {
                        if (_busquedaController.text.trim().isNotEmpty) {
                          _buscarDireccion(_busquedaController.text.trim());
                        }
                      },
                    ),
                  ],
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5DCF5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5DCF5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _violeta, width: 1.5),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'Usa el GPS en tiempo real, busca una dirección o mueve el mapa para posicionar el pin en la entrada de la tienda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
          Expanded(
            child: hasToken
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      MapWidget(
                        key: const ValueKey('store-location-picker-map'),
                        viewport: CameraViewportState(
                          center: Point(
                            coordinates: Position(
                              initial.longitude,
                              initial.latitude,
                            ),
                          ),
                          zoom: 15,
                        ),
                        onMapCreated: _onMapCreated,
                      ),
                      const IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 30),
                          child: Icon(
                            Icons.location_on,
                            color: _violeta,
                            size: 48,
                            shadows: [
                              Shadow(color: Colors.white, blurRadius: 5),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'fab_gps_picker_${identityHashCode(this)}',
                          backgroundColor: Colors.white,
                          foregroundColor: _violeta,
                          elevation: 3,
                          tooltip: 'Mi ubicación actual (GPS en tiempo real)',
                          onPressed: _obteniendoGps
                              ? null
                              : () => _obtenerUbicacionActualGPS(
                                    animarCamara: true,
                                    mostrarFeedback: true,
                                  ),
                          child: _obteniendoGps
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _violeta,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded, size: 20),
                        ),
                      ),
                      if (!_listo)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Falta configurar el token de Mapbox para cargar el mapa.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
          if (_buscandoDireccion || _obteniendoGps || _mensajeDireccion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  if (_buscandoDireccion || _obteniendoGps) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _mensajeDireccion ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _map == null || _resolviendoDireccion
                      ? null
                      : () async {
                          setState(() => _resolviendoDireccion = true);
                          final camera = await _map!.getCameraState();
                          final position = camera.center.coordinates;
                          String? address;
                          try {
                            address = await _obtenerNombreDireccion(
                              latitude: position.lat.toDouble(),
                              longitude: position.lng.toDouble(),
                            );
                          } catch (_) {}
                          address ??=
                              'Ubicación (${position.lat.toDouble().toStringAsFixed(5)}, ${position.lng.toDouble().toStringAsFixed(5)})';
                          if (!context.mounted) return;
                          Navigator.pop(
                            context,
                            StoreLocation(
                              latitude: position.lat.toDouble(),
                              longitude: position.lng.toDouble(),
                              address: address,
                            ),
                          );
                        },
                  icon: _resolviendoDireccion
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _resolviendoDireccion
                        ? 'Obteniendo dirección…'
                        : 'Usar esta ubicación',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _violeta,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreLocationPreview extends StatefulWidget {
  final double latitude;
  final double longitude;
  final double height;

  const StoreLocationPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 190,
  });

  @override
  State<StoreLocationPreview> createState() => _StoreLocationPreviewState();
}

class _StoreLocationPreviewState extends State<StoreLocationPreview> {
  static const _sourceId = 'store-location-preview-source';
  static const _layerId = 'store-location-preview-layer';
  static const _iconId = 'store-location-preview-pin';
  MapboxMap? _map;

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.gestures.updateSettings(
      GesturesSettings(
        scrollEnabled: true,
        pinchToZoomEnabled: true,
        doubleTapToZoomInEnabled: true,
        quickZoomEnabled: true,
        scrollZoomEnabled: true,
        rotateEnabled: false,
        pitchEnabled: false,
        pitchWithRotateEnabled: false,
      ),
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _map;
    if (map == null) return;

    final feature = {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [widget.longitude, widget.latitude],
      },
      'properties': <String, dynamic>{},
    };
    final data = jsonEncode({
      'type': 'FeatureCollection',
      'features': [feature],
    });

    try {
      final pin = await _crearIconoUbicacion();
      await map.addImage(_iconId, 1, pin);
      await map.addSource(GeoJsonSource(id: _sourceId, data: data));
      await map.addLayer(
        SymbolLayer(
          id: _layerId,
          sourceId: _sourceId,
          slot: 'top',
          iconImage: _iconId,
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: 0.85,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
      );
    } catch (_) {
      // Al recargar un estilo, Mapbox vuelve a disparar este evento;
      // el siguiente evento volverá a registrar el punto si hace falta.
    }
  }

  Future<StyleImage> _crearIconoUbicacion() async {
    const width = 48.0;
    const height = 58.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final pin = Path()
      ..moveTo(width / 2, height - 1)
      ..cubicTo(20, 48, 3, 31, 3, 20)
      ..cubicTo(3, 9, 12, 1, width / 2, 1)
      ..cubicTo(36, 1, 45, 9, 45, 20)
      ..cubicTo(45, 31, 28, 48, width / 2, height - 1)
      ..close();
    canvas.drawPath(
      pin,
      Paint()
        ..color = const Color(0xFF6C4AB6)
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      const Offset(width / 2, 20),
      7,
      Paint()
        ..color = Colors.white
        ..isAntiAlias = true,
    );
    final image = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );
    try {
      return await StyleImage.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kMapboxAccessToken.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: MapWidget(
          key: ValueKey('store-preview-${widget.latitude}-${widget.longitude}'),
          viewport: CameraViewportState(
            center: Point(
              coordinates: Position(widget.longitude, widget.latitude),
            ),
            zoom: 15,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
      ),
    );
  }
}

/// Campo de dirección con acceso al selector del mapa.
/// Actualiza el texto y devuelve las coordenadas elegidas al formulario dueño.
class StoreLocationAddressField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final StoreLocation? initialLocation;
  final ValueChanged<StoreLocation> onLocationSelected;
  final FormFieldValidator<String>? validator;
  final String mapTitle;

  const StoreLocationAddressField({
    super.key,
    required this.controller,
    required this.decoration,
    required this.onLocationSelected,
    this.initialLocation,
    this.validator,
    this.mapTitle = 'Ubicación de la tienda',
  });

  @override
  State<StoreLocationAddressField> createState() =>
      _StoreLocationAddressFieldState();
}

class _StoreLocationAddressFieldState extends State<StoreLocationAddressField> {
  late StoreLocation? _location = widget.initialLocation;
  bool _openingMap = false;

  Future<void> _selectOnMap() async {
    if (_openingMap) return;
    setState(() => _openingMap = true);
    try {
      final selected = await StoreLocationPickerPage.show(
        context,
        initialLocation: _location,
        queryAddress: widget.controller.text.trim(),
        title: widget.mapTitle,
      );
      if (selected == null || !mounted) return;

      _location = selected;
      final address = selected.address?.trim();
      if (address != null && address.isNotEmpty) {
        widget.controller.value = TextEditingValue(
          text: address,
          selection: TextSelection.collapsed(offset: address.length),
        );
      }
      widget.onLocationSelected(selected);
      setState(() {});
    } finally {
      if (mounted) setState(() => _openingMap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      textCapitalization: TextCapitalization.sentences,
      validator: widget.validator,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          tooltip: 'Seleccionar ubicación en el mapa',
          onPressed: _openingMap ? null : _selectOnMap,
          icon: _openingMap
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.map_outlined, color: Color(0xFF6C4AB6)),
        ),
      ),
    );
  }
}
