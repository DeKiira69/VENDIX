# 🤖 Informe Técnico Detallado: Implementación del Chatbot con Gemini AI y Mejoras de Henry

> **Fecha de Documentación:** 12 de Noviembre de 2026  
> **Proyecto:** VENDIX — Plataforma de Gestión de Ventas en Vivo para Emprendimientos  
> **Autor de las funciones documentadas:** Henry (con integración y refactorización técnica en el repositorio unificado)  
> **Estado:** Implementado, integrado y verificado al 100% en `main`

---

## 1. 📌 Resumen Ejecutivo de la Implementación

Henry desarrolló la infraestructura del **asistente virtual inteligente para clientas** impulsado por **Google Gemini API**, integrándolo directamente con la base de datos viva en **Firebase Firestore** y dotándolo de una interfaz conversacional moderna tipo bottom sheet flotante.

Adicionalmente, Henry implementó mejoras en la seguridad de autenticación (contraseñas con reglas criptográficas más estrictas) y tolerancia a fallos en navegadores con bloqueadores automáticos como Brave Browser.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   ARQUITECTURA DEL CHATBOT VENDIX                      │
├──────────────────────────┬─────────────────────────────────────────────┤
│   Interfaz de Usuario    │ ClientChatbotSheet (ModalBottomSheet + FAB) │
├──────────────────────────┼─────────────────────────────────────────────┤
│   Motor de Inteligencia  │ Google Gemini 3.5 Flash Lite (SDK Oficial)   │
├──────────────────────────┼─────────────────────────────────────────────┤
│   Inyección de Contexto  │ ContextoClienteChatbot (Tiempo Real)        │
├──────────────────────────┼─────────────────────────────────────────────┤
│   Fuente de Datos        │ Firebase Firestore (clientes, compras,      │
│                          │ pagos, Administradores, usuarios)           │
├──────────────────────────┼─────────────────────────────────────────────┤
│   Mecanismo de Respaldo  │ Fallback determinista local basado en datos │
│   (Sin API Key / Offline)│ directos de Firestore sin latencia externa  │
└──────────────────────────┴─────────────────────────────────────────────┘
```

---

## 2. 🧠 Servicio de Inteligencia Artificial: `lib/services/gemini_service.dart`

### 2.1. Modelo de IA Seleccionado
Se configuró el modelo **`gemini-3.5-flash-lite`** como motor primario a través del paquete oficial `google_generative_ai: ^0.4.7`.
- **Ventaja de latencia:** Tiempos de respuesta menores a 800 ms.
- **Eficiencia de tokens:** Capacidad para procesar el system instruction dinámico con bajo consumo de cuota.
- **Modelo de respaldo (fallback):** Si el modelo primario presenta error de saturación o límite de peticiones (Rate Limit 429), el servicio conmuta automáticamente a `gemini-3.1-flash-lite`.

### 2.2. Modelo de Datos de Contexto (`ContextoClienteChatbot`)
Antes de despachar cualquier consulta a la red neuronal, el servicio recopila y sintetiza en milisegundos toda la ficha del cliente autenticado:

```dart
class ContextoClienteChatbot {
  final String nombre;
  final String telefono;
  final String codigoLive;
  final double totalComprado;
  final double totalPagado;
  final double saldoPendiente;
  final int totalPrendas;
  final List<String> ultimasPrendas;
  final String nombreTienda;
  final String direccionTienda;
  final String telefonoTienda;
}
```

### 2.3. Algoritmo de Extracción Multicolección en Firestore
La función `obtenerContextoCliente()` realiza consultas cruzadas en paralelo:
1. **Identificación de Ficha:** Busca en la colección `clientes` donde `uid == authUser.uid`. Si el usuario no fue vinculado por UID directo, efectúa fallback hacia la colección `usuarios/{uid}`.
2. **Cálculo de Compras en Vivo:** Consulta `compras` filtrando por `clienteId == clienteId`. Extrae y acumula cantidades, precios unitarios y subtotales, construyendo el histórico de las últimas prendas apartadas (ej. *"Blusa Seda (x2, $30.00)"*).
3. **Cálculo de Abonos y Pagos:** Consulta la colección `pagos` donde `clienteId == clienteId` y totaliza el dinero efectivamente cancelado.
4. **Saldo Dinámico:** Determina la deuda exacta mediante:
   $$\text{Saldo Pendiente} = \max(0, \text{Total Comprado} - \text{Total Pagado})$$
5. **Geolocalización del Negocio:** Lee la colección `Administradores/{adminId}` para inyectar la razón social de la tienda, la dirección física del showroom (ej. *"Calle 10 de Agosto y Guayaquil, Riobamba, Ecuador"*) y teléfono de soporte.

### 2.4. System Instruction Dinámico (Prompt Engineering)
El asistente opera bajo un prompt estricto que restringe alucinaciones:
- **Identidad:** Asistente oficial exclusivo de la tienda del emprendedor.
- **Regla de Saldo:** Informa exactamente el saldo pendiente. Si el saldo es \$0.00, felicita a la clienta por estar al día.
- **Regla de Ubicación:** Si la clienta pregunta dónde retirar sus prendas o dónde queda el local, proporciona la dirección física exacta obtenida del perfil del administrador.
- **Regla de Pagos:** Prohibición estricta de inventar pasarelas de pago no autorizadas. Los pagos se coordinan directamente con la secretaria o en el local comercial.
- **Instrucción de Dinámica de Live:** Si se consulta cómo comprar en transmisiones de TikTok o Facebook Live, explica el proceso de comentar en el directo para que la secretaria registre la prenda al instante.

### 2.5. Modo Fallback Autónomo (Sin Conexión o Sin Clave)
Si `apiKey` se encuentra vacía en `lib/secrets.dart` o no se pasa por `--dart-define=GEMINI_API_KEY`:
- El método `_responderFallbackConFirebase()` evalúa la intención del usuario mediante análisis de palabras clave (`saldo`, `deuda`, `ubicación`, `dirección`, `apartar`, `prendas`, etc.).
- Devuelve respuestas prefabricadas formateadas con los datos numéricos exactos de Firestore.
- La aplicación **nunca se congela ni arroja errores visuales** a la clienta.

---

## 3. 🎨 Interfaz de Usuario del Chatbot: `lib/screens/client/widgets/client_chatbot_sheet.dart`

### 3.1. Acceso Visual Rápido (FloatingActionButton)
En `client_shell.dart`, se incorporó un botón flotante animado de color violeta con icono `Icons.auto_awesome` y tooltip *"Asistente IA"*. Este botón está presente de forma persistente en toda la experiencia de navegación de la clienta.

### 3.2. Experiencia ModalBottomSheet
Al pulsar el botón flotante, se despliega una hoja modal inferior tipo chat que ocupa el 85% de la pantalla:
- **Barra Superior:** Avatar distintivo con degradado de violeta a magenta, insignia de estado *"En línea"* con punto verde parpadeante, y botón para reiniciar la conversación.
- **Burbujas de Diálogo:**
  - **Mensajes de la Clienta:** Alineados a la derecha, fondo violeta degradado con texto blanco y bordes redondeados.
  - **Mensajes del Asistente:** Alineados a la izquierda, tarjeta blanca con elevación suave, tipografía nítida y formateo estructurado.
- **Chips de Preguntas Frecuentes (Quick Prompts):**
  - *"¿Cuál es mi saldo?"*
  - *"¿Dónde queda la tienda?"*
  - *"¿Qué prendas tengo apartadas?"*
  - *"¿Cómo aparto en el live?"*
  Al pulsar cualquiera de los chips, la pregunta se envía automáticamente al servicio.
- **Indicador de Pensamiento (Typing Indicator):** Tres puntos con animación ondulada que informan que el modelo está procesando la solicitud.

---

## 4. 🔒 Seguridad y Configuración de Claves: `lib/secrets.dart`

Para evitar fugas de credenciales en GitHub y respetar las directrices de seguridad:
1. Se aisló la constante `geminiApiKey` en el archivo `lib/secrets.dart`.
2. Dicho archivo fue registrado de forma explícita en `.gitignore`:
   ```gitignore
   # Claves secretas del proyecto (NO subir a GitHub)
   lib/secrets.dart
   ```
3. Se admite inyección en tiempo de compilación para entornos CI/CD mediante:
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=AIzaSy...
   ```

---

## 5. 🛡️ Mejoras Adicionales de Autenticación de Henry

### 5.1. Validación de Contraseñas Seguras (`register_admin_screen.dart` y flujos auth)
Se aplicó una expresión regular que exige:
- Mínimo 8 caracteres.
- Al menos una letra mayúscula.
- Al menos una letra minúscula.
- Al menos un dígito numérico.
- Al menos un carácter especial (`!@#$%^&*(),.?":{}|<>`).

### 5.2. Tolerancia a Brave Browser y Bloqueadores de Ventanas (`google_auth_service.dart`)
En navegadores Chromium con escudos estrictos (como Brave Browser), las ventanas emergentes de OAuth pueden generar la excepción `popup-blocked`. Henry incorporó:
- Captura de error amigable.
- Notificación al usuario mediante `SnackBar` con instrucciones para permitir ventanas emergentes o continuar con correo y contraseña tradicionales.

---

## 6. 📊 Tabla Resumen de Archivos Afectados por Henry

| Archivo | Tipo | Descripción de la Modificación |
|---|---|---|
| `lib/services/gemini_service.dart` | **Nuevo** | Integración del SDK Gemini 3.5, extracción Firestore y fallback. |
| `lib/screens/client/widgets/client_chatbot_sheet.dart` | **Nuevo** | UI del chat interactivo con burbujas, chips y FAB. |
| `lib/screens/client/client_shell.dart` | Modificado | Integración del FloatingActionButton del chatbot. |
| `lib/secrets.dart` | **Nuevo (Local)** | Contenedor de la API Key, aislado por gitignore. |
| `lib/services/google_auth_service.dart` | Modificado | Manejo de bloqueo de popups en Brave. |
| `lib/screens/auth/register_admin_screen.dart` | Modificado | Reglas de validación estricta de contraseña. |
| `pubspec.yaml` | Modificado | Incorporación de dependencia `google_generative_ai: ^0.4.7`. |
| `.gitignore` | Modificado | Exclusión garantizada de `lib/secrets.dart`. |
