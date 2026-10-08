# 🌸 Sistema de Gestión Integral de Siembras - Buenavista Flowers

> **Solución Móvil Offline-First para Captura Agronómica, Control de Rendimiento y Trazabilidad de Camas en Invernaderos.**

---

## 📌 Resumen Ejecutivo
El **Proyecto Siembras** sustituye de manera definitiva las tradicionales planillas físicas de papel en los invernaderos por una aplicación táctil en dispositivos Android. Su arquitectura **Offline-First** permite operar con autonomía total en zonas sin internet ni señal celular, guardando en la base de datos local SQLite y sincronizando bidireccionalmente con el computador central y la base de datos empresarial histórica (`bmempresarial2021.accdb`).

---

## 🚀 Características y Módulos Principales

### 1. 🌾 Registro Multi-Cultivo Táctil
* **Pompón y Cremón Bilateral:** División de cama en `Lado A (11 esq/lín)`, `Lado B (11 esq/lín)`, `Cama Completa (22 esq/lín)` y función `Pasó al otro lado` para operarios de apoyo.
* **Lirios Especializados:** Conteo por **Parrillas** en lugar de líneas. Multiplica automáticamente por **143 bulbos/parrilla** en Lirios LA y por **63 bulbos/parrilla** en Orientales (LO/OT). Vinculación a lotes de compra de la **Tabla 187**, proveedores holandeses/nacionales, contenedor y semanas de frío.
* **Rendimiento de Lirios por Canastas:** Botones rápidos de entrega para **400, 425 y 450 bulbos** (o **200, 225 y 250 bulbos**), permitiendo medir el trabajo individual en siembras colectivas.
* **Áreas Especiales de Propagación:** Módulos para *Planta Madre*, *Bancos de Enraizamiento* y *Núcleos Élite* con exclusión automática de sembrador individual.
* **Girasol, Matsumoto, Gerbera y Alstroemeria:** Formularios ajustados a densidades agronómicas de cada especie.

### 2. 🛡️ Inmutabilidad y Seguridad a 48 Horas
* Todo registro puede editarse o eliminarse durante **2 días calendario (48 horas)** directamente en el celular.
* Tras cumplirse el plazo, el registro se bloquea con **candado dorado**; cualquier modificación posterior queda reservada a la base de datos empresarial de la oficina.

### 3. 🥇 Ranking de Rendimiento y Podio de Medallas
* Medición de productividad en tiempo real por operario, promedio de tallos/cama y total cosechado.
* Reconocimiento motivacional con **Medalla de Oro (🥇)**, **Plata (🥈)** y **Bronce (🥉)** para los mejores sembradores de la jornada y de la semana.

### 4. 📄 Reportes Oficiales en PDF y WhatsApp
* Generación instantánea de informes formales con filtros por cultivo, semana agronómica estadounidense (Sem. 1 a 53) y rango de fechas.
* Previsualización integrada, almacenamiento en la carpeta Descargas y envío con un toque vía **WhatsApp** o correo.

### 5. 🔄 Sincronización a Demanda (Offline-First)
* Autonomía 100% en invernadero gracias a SQLite WAL en el dispositivo móvil.
* Al recuperar conexión Wi-Fi, un botón azul envía los lotes pendientes al backend REST API en Python/Node.js, integrándolos a Microsoft Access.

---

## 🛠️ Stack Tecnológico
* **App Móvil:** Flutter 3.x / Dart (Android, diseño responsive vertical y horizontal).
* **Persistencia Local:** SQLite con modo WAL y caché de catálogos en memoria.
* **Backend de Oficina:** Python FastAPI / Node.js con endpoints REST (`iniciar_backend.bat`).
* **Base de Datos Central:** Microsoft Access (`bmempresarial2021.accdb`).
* **Formatos de Reporte:** PDF con soporte para impresión térmica y estándar A4/Carta.

---

## 📚 Documentación del Proyecto
| Documento | Descripción |
| :--- | :--- |
| 📘 [DOCUMENTACION_USUARIO.docx](file:///d:/PROYECTO%20SIEMBRAS/DOCUMENTACION_USUARIO.docx) | Manual de usuario ultra-visual con 16 pantallazos paso a paso para el personal de campo. |
| 📗 [DESCRIPCION_DEL_PROYECTO.docx](file:///d:/PROYECTO%20SIEMBRAS/DESCRIPCION_DEL_PROYECTO.docx) | Descripción ejecutiva y funcional clara y concisa del proyecto. |
| 📙 [DOCUMENTACION_SOPORTE.docx](file:///d:/PROYECTO%20SIEMBRAS/DOCUMENTACION_SOPORTE.docx) | Manual técnico, mantenimiento de backend, bases de datos y resolución de fallas. |
| 📕 [DOCUMENTO_IEEE_PROYECTO_SIEMBRAS.docx](file:///d:/PROYECTO%20SIEMBRAS/DOCUMENTO_IEEE_PROYECTO_SIEMBRAS.docx) | Artículo científico en formato formal IEEE para sustentación académica o técnica. |
| 📓 [EXPLICACION_TECNICA_DESARROLLOS_SIEMBRAS.docx](file:///d:/PROYECTO%20SIEMBRAS/EXPLICACION_TECNICA_DESARROLLOS_SIEMBRAS.docx) | Bitácora de ingeniería y detalle de arquitectura del software. |
