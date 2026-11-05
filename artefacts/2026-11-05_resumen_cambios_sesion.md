# 📋 Cambios Realizados — VENDIX (Sesión 2026-11-05)

> [!IMPORTANT]
> Esta sesión incluyó cambios grandes en autenticación, registro y perfiles. No se ha subido nada a GitHub todavía — pendiente de pruebas del usuario.

---

## 1. 🔍 Revisión de cambios de Henry (GitHub)

**Resultado:** Henry **solo modificó el `README.md`** — eliminó la mención de "Antigravity AI" de la sección de autores.  
**No hubo ningún cambio en código Dart.** Todo lo demás fue trabajo propio de esta sesión.

---

## 2. 👤 Registro de Cliente SIN código (nuevo flujo)

**Archivo:** `lib/screens/auth/register_client_screen.dart`

### Qué se cambió:
- Se **eliminó** el campo de código Live del formulario de registro.
- Se **eliminó** la validación del código en `_registrar()`.
- Al registrarse, el cliente se guarda en Firestore con `adminId: ''`, `secretarioId: ''`, `codigoLive: ''` (cadenas vacías).
- Después del registro exitoso → navega a `EnterCodeScreen` (pantalla de ingreso de código), **no** a `ClientShell`.
- Lo mismo aplica al registro con **Google**: sin campo de código, guarda vacíos y va a `EnterCodeScreen`.

### Error encontrado y corregido:
| Error | Fix |
|-------|-----|
| `import 'client_shell.dart'` quedó sin usar después de quitar la navegación directa | Se eliminó el import innecesario → `dart analyze` pasó a `No issues found!` |

---

## 3. 🔐 Pantalla de ingreso de código post-login (`EnterCodeScreen`)

**Archivo:** `lib/screens/client/enter_code_screen.dart` ← **NUEVO**

### Lógica completa:
1. Se muestra automáticamente cuando un cliente inicia sesión y su campo `codigoLive` en Firestore está **vacío**.
2. Usa `PopScope(canPop: false)` → **no se puede saltar con el botón "atrás"**.
3. El cliente escribe el código → se valida contra la colección `secretarios` buscando el campo `codigoLive`.
4. Si el código es válido:
   - Se actualiza `usuarios/{uid}` con `adminId`, `secretarioId`, `codigoLive`.
   - Se actualiza `clientes/{uid}` con los mismos datos (batch write).
   - Navega a `ClientShell`.
5. Si el código es inválido → muestra error en pantalla.
6. Tiene botón **"Cerrar sesión"** con diálogo de confirmación → hace `signOut()` y regresa a `LoginScreen`.

### Error potencial encontrado (bug conocido):
> [!WARNING]
> La función `_cerrarSesion` originalmente usaba `Navigator.pushNamedAndRemoveUntil('/', ...)` pero `main.dart` no tiene rutas nombradas definidas → esto hubiera causado crash en runtime. Se corrigió usando `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(...LoginScreen...), ...)` sin usar rutas nombradas.

---

## 4. 🏪 Registro de Emprendedor desde la app

**Archivo:** `lib/screens/auth/register_admin_screen.dart` ← **NUEVO**

### Qué hace:
- Pantalla completa de registro para el rol **Administrador/Emprendedor**.
- Campos: nombre, apellido, teléfono, correo, contraseña, confirmación de contraseña.
- Al registrarse crea documentos en:
  - `Administradores/{uid}` → nombre, apellido, correo, telefono, estado: true
  - `usuarios/{uid}` → rol: 'administrador', aprobado: true, estado: true
- Navega directamente a `AdminHomeScreen` (sin aprobación pendiente).
- Soporta **Google Sign-In**: si se pasa un `User? googleUser`, muestra un modal para completar nombre, apellido y teléfono.

---

## 5. 🔘 Botón de Emprendedor en pantalla de Login

**Archivo:** `lib/screens/auth/login_screen.dart`

### Cambios:
- Se agregó la función `_irARegistroEmprendedor()` → navega a `RegisterAdminScreen`.
- El widget `_SelectorRegistroAnimado` pasó de **2 botones** (Secretario, Cliente) a **3 botones** (Secretario, Cliente, Emprendedor).
- El botón Emprendedor usa el ícono `Icons.storefront_outlined`.
- En el flujo de Google Sign-In, se agregó la opción "Soy Emprendedor (Administrador)" en el diálogo de selección de rol.
- La función `_crearPantallaSegunRol` ahora detecta: si `rol == 'cliente'` y `codigoLive` está vacío → retorna `EnterCodeScreen()` en vez de `ClientShell`.
- `_resolverPantalla` también verifica el código vacío para clientes.

---

## 6. 🖼️ Perfil del Emprendedor (AdminProfileScreen)

**Archivo:** `lib/screens/admin/admin_profile_screen.dart` ← **NUEVO**

### Funciones:
- Muestra foto de perfil con `StreamBuilder` conectado a `PerfilFotoService.fotoStream`.
- Muestra nombre completo, rol ("Emprendedor"), email, teléfono.
- Botón de **editar perfil**: abre `BottomSheet` con campos de nombre, apellido, teléfono → guarda en `Administradores/{uid}` y `usuarios/{uid}`.
- Botón **Cambiar contraseña** → llama `FirebaseAuth.sendPasswordResetEmail`.
- Contadores en tiempo real: número de secretarios y clientes (via `StreamBuilder`).
- Botón **Cerrar sesión** con diálogo de confirmación → va a `LoginScreen`.

### Errores encontrados y corregidos:
| Error | Fix |
|-------|-----|
| `import 'app_theme.dart'` sin usar | Eliminado |
| Campo `rosa` declarado pero no usado | Eliminado |

---

## 7. 🏠 Admin Home Screen — Pestaña de Perfil

**Archivo:** `lib/screens/admin/admin_home_screen.dart`

### Cambios:
- Pestaña índice 3 (antes "Más / Configuración") ahora navega a `AdminProfileScreen`.
- Pestaña índice 2 ahora va a `AdminMoreScreen` (gestión de secretarios).
- El avatar en la barra superior ahora muestra la foto real del Firestore via `PerfilFotoService.fotoStream`.
- Al tocar el avatar → va directamente a la pestaña de perfil (índice 3).

---

## 8. 👩‍💼 Admin More Screen — Avatar con foto real

**Archivo:** `lib/screens/admin/admin_more_screen.dart`

### Cambios:
- La tarjeta del admin ahora usa `StreamBuilder` con `PerfilFotoService.fotoStream` → muestra foto real en vez de avatar con iniciales estáticas.

---

## 9. 🔑 Google Auth Service — Soporte para Administrador

**Archivo:** `lib/services/google_auth_service.dart`

### Cambios:
- Se agregó bloque `else if (rol == 'administrador' || rol == 'admin')`:
  - Guarda en `usuarios` (rol: 'administrador', estado: true, aprobado: true).
  - Guarda en colección `Administradores`.
  - Guarda en `fotos_perfil` si el usuario de Google tiene foto.

---

## 10. 🏷️ Nombre hardcodeado en pantalla del Secretario

**Archivo:** `lib/screens/secretary/more_screen.dart`

### El bug:
```dart
// ❌ ANTES — nombre falso de prueba
final nombreMostrar = usuario?.displayName ?? 'Daniela León';
```

Los secretarios veían el nombre **"Daniela León"** si su `displayName` de Firebase Auth estaba vacío (lo cual pasa frecuentemente cuando el registro es con email/contraseña).

### La solución:
```dart
// ✅ DESPUÉS — lee desde Firestore en tiempo real
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).snapshots(),
  builder: (context, snap) {
    final datos = snap.data?.data() as Map<String, dynamic>?;
    final nombre = datos?['nombre']?.toString() ?? '';
    final apellido = datos?['apellido']?.toString() ?? '';
    final nombreFinal = [nombre, apellido].where((s) => s.isNotEmpty).join(' ').trim();
    // Si tampoco está en Firestore → usa email como fallback, nunca un nombre falso
    ...
  }
)
```

El widget también fue convertido de `StatelessWidget` a `StatefulWidget` para soportar el `StreamBuilder` correctamente.

### Errores del refactor corregidos:
| Error | Fix |
|-------|-----|
| `_generarCodigoLive` y `_generarOGuardarCodigo` eran `static` en `MoreScreen` pero se llamaban desde `_MoreScreenState` | Se movieron a `_MoreScreenState` como métodos estáticos del State |

---

## ✅ Estado Final de dart analyze

```
dart analyze lib/
→ No issues found!
```

---

## 📁 Archivos nuevos creados esta sesión

| Archivo | Rol |
|---------|-----|
| `lib/screens/client/enter_code_screen.dart` | Pantalla de ingreso de código para clientes |
| `lib/screens/auth/register_admin_screen.dart` | Registro de Emprendedor |
| `lib/screens/admin/admin_profile_screen.dart` | Perfil editable del Emprendedor |

## 📁 Archivos modificados esta sesión

| Archivo | Qué cambió |
|---------|------------|
| `lib/screens/auth/register_client_screen.dart` | Sin código en registro, navega a EnterCodeScreen |
| `lib/screens/auth/login_screen.dart` | 3er botón Emprendedor, lógica de código vacío |
| `lib/screens/admin/admin_home_screen.dart` | Pestaña perfil, avatar con foto real |
| `lib/screens/admin/admin_more_screen.dart` | Avatar admin con foto real |
| `lib/screens/admin/admin_profile_screen.dart` | Nuevo + fixes de analyze |
| `lib/services/google_auth_service.dart` | Soporte rol administrador |
| `lib/screens/secretary/more_screen.dart` | Fix nombre hardcodeado "Daniela León" |
