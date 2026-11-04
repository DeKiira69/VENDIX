class JornadaDemo {
  String nombre;
  DateTime fecha;
  DateTime? horaInicio;
  DateTime? horaFin;
  String estado; // 'activa', 'cerrada', 'pendiente'

  JornadaDemo({
    required this.nombre,
    required this.fecha,
    this.horaInicio,
    this.horaFin,
    this.estado = 'pendiente',
  });

  bool get estaActiva => estado == 'activa';
  bool get estaCerrada => estado == 'cerrada';
  bool get estaPendiente => estado == 'pendiente';

  String get duracionTexto {
    if (horaInicio == null) return 'Sin iniciar';
    if (horaFin == null) {
      final diff = DateTime.now().difference(horaInicio!);
      final horas = diff.inHours;
      final minutos = diff.inMinutes % 60;
      return '${horas}h ${minutos}m en curso';
    }
    final diff = horaFin!.difference(horaInicio!);
    final horas = diff.inHours;
    final minutos = diff.inMinutes % 60;
    return '${horas}h ${minutos}m';
  }
}

class PrendaDemo {
  String nombre;
  double precio;
  bool activa;

  PrendaDemo(this.nombre, this.precio, {this.activa = true});
}

class CompraDemo {
  final String prendaNombre;
  final double precioUnitario;
  int cantidad;
  final DateTime fecha;

  CompraDemo({
    required this.prendaNombre,
    required this.precioUnitario,
    required this.cantidad,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  double get subtotal => precioUnitario * cantidad;
}

class PagoDemo {
  final double monto;
  final DateTime fecha;
  final String? observacion;

  PagoDemo({required this.monto, DateTime? fecha, this.observacion})
    : fecha = fecha ?? DateTime.now();
}

class ClienteDemo {
  String nombre;
  String telefono;
  String direccion;
  final List<CompraDemo> compras;
  final List<PagoDemo> pagos;

  ClienteDemo({
    required this.nombre,
    required this.telefono,
    this.direccion = '',
    List<CompraDemo>? compras,
    List<PagoDemo>? pagos,
  }) : compras = compras ?? [],
       pagos = pagos ?? [];

  double get totalComprado {
    return compras.fold<double>(0, (total, compra) => total + compra.subtotal);
  }

  double get totalPagado {
    return pagos.fold<double>(0, (total, pago) => total + pago.monto);
  }

  double get deuda {
    final saldo = totalComprado - totalPagado;
    return saldo > 0 ? saldo : 0;
  }

  int get prendas {
    return compras.fold<int>(0, (total, compra) => total + compra.cantidad);
  }

  void agregarCompra(PrendaDemo prenda, int cantidad) {
    if (cantidad <= 0) return;

    compras.add(
      CompraDemo(
        prendaNombre: prenda.nombre,
        precioUnitario: prenda.precio,
        cantidad: cantidad,
      ),
    );
  }

  bool registrarPago(double monto) {
    if (monto <= 0 || monto > deuda + 0.001) {
      return false;
    }

    pagos.add(PagoDemo(monto: monto));
    return true;
  }
}

// Catálogo compartido de prendas.
// Los cambios se reflejarán en las pantallas que usen esta lista.
final List<PrendaDemo> prendasDemo = [
  PrendaDemo('Camiseta', 7),
  PrendaDemo('Blusa', 6),
  PrendaDemo('Pantalón', 8),
  PrendaDemo('Medias', 2),
  PrendaDemo('Vestido', 10),
];

// Datos de ejemplo para probar la aplicación.
// Cada compra conserva el precio que tenía cuando se registró.
final List<ClienteDemo> clientesDemo = [
  ClienteDemo(
    nombre: 'María López',
    telefono: '099 845 2210',
    direccion: 'Dirección pendiente de registrar',
    compras: [
      CompraDemo(prendaNombre: 'Camiseta', precioUnitario: 7, cantidad: 2),
      CompraDemo(prendaNombre: 'Blusa', precioUnitario: 6, cantidad: 1),
      CompraDemo(prendaNombre: 'Pantalón', precioUnitario: 8, cantidad: 3),
      CompraDemo(prendaNombre: 'Medias', precioUnitario: 2, cantidad: 2),
    ],
    pagos: [PagoDemo(monto: 30)],
  ),
  ClienteDemo(
    nombre: 'Ana Pérez',
    telefono: '098 318 4452',
    compras: [
      CompraDemo(prendaNombre: 'Camiseta', precioUnitario: 7, cantidad: 2),
      CompraDemo(prendaNombre: 'Blusa', precioUnitario: 6, cantidad: 1),
      CompraDemo(prendaNombre: 'Pantalón', precioUnitario: 8, cantidad: 1),
    ],
    pagos: [PagoDemo(monto: 28)],
  ),
  ClienteDemo(
    nombre: 'Carla Torres',
    telefono: '096 225 9912',
    compras: [
      CompraDemo(prendaNombre: 'Blusa', precioUnitario: 6, cantidad: 3),
      CompraDemo(prendaNombre: 'Pantalón', precioUnitario: 8, cantidad: 3),
      CompraDemo(prendaNombre: 'Medias', precioUnitario: 2, cantidad: 1),
      CompraDemo(prendaNombre: 'Vestido', precioUnitario: 10, cantidad: 1),
    ],
    pagos: [PagoDemo(monto: 20)],
  ),
  ClienteDemo(
    nombre: 'Sofía Mendoza',
    telefono: '099 741 3288',
    compras: [
      CompraDemo(prendaNombre: 'Camiseta', precioUnitario: 7, cantidad: 1),
      CompraDemo(prendaNombre: 'Pantalón', precioUnitario: 8, cantidad: 1),
      CompraDemo(prendaNombre: 'Vestido', precioUnitario: 10, cantidad: 1),
    ],
    pagos: [PagoDemo(monto: 15)],
  ),
  ClienteDemo(
    nombre: 'Paola Castro',
    telefono: '097 556 7021',
    compras: [
      CompraDemo(prendaNombre: 'Camiseta', precioUnitario: 7, cantidad: 3),
      CompraDemo(prendaNombre: 'Medias', precioUnitario: 2, cantidad: 2),
      CompraDemo(prendaNombre: 'Vestido', precioUnitario: 10, cantidad: 1),
    ],
    pagos: [PagoDemo(monto: 15)],
  ),
];


// Jornadas de ejemplo para probar la gestión de lives.
final List<JornadaDemo> jornadasDemo = [
  JornadaDemo(
    nombre: 'Live Viernes de Ofertas',
    fecha: DateTime.now(),
    horaInicio: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
    estado: 'activa',
  ),
  JornadaDemo(
    nombre: 'Live Colección Nueva',
    fecha: DateTime.now().subtract(const Duration(days: 2)),
    horaInicio: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
    horaFin: DateTime.now().subtract(const Duration(days: 2, hours: 2)),
    estado: 'cerrada',
  ),
  JornadaDemo(
    nombre: 'Live Liquidación Temporada',
    fecha: DateTime.now().subtract(const Duration(days: 5)),
    horaInicio: DateTime.now().subtract(const Duration(days: 5, hours: 6)),
    horaFin: DateTime.now().subtract(const Duration(days: 5, hours: 3)),
    estado: 'cerrada',
  ),
  JornadaDemo(
    nombre: 'Live Ropa Deportiva',
    fecha: DateTime.now().subtract(const Duration(days: 8)),
    horaInicio: DateTime.now().subtract(const Duration(days: 8, hours: 4)),
    horaFin: DateTime.now().subtract(const Duration(days: 8, hours: 1, minutes: 30)),
    estado: 'cerrada',
  ),
];
