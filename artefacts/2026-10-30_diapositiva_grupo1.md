# GRUPO 1: AVANCE DEL PROYECTO VENDIX

- **Proyecto:** VENDIX — Gestión de Ventas en Vivo (Live Shopping)
- **Editor:** Susan Segura
- **Fecha:** 30 de octubre de 2026
- **Documento:** Guion de exposición
- **Equipo:** Ayala Ximena · Batallas Cristhian · Cevallos Henry · Segura Susan

---

## 1. ÍNDICE
1. Planteamiento del problema.
2. Tema del proyecto.
3. Propuesta de solución.
4. Objetivo general y objetivos específicos.
5. Requerimientos funcionales.
6. Requerimientos no funcionales.
7. Tecnologías a usar.
8. Metodología de desarrollo.
9. Arquitectura de la aplicación.
10. Prototipo de la aplicación en Figma.
11. Modelo de la base de datos.

---

## 2. PLANTEAMIENTO DEL PROBLEMA
> *"La transmisión termina, pero el trabajo apenas comienza..."*

Las ventas mediante transmisiones en vivo generan una gran carga administrativa para los pequeños emprendimientos, ya que el registro de pedidos, el control de productos, el cálculo del total y el envío de saldos se realizan de forma manual.

Esta situación obliga al secretario a dedicar varias horas adicionales, incluso hasta la madrugada, aumentando el cansancio y el riesgo de errores que pueden generar reclamos y afectar la confianza de las clientas. La falta de automatización dificulta gestionar las ventas de manera rápida, organizada y eficiente.

---

## 3. TEMA DEL PROYECTO
### VENDIX
**Desarrollo de una aplicación móvil mediante Flutter para la automatización de gestión de pedidos durante transmisiones en redes sociales.**

El nombre **Vendix** combina el concepto de venta con una terminación de estilo tecnológico, buscando representar una herramienta moderna orientada a la gestión de pedidos.

* **Propósito:** Centralizar y facilitar las tareas administrativas que se realizan durante y después de cada transmisión.
* **Usuarios principales:**
  1. Administrador (Emprendedor).
  2. Secretario (Operador).
  3. Cliente.

---

## 4. PROPUESTA DE SOLUCIÓN
Vendix busca automatizar el proceso de gestión de ventas mediante las siguientes funcionalidades:

* **Gestión de productos y clientes:** Registro de prendas, precios, cantidades disponibles y clientes mediante su número telefónico.
* **Automatización de pedidos:** Registro de las compras durante el live, cálculo automático de totales y actualización del stock.
* **Comunicación y reportes:** Envío del resumen de compra y saldo mediante chats, generación de hojas de cálculo y consulta del historial de ventas.
* **Resultado esperado:** Reducir el trabajo manual, disminuir los errores y mejorar la organización y eficiencia de las ventas.

---

## 5. OBJETIVOS

### Objetivo General
Desarrollar una aplicación móvil mediante Flutter para la automatización de gestión de pedidos durante transmisiones en redes sociales.

### Objetivos Específicos
* **Análisis del proceso:** Identificar requerimientos del sistema evaluando la gestión administrativa y manual.
* **Diseño de arquitectura:** Definir la estructura, módulos y tecnologías clave de la app móvil.
* **Integración de servicios:** Implementar módulos interconectados mediante el uso de APIs externas.
* **Evaluación funcional:** Verificar el cumplimiento de los requerimientos mediante la norma ISO/IEC 25010.

---

## 6. REQUISITOS FUNCIONALES
* Autenticarse de forma segura en la aplicación según el rol de usuario.
* Gestionar y modificar el catálogo de prendas, precios y stock.
* Registrar ágilmente las ventas y los pagos de los clientes durante las transmisiones en vivo.
* Consultar el historial de compras, saldos pendientes y el estado de los pedidos.
* Visualizar estadísticas en el dashboard y exportar los reportes de ventas.

---

## 7. REQUISITOS NO FUNCIONALES
* Interfaz sencilla e intuitiva para agilizar el registro y consulta en transmisiones.
* La app debe estar disponible durante las jornadas de ventas, siempre que haya conexión a internet.
* Funcionamiento garantizado en teléfonos inteligentes con sistema operativo Android.
* Autenticación estricta con cifrado seguro de credenciales y protección de datos.
* Validación de registros para prevenir duplicidad de datos en las ventas.

---

## 8. TECNOLOGÍAS QUE SE VAN A UTILIZAR
* **Flutter & Dart** (Desarrollo móvil multiplataforma)
* **Firebase:**
  * Authentication
  * Cloud Firestore
  * Cloud Messaging API
* **Google Maps Platform** (Google Maps APIs)
* **Herramientas de desarrollo y analítica:** Antigravity IDE, Emulador, Empaquetador GAPI, Google Sheets, Dashboards API, Power BI, REST API.

---

## 9. METODOLOGÍA DE DESARROLLO (MOBILE D)
Es una metodología ágil creada específicamente para el desarrollo de aplicaciones móviles (diseñada por el centro de investigación finlandés VTT). Combina las iteraciones cortas de Scrum con las prácticas técnicas de Extreme Programming (XP).

**¿Por qué se decidió usar esta metodología?**
* Enfoque móvil estricto.
* Velocidad y ciclos cortos.
* Pruebas tempranas continuas.

### Fases del proyecto:
1. **Exploración:** Identificación del problema en ventas de TikTok Live, definición de roles (Administrador, Secretaria, Cliente) y diseño de maquetas en Figma.
2. **Inicialización:** Configuración del entorno con Flutter, enlace con Firebase y conexión del emulador Android Studio.
3. **Producción (Actual):** Desarrollo de la lógica e interfaces principales, con Firebase Authentication (roles) y Cloud Firestore (datos en tiempo real) integrados; APIs externas e inventario avanzado quedan pendientes.
4. **Estabilización:** Depuración y optimización móvil, incluyendo bloqueo vertical, gestión de diálogos, interfaz con selector de rol y corrección de errores visuales.
5. **Prueba del Sistema:** Pruebas integrales simulando un en vivo real, empaquetado del APK final y entrega del proyecto.

---

## 10. ARQUITECTURA DE LA APLICACIÓN (MVC)

* **Vista:** Pantallas y formularios interactivos construidos con widgets reactivos (`StreamBuilder`). Captura las ventas en vivo y los pedidos de los clientes.
* **Controlador:** Servicios de lógica de negocio (`PrendaService` y `ClientService`). Calcula totales, deudas pendientes y sincroniza datos con Cloud Firestore.
* **Modelo:** Clases de datos tipadas en Dart (`PrendaModel`, `AdministradorModel`, `ClienteDemo`). Serializan y estructuran los documentos NoSQL.

### Estructura de directorios (`lib/`):
```text
lib/
├── data/ (servicios y datos locales)
├── models/ (modelos de datos Dart)
├── screens/ (pantallas organizadas por rol)
│   ├── auth/ -> Login y registros (Admin / Cliente)
│   ├── admin/ -> Dashboard, KPIs y secretarios
│   ├── secretary/ -> Ventas en vivo, catálogo y clientas
│   └── client/ -> Consulta de saldo y compras
├── services/ (servicios de clientes y compras)
├── theme/ (tema global y paleta de color)
├── firebase_options.dart
└── main.dart