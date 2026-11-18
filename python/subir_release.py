import subprocess
import urllib.request
import json
import os
import sys

# 1. Obtener token de GitHub
p = subprocess.run(['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n', text=True, capture_output=True)
token = None
for line in p.stdout.splitlines():
    if line.startswith('password='):
        token = line.split('=', 1)[1].strip()
        break

if not token:
    print("ERROR: No se pudo obtener el token de Git.")
    sys.exit(1)

headers = {
    'Authorization': f'token {token}',
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'VendixDeploy'
}

apk_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'apk', 'VENDIX_release.apk')
if not os.path.exists(apk_path):
    print(f"ERROR: No existe el APK en {apk_path}")
    sys.exit(1)

apk_size = os.path.getsize(apk_path)
print(f"APK encontrado: {apk_path} ({apk_size / (1024*1024):.1f} MB)")

# 2. Consultar releases
req = urllib.request.Request('https://api.github.com/repos/DeKiira69/VENDIX/releases', headers=headers)
with urllib.request.urlopen(req) as resp:
    releases = json.loads(resp.read().decode())

target_release = None
for r in releases:
    print(f"Release encontrada: {r['tag_name']} (ID: {r['id']})")
    target_release = r
    break

if not target_release:
    # Crear release v1.1.1
    print("Creando release v1.1.1...")
    create_data = json.dumps({
        'tag_name': 'v1.1.1',
        'target_commitish': 'main',
        'name': 'VENDIX v1.1.1 - Multi-Tienda y Correcciones',
        'body': 'Release oficial con arquitectura multi-tienda, reactividad en tiempo real de saldo/compras y correcciones visuales.',
        'draft': False,
        'prerelease': False
    }).encode('utf-8')
    req = urllib.request.Request(
        'https://api.github.com/repos/DeKiira69/VENDIX/releases',
        data=create_data,
        headers={**headers, 'Content-Type': 'application/json'}
    )
    with urllib.request.urlopen(req) as resp:
        target_release = json.loads(resp.read().decode())
        print(f"Release creada: {target_release['tag_name']} (ID: {target_release['id']})")

release_id = target_release['id']
upload_url = target_release['upload_url'].split('{')[0]

# 3. Eliminar assets viejos con el mismo nombre si existen
for a in target_release.get('assets', []):
    if a['name'] == 'VENDIX_release.apk':
        print(f"Eliminando asset previo: {a['name']} (ID: {a['id']})...")
        del_req = urllib.request.Request(
            f"https://api.github.com/repos/DeKiira69/VENDIX/releases/assets/{a['id']}",
            headers=headers,
            method='DELETE'
        )
        try:
            with urllib.request.urlopen(del_req) as resp:
                print("Asset previo eliminado.")
        except Exception as e:
            print(f"Error eliminando asset previo: {e}")

# 4. Subir nuevo APK
print(f"Subiendo {apk_path} a GitHub Releases...")
upload_full_url = f"{upload_url}?name=VENDIX_release.apk"

with open(apk_path, 'rb') as f:
    apk_data = f.read()

upload_req = urllib.request.Request(
    upload_full_url,
    data=apk_data,
    headers={
        'Authorization': f'token {token}',
        'Content-Type': 'application/vnd.android.package-archive',
        'User-Agent': 'VendixDeploy'
    }
)

with urllib.request.urlopen(upload_req) as resp:
    res = json.loads(resp.read().decode())
    print("\n" + "=" * 50)
    print("UPLOAD EXITOSO!")
    print(f"Asset ID      : {res['id']}")
    print(f"Nombre        : {res['name']}")
    print(f"Tamaño        : {res['size'] / (1024*1024):.1f} MB")
    print(f"Download URL  : {res['browser_download_url']}")
    print("=" * 50)
