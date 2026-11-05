import subprocess
import shutil
import os
import sys

# ── Rutas ─────────────────────────────────────────────────────────────────────
PROYECTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARPETA_APK = os.path.join(PROYECTO, "apk")
APK_ORIGEN  = os.path.join(PROYECTO, "build", "app", "outputs", "flutter-apk", "app-release.apk")
APK_DESTINO = os.path.join(CARPETA_APK, "VENDIX_release.apk")

def titulo(texto):
    print("\n" + "=" * 50)
    print(f"  {texto}")
    print("=" * 50)

def paso(n, texto):
    print(f"\n[{n}] {texto}...")

def correr(cmd, cwd=PROYECTO, capturar=False):
    """Ejecuta un comando. Si capturar=True devuelve (code, output)."""
    if capturar:
        resultado = subprocess.run(
            cmd, cwd=cwd, shell=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace"
        )
        print(resultado.stdout)
        return resultado.returncode, resultado.stdout
    else:
        resultado = subprocess.run(cmd, cwd=cwd, shell=True)
        return resultado.returncode, ""

def verificar_modo_desarrollador():
    """Devuelve True si el Modo Desarrollador esta activado en Windows."""
    try:
        import winreg
        clave = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE,
            r"SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        )
        valor, _ = winreg.QueryValueEx(clave, "AllowDevelopmentWithoutDevLicense")
        winreg.CloseKey(clave)
        return valor == 1
    except Exception:
        return False  # Si no se puede leer, asumir que no esta activo

def main():
    titulo("VENDIX - Generar APK Release")
    print(f"  Proyecto: {PROYECTO}")

    # ── 0. Verificar Modo Desarrollador ───────────────────────────────────────
    paso(0, "Verificando Modo Desarrollador de Windows")
    if not verificar_modo_desarrollador():
        print("\n  ATENCION: El Modo Desarrollador de Windows NO esta activado.")
        print("  Flutter necesita este modo para crear symlinks al compilar.")
        print("\n  Abriendo configuracion de Windows...")
        os.system("start ms-settings:developers")
        print("""
  INSTRUCCIONES:
  1. En la ventana que se abrio, activa "Modo desarrollador"
  2. Acepta el dialogo de confirmacion
  3. Cierra esta ventana y vuelve a ejecutar el script

  Si ya lo activaste y sigue saliendo este error,
  reinicia la computadora e intentalo de nuevo.
        """)
        input("Presiona ENTER para cerrar...")
        sys.exit(1)
    else:
        print("  Modo Desarrollador: ACTIVO")

    # ── 1. Verificar Flutter ──────────────────────────────────────────────────
    paso(1, "Verificando Flutter")
    if shutil.which("flutter") is None:
        print("\n  ERROR: Flutter no encontrado en PATH.")
        input("\nPresiona ENTER para salir...")
        sys.exit(1)
    correr("flutter --version")

    # ── 2. Flutter clean ──────────────────────────────────────────────────────
    paso(2, "Limpiando build anterior (flutter clean)")
    correr("flutter clean")

    # ── 3. Flutter pub get ────────────────────────────────────────────────────
    paso(3, "Obteniendo dependencias (flutter pub get)")
    code, output = correr("flutter pub get", capturar=True)

    # Pub get puede retornar != 0 por warnings pero aun haber descargado todo
    if "Got dependencies" not in output and code != 0:
        print("\n  ERROR al obtener dependencias.")
        input("\nPresiona ENTER para salir...")
        sys.exit(1)

    # ── 4. Build APK release ──────────────────────────────────────────────────
    paso(4, "Compilando APK Release... (puede tardar 3-8 minutos)")
    code, _ = correr("flutter build apk --release", capturar=True)
    if code != 0:
        print("\n  ERROR al compilar el APK. Revisa el log de arriba.")
        input("\nPresiona ENTER para salir...")
        sys.exit(1)

    # ── 5. Copiar APK a /apk ──────────────────────────────────────────────────
    paso(5, "Copiando APK a carpeta apk/")
    if not os.path.exists(APK_ORIGEN):
        print(f"\n  ERROR: No se encontro el APK en:\n  {APK_ORIGEN}")
        input("\nPresiona ENTER para salir...")
        sys.exit(1)

    os.makedirs(CARPETA_APK, exist_ok=True)
    shutil.copy2(APK_ORIGEN, APK_DESTINO)

    tam_mb = os.path.getsize(APK_DESTINO) / (1024 * 1024)

    titulo("APK GENERADO EXITOSAMENTE!")
    print(f"  Ubicacion : {APK_DESTINO}")
    print(f"  Tamano    : {tam_mb:.1f} MB")

    os.startfile(CARPETA_APK)
    input("\nPresiona ENTER para cerrar...")

if __name__ == "__main__":
    main()
