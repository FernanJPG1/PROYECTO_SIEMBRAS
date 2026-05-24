# Proyecto Siembras - Sistema de Gestión Offline-First

Este proyecto es un sistema de gestión para el registro de siembras en campo, diseñado con una arquitectura **Offline-First**. Permite a los operarios registrar datos en campo sin necesidad de conexión a internet, sincronizándolos posteriormente con una base de datos central en Microsoft Access.

## 🏗️ Arquitectura del Sistema

El proyecto se divide en tres componentes principales:

1. **Base de Datos Central (Microsoft Access)**
   - Archivo `.accdb` (`bmempresarial2021.accdb`).
   - Almacena catálogos (variedades, camas, operarios) y registros de siembra.
   - Acceso restringido y concurrencia gestionada a través del backend.

2. **Backend API (Python / FastAPI)**
   - Actúa como intermediario entre la aplicación móvil y la base de datos Access.
   - Implementado con **FastAPI** para alto rendimiento y documentación automática (Swagger).
   - Usa **pyodbc** para la conexión con Access.
   - Provee endpoints para sincronización (`/api/sync`), consulta de catálogos y health check.

3. **Aplicación Móvil (Android / Kotlin / Jetpack Compose / Flutter)**
   - Aplicación diseñada para funcionar en entornos sin conexión.
   - Usa una base de datos local (SQLite) para almacenar registros temporalmente.
   - Sincronización en lotes (Batch Push/Pull) cuando se detecta conexión a internet.
   - Manejo de conflictos de sincronización.

---

## 🛠️ Requisitos y Dependencias

### Entorno de Desarrollo
- **Sistema Operativo:** Windows (requerido para el driver ODBC de Microsoft Access).
- **Python:** 3.10 o superior.
- **Java Development Kit (JDK):** Versión 17 o superior (incluido en Android Studio).
- **Flutter SDK:** Para el desarrollo de la aplicación móvil.
- **Android Studio / Android SDK:** Herramientas de compilación para Android.

### Dependencias de Python (Backend)
Las dependencias están definidas en el archivo `requirements.txt`. Las principales son:
- `fastapi`, `uvicorn`: Framework web y servidor.
- `pyodbc`: Driver de conexión a bases de datos.
- `pydantic`: Validación de datos.
- `pandas`, `numpy`, `openpyxl`: Análisis y manipulación de datos.
- `pytest`, `httpx`: Pruebas automatizadas.

---

## 📂 Estructura del Proyecto

```text
PROYECTO SIEMBRAS/
├── app_movil/              # Aplicación móvil Flutter (Offline-First)
│   ├── lib/                # Código fuente Dart (UI, DB SQLite, Servicios, Repositorios)
│   ├── assets/             # Recursos visuales e íconos de la app
│   └── test/               # Pruebas unitarias y de widgets
├── backend/                # Servidor API FastAPI
│   ├── app/                # Endpoints, queries Access, seguridad y configuración
│   └── tests/              # Pruebas de estrés y rendimiento
├── bmempresarial2021.accdb # Base de datos principal de Microsoft Access
├── backup_access.ps1       # Script automatizado de respaldo de base de datos
├── requirements.txt        # Dependencias de entorno Python
└── README.md               # Documentación y hoja de ruta del proyecto
```

---

## 🚀 Cronograma Maestro de Desarrollo (8 Semanas)

Este cronograma distribuye de forma modular el desarrollo completo del sistema a lo largo de 8 semanas. En la sesión actual se presenta formalmente el **Avance de la Semana 1**:

### 📍 Semana 1: Arquitectura Base, Conectividad y Persistencia Local (AVANCE ACTUAL)
- **Backend API**: Configuración inicial de FastAPI, conexión segura mediante `pyodbc` con cerrojo de concurrencia (`db_lock`) para proteger la base de datos Microsoft Access (`bmempresarial2021.accdb`). Autenticación por `X-API-Key`.
- **Estructura Móvil Flutter**: Inicialización de la aplicación móvil con arquitectura por capas, definición de entidades Dart (`Siembra`, `Variedad`, `Cama`, `Operario`).
- **Base de Datos Local (SQLite)**: Diseño y compilación del esquema relacional local (`schema_sqlite_offline.sql`, `local_db.dart`) para operación sin internet.

### 📅 Semana 2: Catálogos Maestros y Datos Semilla
- **Backend**: Endpoint de extracción de catálogos (`GET /api/catalogs`) para bloques, camas, variedades y operarios.
- **App Móvil**: Implementación de datos semilla (`seed_data.dart`) en SQLite local para disponibilidad inmediata sin conexión.
- **Repositorios**: Métodos de lectura y consulta local de maestros en `db_repository.dart`.

### 📅 Semana 3: Menú de Cultivos, Identidad Visual y Formulario Base
- **Identidad de la App**: Integración de íconos oficiales (`assets/icon/app_icon.png` y mipmaps en Android).
- **Selector de Cultivos**: Pantalla interactiva `menu_cultivos_screen.dart` con navegación visual.
- **Formulario Base**: Implementación de `form_siembra_screen.dart` con validaciones de campos obligatorios.

### 📅 Semana 4: Formularios Especializados y Lógica Agronómica
- **Formulario de Pompón**: Pantalla `form_siembra_pompon_screen.dart` con cálculo automático de tallos en tiempo real (líneas × factor agronómico para crisantemos, girasol, cremon, matsumoto).
- **Formulario de Lirios**: Pantalla `form_siembra_lirios_screen.dart` y `subgrupo_lirios_screen.dart` con control por calibres y subgrupos.
- **Persistencia**: Registro inmediato en SQLite en estado `pendiente_sincronizacion = 1`.

### 📅 Semana 5: Dashboard Operativo y Telemetría en Tiempo Real
- **Dashboard Principal**: Pantalla `dashboard_screen.dart` con métricas KPI (tallos totales, camas sembradas, variedad líder).
- **Control Semanal**: Selector dinámico de semana de siembra y filtros rápidos.
- **Telemetría de Red**: Servicio `network_service.dart` con indicador dinámico en tiempo real (*En línea / Fuera de línea*).

### 📅 Semana 6: Panel Hub de Administración Agronómica
- **Panel Administrativo Central**: Hub de control `admin_panel_hub_screen.dart`.
- **Gestión de Variedades**: Pantalla `admin_variedades_screen.dart`.
- **Ciclos por Variedad**: Pantalla `admin_ciclo_variedad_screen.dart` para parametrizar semanas de floración a cosecha.
- **Densidad de Plantas**: Pantalla `admin_densidad_plantas_screen.dart` y configuración global `admin_config_agronomica_screen.dart`.

### 📅 Semana 7: Motor de Sincronización Bidireccional y Reportes
- **Backend Sync**: Endpoint transaccional por lotes `POST /api/sync` con escritura segura en Access.
- **Servicio de Sincronización**: Lógica `sync_service.dart` con cola de reintentos y actualización de estados locales.
- **Historial y Reportes**: Pantalla `historial_screen.dart` y diálogo de exportación de reportes `reporte_dialog.dart` / `reporte_service.dart`.

### 📅 Semana 8: Pruebas de Carga, Respaldo Automático y Cierre
- **Pruebas de Estrés**: Suite `stress_test.py` simulando solicitudes concurrentes masivas contra el cerrojo de Access.
- **Copias de Seguridad**: Script automatizado `backup_access.ps1` con rotación histórica de copias de seguridad.
- **Control de Calidad**: Validación de código limpio y empaquetado final de producción.

---

## 🔒 Consideraciones de Seguridad y Acceso
- El archivo `.accdb` **no debe compartirse en red** directamente. Todo acceso debe pasar por el backend FastAPI.
- Se utiliza un sistema de **API Keys** (`X-API-Key`) para validar las peticiones desde los dispositivos móviles autorizados.
