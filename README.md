<p align="center">
  <img src="https://i.ibb.co/vzG7C5N/vendix-logo.png" alt="VENDIX Logo" width="120" onerror="this.style.display='none'"/>
</p>

<h1 align="center">✨ VENDIX ✨</h1>

<p align="center">
  <strong>Plataforma Integral de Comercio en Vivo (Live Commerce) y Gestión de Ventas</strong><br>
  Optimizado para transmisiones en vivo, control de prendas, cobros inmediatos y balance de clientas en tiempo real.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firestore" />
  <img src="https://img.shields.io/badge/Google-Sign_In-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Google Sign-In" />
  <img src="https://img.shields.io/badge/Cloudinary-Image_Storage-3448C5?style=for-the-badge&logo=cloudinary&logoColor=white" alt="Cloudinary" />
</p>

---

## 📌 Acerca de VENDIX

**VENDIX** es una solución móvil diseñada específicamente para tiendas de ropa y emprendedores que comercializan sus productos mediante transmisiones en vivo (TikTok Live, Facebook Live, Instagram Live).

Resuelve el caos tradicional de tomar pedidos a mano en libretas o mensajes de chat, sincronizando en **tiempo real** las ventas del live, los abonos y el estado de cuenta de cada clienta directamente con la base de datos de **Firebase Firestore**.

---

## 🚀 Módulos Principales del Sistema

### 👑 1. Módulo Emprendedor / Administrador
* **Gestión de Operadores:** Cada emprendedor aprueba y visualiza a sus propios secretarios (`adminId`).
* **Catálogo Global:** Alta, edición de precios y control de inventario de prendas.
* **Control Centralizado:** Supervisión total de ingresos, métricas y cierres de jornada.

### 💼 2. Módulo Secretario / Operador de Transmisión
* **Código de Acceso para el Live:** Generación automática de códigos únicos (ej. `VX-849`) desde su perfil para compartir en el live.
* **Venta Rápida en Vivo:** Carrito reactivo por clienta para cargar prendas en segundos con un solo toque.
* **Gestión de Clientas:** Registro de nuevas clientas, historial de compras y calculadora de deuda (`Total Comprado - Total Pagado`).
* **Registro de Pagos:** Abonos parciales o totales con cálculo automático de saldos pendientes.
* **Jornadas de Live:** Cronómetro interactivo de apertura, seguimiento y cierre de transmisiones.
* **Estadísticas en Directo:** Gráficas financieras y balance consolidado del día.

### 🛍️ 3. Módulo Cliente
* **Registro Obligatorio con Código:** Para registrarse, la clienta debe ingresar el código emitido por el secretario en la transmisión, garantizando que quede vinculada automáticamente a la tienda del emprendedor.
* **Identidad de Tienda:** Visualización directa de la información del emprendedor (nombre de la tienda, teléfono y contacto).
* **Ficha Financiera:** Visualización clara de su saldo pendiente, prendas adquiridas y abonos recibidos.
* **Autenticación Dual:** Acceso seguro con correo y contraseña o a través de **Google Sign-In**.
* **Foto de Perfil:** Carga y optimización de avatar en la nube mediante Cloudinary.

---

## 🔄 Flujo de Vinculación y Venta en Vivo

```text
       [ Emprendedor (Administrador) ]
                     │
                     ▼ (Aprueba y vincula con adminId)
         [ Secretario / Operador ]
                     │
                     ▼ (Genera código único en su perfil: ej. "VX-849")
             [ Código del Live ]
                     │
                     ▼ (Cliente ingresa el código obligatorio al registrarse)
             [ Cuenta de Cliente ]
                     │
                     ▼ (Queda enlazada automáticamente a la tienda del Emprendedor)
          [ Consultas y Compras en Vivo ]
```

---

## 🛠️ Tecnologías y Librerías Utilizadas

* **Framework:** [Flutter](https://flutter.dev/) (SDK 3.x)
* **Lenguaje:** [Dart](https://dart.dev/) (Null-Safety)
* **Autenticación:** Firebase Auth (Email/Password & Google Identity Service)
* **Base de Datos en Tiempo Real:** Cloud Firestore
* **Almacenamiento de Multimedia:** Cloudinary REST API
* **Estilos:** Material 3 personalizado (`AppTheme` con paleta violeta/rosa pastel)

---

## 📂 Estructura del Proyecto

```text
flutter_application_1/
├── lib/
│   ├── data/                 # Servicios de datos (Prendas)
│   ├── models/               # Modelos tipados (Administrador, Prenda)
│   ├── screens/
│   │   ├── admin/            # Pantallas de administración y gestión de secretarios
│   │   ├── auth/             # Login, registro de cliente y emprendedor
│   │   ├── client/           # Home, saldo, compras y perfil de clienta
│   │   └── secretary/        # Venta rápida, clientas, pagos, jornadas y métricas
│   ├── services/             # Servicios Firebase, Google Auth, Cloudinary
│   ├── theme/                # Paleta de colores, tipografía y estilos globales
│   └── main.dart             # Punto de entrada de la aplicación
├── artefacts/                # Bitácoras arquitectónicas y documentación de ingeniería
└── README.md                 # Esta documentación
```

---

## 💻 Instalación y Configuración Local

### 1. Clonar el repositorio
```bash
git clone https://github.com/DeKiira69/VENDIX.git
cd VENDIX/flutter_application_1
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Ejecutar análisis de calidad
```bash
dart analyze lib/
# Resultado esperado: No issues found! (0 errores)
```

### 4. Ejecutar la aplicación
```bash
flutter run
```

---

## 📄 Licencia y Créditos

Desarrollado para la gestión moderna del comercio digital y transmisiones en vivo.  
**Autor:** [DeKiira69](https://github.com/DeKiira69) & Antigravity AI  
Todos los derechos reservados © 2026.
