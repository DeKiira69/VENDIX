import json
import re
import sys
import unicodedata
import urllib.error
import urllib.request

API_KEY = 'AIzaSyAeZuUr8aBl3f4YtJDhF42b5qQOzhQB4_k'
PROJECT_ID = 'vendix-53bd7'


def limpiar_texto(texto: str) -> str:
  """Normaliza texto quitando acentos y espacios extra."""
  t = unicodedata.normalize('NFKD', texto)
  t = ''.join(c for c in t if not unicodedata.combining(c))
  return re.sub(r'[^a-zA-Z0-9]', '', t).lower()


def generar_correo(nombre: str, apellido: str) -> str:
  """Genera el correo corporativo nombre.apellido@vendix.com."""
  n = limpiar_texto(nombre.strip().split()[0])
  a = limpiar_texto(apellido.strip().split()[0])
  return f'{n}.{a}@vendix.com'


def registrar_en_firebase_auth(correo: str, contrasena: str):
  """Crea el usuario en Firebase Authentication."""
  url = (
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key='
      f'{API_KEY}'
  )
  payload = json.dumps({
      'email': correo,
      'password': contrasena,
      'returnSecureToken': True,
  }).encode('utf-8')

  req = urllib.request.Request(
      url, data=payload, headers={'Content-Type': 'application/json'}
  )
  try:
    with urllib.request.urlopen(req) as response:
      res = json.loads(response.read().decode())
      return res['localId'], res['idToken']
  except urllib.error.HTTPError as e:
    err_body = e.read().decode()
    err_json = json.loads(err_body)
    msg = err_json.get('error', {}).get('message', 'ERROR_DESCONOCIDO')
    if 'EMAIL_EXISTS' in msg:
      raise Exception(
          f"El correo '{correo}' ya está registrado en Firebase Authentication."
      )
    elif 'WEAK_PASSWORD' in msg:
      raise Exception('La contraseña es muy débil (mínimo 6 caracteres).')
    else:
      raise Exception(f'Error de Firebase Auth: {msg}')


def guardar_en_firestore_administrador(
    uid: str,
    id_token: str,
    nombre: str,
    apellido: str,
    correo: str,
    telefono: str,
    contrasena: str,
):
  """Guarda la información en la colección Administradores con los campos del diagrama."""
  url = f'https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/Administradores/{uid}'

  doc_data = {
      'fields': {
          'nombre': {'stringValue': nombre},
          'apellido': {'stringValue': apellido},
          'correo': {'stringValue': correo},
          'telefono': {'stringValue': telefono},
          'contrasena': {'stringValue': contrasena},
          'estado': {'booleanValue': True},
          'rol': {'stringValue': 'admin'},
      }
  }

  req = urllib.request.Request(
      url,
      data=json.dumps(doc_data).encode('utf-8'),
      headers={
          'Authorization': f'Bearer {id_token}',
          'Content-Type': 'application/json',
      },
      method='PATCH',
  )
  with urllib.request.urlopen(req) as resp:
    return resp.status == 200


def listar_administradores():
  """Consulta y muestra todos los administradores registrados en Firestore."""
  url = f'https://firestore.googleapis.com/v1/projects/{PROJECT_ID}/databases/(default)/documents/Administradores'
  req = urllib.request.Request(url)

  try:
    with urllib.request.urlopen(req) as resp:
      data = json.loads(resp.read().decode())
      docs = data.get('documents', [])

      if not docs:
        print(
            '\nℹ️  No hay administradores registrados en la colección'
            ' "Administradores".'
        )
        return

      print(f'\n=== LISTA DE ADMINISTRADORES REGISTRADOS ({len(docs)}) ===')
      print('-' * 75)
      print(f'{"NOMBRE COMPLETO":<28} | {"CORREO":<26} | {"TELÉFONO":<12}')
      print('-' * 75)

      for doc in docs:
        fields = doc.get('fields', {})
        nom = fields.get('nombre', {}).get('stringValue', '')
        ape = fields.get('apellido', {}).get('stringValue', '')
        cor = fields.get('correo', {}).get('stringValue', '')
        tel = fields.get('telefono', {}).get('stringValue', '')
        est = fields.get('estado', {}).get('booleanValue', True)

        nombre_completo = f'{nom} {ape}'.strip() or 'Sin nombre'
        estado_str = ' [Activo]' if est else ' [Inactivo]'
        print(f'{nombre_completo + estado_str:<28} | {cor:<26} | {tel:<12}')
      print('-' * 75)

  except urllib.error.HTTPError as e:
    print(f'Error al consultar administradores: {e}')


def menu_crear_admin():
  print('\n' + '=' * 50)
  print('        REGISTRO DE NUEVO ADMINISTRADOR')
  print('=' * 50)

  nombre = input('Nombre del Administrador: ').strip()
  while not nombre:
    nombre = input('El nombre no puede estar vacío: ').strip()

  apellido = input('Apellido del Administrador: ').strip()
  while not apellido:
    apellido = input('El apellido no puede estar vacío: ').strip()

  telefono = input('Teléfono (ej. 0990000000): ').strip()

  correo_generado = generar_correo(nombre, apellido)
  print(f'\n📧 Correo generado automáticamente: {correo_generado}')

  contrasena = input('Ingresa la contraseña (mínimo 6 caracteres): ').strip()
  while len(contrasena) < 6:
    contrasena = input(
        'La contraseña debe tener al menos 6 caracteres: '
    ).strip()

  print('\n⏳ Registrando en Firebase Authentication y Cloud Firestore...')

  try:
    uid, id_token = registrar_en_firebase_auth(correo_generado, contrasena)
    guardar_en_firestore_administrador(
        uid,
        id_token,
        nombre,
        apellido,
        correo_generado,
        telefono,
        contrasena,
    )

    print('\n' + '🎉' * 20)
    print('✅ ¡ADMINISTRADOR REGISTRADO CON ÉXITO!')
    print(f'   • UID: {uid}')
    print(f'   • Nombre: {nombre} {apellido}')
    print(f'   • Correo: {correo_generado}')
    print(f'   • Teléfono: {telefono}')
    print(
        '   • Colección Firestore: Administradores/'
    )
    print('🎉' * 20)

  except Exception as e:
    print(f'\n❌ Error durante el registro: {e}')


def main():
  while True:
    print('\n' + '=' * 50)
    print('      SISTEMA DE GESTIÓN DE ADMINS - VENDIX')
    print('=' * 50)
    print('1. Crear nuevo Administrador')
    print('2. Ver lista de Administradores')
    print('3. Salir')

    op = input('\nSelecciona una opción (1, 2 o 3): ').strip()

    if op == '1':
      menu_crear_admin()
    elif op == '2':
      listar_administradores()
    elif op == '3':
      print('\n¡Hasta luego!')
      sys.exit(0)
    else:
      print('\nOpción inválida. Intenta nuevamente.')


if __name__ == '__main__':
  main()
