# Orbita · App iOS

App **iOS nativa** (Swift + SwiftUI) de Orbita: ingresos y egresos personales por cuenta, en varias monedas, con transferencias, compras con tarjeta de crédito pendientes de pago y reportes. Es la misma app que Android (`atm-orbita-android`) y habla con el mismo API (`atm-orbita-api`).

- Bundle id: `com.atmosferast.orbita`
- La **especificación funcional** es `atm-orbita-android/docs/ORBITA_SPEC.md` (pantallas, reglas, textos, cálculos y datos de ejemplo). Si el código y la spec no coinciden, manda el código de Android.
- Contrato del API: `atm-orbita-api/docs/plans/` y `docs/openapi.yaml`.

## Ramas

Todo el trabajo va en `develop`. `main` guarda lo que ya funciona; pasar a `main` lo decide el usuario. Commits en Conventional Commits, en inglés.

## Estado

Replica toda la app de Android (26 oct 2026), conectada al servidor real: sesión (registro, ingreso, recuperar contraseña con código de 6 dígitos, cerrar sesión, eliminar cuenta), Inicio, Cuentas, Movimientos (ingreso, egreso, compra con tarjeta, transferencia), Reportes (mes, año, rango), Crédito (tarjetas, compras pendientes, pagar), Categorías y Ajustes (monedas y tipo de cambio).

> **Pendiente de verificar:** este código se escribió en una máquina sin Xcode, así que **aún no se compiló**. El primer paso en un Mac es abrir `orbita.xcodeproj`, compilar y corregir lo que salga.

Pendiente respecto a Android:

- **Continuar con Google.** El flujo está hecho (`AppModel.continueWithGoogle`, vincular con contraseña), pero no hay proveedor de tokens (`GoogleTokenProvider`), así que el botón no se muestra. Hace falta el SDK de Google Sign-In (Swift Package), un cliente OAuth de tipo iOS y que el API acepte ese `audience` (hoy solo verifica el cliente web).
- **Pruebas unitarias.** Android tiene pruebas de reglas de dinero, tipo de cambio, nombres y repositorios; aquí falta crear el target de pruebas.
- **Textos en String Catalog.** Los textos están escritos en los propios archivos Swift (es-PE).
- **Iconos propios.** Se usan SF Symbols en lugar de los iconos de línea de Android.

## Arquitectura

```
UI (SwiftUI)  →  App (AppModel, @Observable)  →  Domain (modelos, borradores, reglas, protocolos)  ←  Data (Demo | Remote)
```

| Carpeta | Qué hay |
|---|---|
| `orbita/Core` | Formatos de dinero y fechas, `LocalDay` (una fecha sin hora, como `LocalDate`), entrada de montos "desde la derecha". |
| `orbita/Domain` | Modelos, `FxPair`, nombres de categoría, borradores con su `validate()` y los **protocolos de repositorio**. Sin SwiftUI. |
| `orbita/Data/Demo` | Implementación en memoria con los datos de ejemplo de la spec (sección 11). |
| `orbita/Data/Remote` | `URLSession` contra el API: cliente, sesión con renovación de una en una, DTOs, llavero (Keychain) y repositorios. |
| `orbita/App` | `AppEnvironment` (decide demo o API), `AppModel` (sesión, pila de navegación, mensajes, escrituras), `Loader`. |
| `orbita/UI` | Tema (Manrope y colores de la spec), componentes, teclado de monto y calendario propios. |
| `orbita/Features` | Una carpeta o archivo por pantalla. |

Reglas que no cambian (iguales a Android):

1. **Dinero = `Decimal`**, 2 decimales, redondeo `.plain` (half up) una sola vez al final. Nunca `Double`. En el API viaja como texto (`ApiDecimal`).
2. El saldo no se guarda: lo calcula el API (y `Data/Demo` igual).
3. La app nunca envía un id de usuario: solo su token. Los ids de lo que se crea los genera la app (UUID).
4. Ningún secreto en la app ni en el repo. El refresh token vive en el llavero (`ThisDeviceOnly`, fuera de los respaldos); el access token solo en memoria.
5. "Hoy" lo decide el API con la zona horaria del perfil (la app envía `TimeZone.current` al registrarse).
6. Sin tipo de cambio no hay otra moneda.
7. Los mensajes de error los elige la app por el `code` del API (`UiMessage`); el `message` del API no se muestra.

### Cómo se leen y escriben los datos

Los repositorios no guardan nada: devuelven la lectura actual. Cada pantalla tiene un `Loader` y vuelve a leer cuando cambia `AppModel.revision`, que sube después de **cada escritura que salió bien**, al cambiar la sesión y al volver de segundo plano (`.task(id: [app.revision, loader.attempt])`). Las escrituras pasan por `AppModel.perform(invalid:onDone:_:)`, que avisa la validación o el error, ignora toques mientras otra escritura corre y cierra la pantalla al terminar.

### Navegación

`NavigationStack` con una pila de `Route` (`App/Navigation.swift`) sobre las cuatro pestañas (Inicio · Cuentas · Reportes · Crédito) y el botón **+** central, que abre Nuevo movimiento. Las pantallas que crean algo llevan **X**; las demás, **‹**. La barra del sistema está oculta y se conserva el gesto de deslizar para volver.

## Cómo correrla

Requiere Xcode con soporte para el SDK que indica el proyecto.

- **Por defecto usa el servidor real.** Abrir en Xcode y correr (Debug o Release) habla con `https://orbita-api.atmosferast.com/api/v1` por HTTPS: registro, inicio de sesión y todos los datos son de verdad. Para probar sin ensuciar el servidor, usa una cuenta de prueba.
- **Con otro API (Debug):** en el esquema de Xcode (*Edit Scheme → Run → Arguments → Environment Variables*) agregar:

  ```
  API_BASE_URL = http://192.168.x.x:3001/api/v1     # IP de la PC en la red local
  ```

  Para levantar el API, ver `atm-orbita-api/docs/plans/00-foundations.md`. El HTTP sin cifrar solo se permite en Debug y solo a la red local (`Config/Debug-Info.plist`).
- **Modo demo (sin servidor, solo Debug):** agregar la variable `ORBITA_DEMO = 1` al esquema. Cualquier correo y contraseña entran; los datos son los de ejemplo y se pierden al cerrar. En demo "hoy" es el 2 oct 2026.
