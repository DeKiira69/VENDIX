# Implementación de Autenticación con Google (Clientes y Secretarios)

**Fecha:** 03 de noviembre de 2026  
**Proyecto:** VENDIX — `flutter_application_1`  
**Estado:** ✅ Integrado y Compilando — `dart analyze lib/` = **0 errores**

---

## 1. Resumen de la Solución

Se implementó el inicio de sesión y registro directo con **Google Authentication** tanto para **Clientes** como para **Secretarios (Operadores)**, garantizando que el flujo respete las reglas de negocio de cada rol.

---

## 2. Componentes Creados y Modificados

### 1. Nuevo Servicio: [`lib/services/google_auth_service.dart`](file:///c:/Users/crist/Desktop/VENDIX/flutter_application_1/lib/services/google_auth_service.dart)
* **Compatibilidad híbrida (Web y Android):**
  * En Web: usa `GoogleAuthProvider` con ventana emergente estándar de Firebase (`signInWithPopup`).
  * En Móvil / Android: usa `GoogleSignIn.instance.authenticate()` vinculado a Firebase Credentials (`idToken`).
* **Función `obtenerPerfil(uid)`:** Consulta rápida a la colección `usuarios` para verificar si es un usuario recurrente o nuevo.
* **Función `registrarUsuarioGoogle(...)`:**
  * Si es **Cliente**: Crea el registro en `usuarios`, en `clientes` y en `fotos_perfil` (usando su avatar de Google), con estado activo y aprobado inmediatamente.
  * Si es **Secretario**: Crea el registro en `usuarios`, en `secretarios` y en `fotos_perfil`, asignándole el estado **`pendiente`** y `aprobado: false`.

### 2. Pantalla de Login: [`lib/screens/auth/login_screen.dart`](file:///c:/Users/crist/Desktop/VENDIX/flutter_application_1/lib/screens/auth/login_screen.dart)
* Se integró el botón **"Continuar con Google"**.
* Si el usuario ya está registrado, lo redirige directamente a su interfaz respectiva (Cliente, Secretario aprobado, o Administrador).
* Si es la primera vez que inicia con esa cuenta de Google, se le presenta un diálogo interactivo para que elija su rol (**Soy Cliente** o **Soy Secretario**).
* Si elige **Secretario**, queda registrado en estado **PENDIENTE** y se le avisa que el administrador debe aprobar su cuenta antes de ingresar.

### 3. Registro de Cliente: [`lib/screens/auth/register_client_screen.dart`](file:///c:/Users/crist/Desktop/VENDIX/flutter_application_1/lib/screens/auth/register_client_screen.dart)
* Se agregó el botón **"Registrarse con Google"**.
* Hereda automáticamente los datos opcionales ingresados en el formulario (teléfono, dirección) y da acceso instantáneo como cliente.

### 4. Registro de Secretario: [`lib/screens/auth/register_entrepreneur_screen.dart`](file:///c:/Users/crist/Desktop/VENDIX/flutter_application_1/lib/screens/auth/register_entrepreneur_screen.dart)
* Se agregó el botón **"Registrarse con Google"**.
* Registra al secretario con su cuenta de Google, cierra la sesión temporal para seguridad y muestra el diálogo oficial de que la cuenta está en revisión por el Administrador.

---

## 3. Verificación de Compilación

```
> dart analyze lib/
Analyzing lib...
No issues found!
```
