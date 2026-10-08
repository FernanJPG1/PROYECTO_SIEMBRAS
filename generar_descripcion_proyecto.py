import os
import sys
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

sys.stdout.reconfigure(encoding='utf-8')

DOCX_PATH = r"d:\PROYECTO SIEMBRAS\DESCRIPCION_DEL_PROYECTO.docx"

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill_hex)
    tcPr.append(shd)

def set_cell_margins(cell, top=140, bottom=140, left=180, right=180):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('w:top', top), ('w:bottom', bottom), ('w:left', left), ('w:right', right)]:
        node = OxmlElement(m)
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def add_callout(doc, emoji, title, text, bg_hex="F1F8E9", border_color="7CB342"):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    table.columns[0].width = Inches(6.5)
    cell = table.cell(0, 0)
    set_cell_background(cell, bg_hex)
    set_cell_margins(cell, top=140, bottom=140, left=200, right=200)
    
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    left_b = OxmlElement('w:left')
    left_b.set(qn('w:val'), 'single')
    left_b.set(qn('w:sz'), '24')
    left_b.set(qn('w:space'), '0')
    left_b.set(qn('w:color'), border_color)
    tcBorders.append(left_b)
    for side in ['top', 'bottom', 'right']:
        b = OxmlElement(f'w:{side}')
        b.set(qn('w:val'), 'none')
        tcBorders.append(b)
    tcPr.append(tcBorders)

    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.line_spacing = 1.15
    run_title = p.add_run(f"{emoji} {title}\n")
    run_title.bold = True
    run_title.font.name = "Arial"
    run_title.font.size = Pt(11)
    run_title.font.color.rgb = RGBColor(46, 125, 50) if border_color == "7CB342" else RGBColor(21, 101, 192)

    run_text = p.add_run(text)
    run_text.font.name = "Arial"
    run_text.font.size = Pt(10)
    run_text.font.color.rgb = RGBColor(38, 50, 56)
    
    p_sp = doc.add_paragraph()
    p_sp.paragraph_format.space_before = Pt(0)
    p_sp.paragraph_format.space_after = Pt(4)

def add_heading_1(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(16)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.bold = True
    run.font.name = "Arial"
    run.font.size = Pt(15)
    run.font.color.rgb = RGBColor(46, 125, 50)
    return p

def add_heading_2(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.bold = True
    run.font.name = "Arial"
    run.font.size = Pt(12)
    run.font.color.rgb = RGBColor(51, 105, 30)
    return p

def add_paragraph(doc, text, bold_prefix=None):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    if bold_prefix:
        r_pre = p.add_run(bold_prefix)
        r_pre.bold = True
        r_pre.font.name = "Arial"
        r_pre.font.size = Pt(10)
        r_pre.font.color.rgb = RGBColor(38, 50, 56)
    run = p.add_run(text)
    run.font.name = "Arial"
    run.font.size = Pt(10)
    run.font.color.rgb = RGBColor(55, 71, 79)
    return p

doc = docx.Document()

# Margins
for s in doc.sections:
    s.top_margin = Inches(0.8)
    s.bottom_margin = Inches(0.8)
    s.left_margin = Inches(0.8)
    s.right_margin = Inches(0.8)

# Header corporate
p_top = doc.add_paragraph()
p_top.paragraph_format.space_before = Pt(10)
p_top.paragraph_format.space_after = Pt(2)
p_top.alignment = WD_ALIGN_PARAGRAPH.CENTER
r_top = p_top.add_run("BUENAVISTA FLOWERS • DOCUMENTO EJECUTIVO DE PROYECTO")
r_top.bold = True
r_top.font.name = "Arial"
r_top.font.size = Pt(10.5)
r_top.font.color.rgb = RGBColor(124, 179, 66)

p_title = doc.add_paragraph()
p_title.paragraph_format.space_before = Pt(4)
p_title.paragraph_format.space_after = Pt(6)
p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
r_title = p_title.add_run("DESCRIPCIÓN INTEGRAL DEL PROYECTO\nSISTEMA DE GESTIÓN DE SIEMBRAS")
r_title.bold = True
r_title.font.name = "Arial"
r_title.font.size = Pt(20)
r_title.font.color.rgb = RGBColor(46, 125, 50)

p_sub = doc.add_paragraph()
p_sub.paragraph_format.space_before = Pt(2)
p_sub.paragraph_format.space_after = Pt(16)
p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
r_sub = p_sub.add_run("Visión General, Arquitectura Técnica, Módulos Operativos e Impacto en Invernaderos Florícolas")
r_sub.font.name = "Arial"
r_sub.font.size = Pt(11.5)
r_sub.font.color.rgb = RGBColor(84, 110, 122)

add_callout(
    doc,
    "📋",
    "RESUMEN EJECUTIVO EN UNA FRASE",
    "El Proyecto Siembras es una solución móvil integral Offline-First (100% operativa sin internet) que reemplaza las planillas físicas de papel en los invernaderos por captura táctil en Android, automatizando la división de camas, el rendimiento por operario, la trazabilidad de lotes de compra y la sincronización bidireccional con la base de datos central de la empresa.",
    bg_hex="F1F8E9",
    border_color="7CB342"
)

# 1. FICHA TÉCNICA DEL PROYECTO
add_heading_1(doc, "1. FICHA TÉCNICA DEL PROYECTO")

ficha_data = [
    ("Nombre del Sistema", "Sistema de Gestión y Control Integral de Siembras"),
    ("Empresa / Ámbito", "Buenavista Flowers (Invernaderos y Floricultura Comercial)"),
    ("Dispositivo Objetivo", "Smartphones y Tablets Android (Motorola Moto G52 / Dispositivos de Campo)"),
    ("Arquitectura", "Offline-First Híbrida: SQLite Local WAL + Backend REST API + Base Central Microsoft Access"),
    ("Lenguajes y Frameworks", "Flutter 3.x (Dart), Python 3.13 / Node.js, SQLite3 Local, Access (`bmempresarial2021.accdb`)"),
    ("Cultivos Soportados", "Lirios (LA, LO, OT), Cremón, Pompón, Girasol, Matsumoto, Gerbera, Alstroemeria, Áreas Especiales"),
    ("Módulos Clave", "División Bilateral de Camas, Conteo de Parrillas, Rendimiento por Canastas, Podio de Medallas, Reportes PDF")
]

t_ficha = doc.add_table(rows=len(ficha_data) + 1, cols=2)
t_ficha.alignment = WD_TABLE_ALIGNMENT.CENTER
t_ficha.columns[0].width = Inches(2.2)
t_ficha.columns[1].width = Inches(4.3)

h_f = t_ficha.rows[0].cells
h_f[0].text = "PARÁMETRO"
h_f[1].text = "DETALLE TÉCNICO / ESPECIFICACIÓN"
set_cell_background(h_f[0], "2E7D32")
set_cell_background(h_f[1], "2E7D32")
for c in h_f:
    for p in c.paragraphs:
        for r in p.runs:
            r.bold = True
            r.font.name = "Arial"
            r.font.color.rgb = RGBColor(255, 255, 255)
            r.font.size = Pt(9.5)

for idx, (param, val) in enumerate(ficha_data):
    row_c = t_ficha.rows[idx + 1].cells
    row_c[0].text = param
    row_c[1].text = val
    bg = "F9FBE7" if idx % 2 == 0 else "FFFFFF"
    set_cell_background(row_c[0], bg)
    set_cell_background(row_c[1], bg)
    for c in row_c:
        for p in c.paragraphs:
            for r in p.runs:
                r.font.name = "Arial"
                r.font.size = Pt(9)
                r.font.color.rgb = RGBColor(38, 50, 56)

# 2. PROBLEMA QUE RESUELVE
add_heading_1(doc, "2. PROBLEMA QUE RESUELVE Y MOTIVACIÓN")
add_paragraph(doc, "Tradicionalmente, en la industria florícola la siembra de camas se registraba a mano en hojas de papel sujetas con tablas de madera. Esta metodología histórica presentaba deficiencias críticas:")
add_paragraph(doc, "• Planillas mojadas o dañadas por el barro, la humedad relativa (85%+) y las labores de riego.", "1. Deterioro físico: ")
add_paragraph(doc, "• Retrasos de 24 a 72 horas para que la oficina técnica digitara la información en el computador central.", "2. Pérdida de tiempo: ")
add_paragraph(doc, "• Errores humanos de digitación, números ilegibles de operarios y camas duplicadas o mal asignadas.", "3. Calidad de datos: ")
add_paragraph(doc, "• Sombra de señal celular: En el 80% de los bloques de invernadero no hay señal Wi-Fi ni datos móviles, lo que impedía usar soluciones web tradicionales.", "4. Conectividad nula: ")

add_paragraph(doc, "El Proyecto Siembras soluciona de raíz todos estos problemas permitiendo captura instantánea, validaciones agronómicas en tiempo real y funcionamiento 100% desconectado.")

# 3. PILARES ARQUITECTÓNICOS
add_heading_1(doc, "3. PILARES DE LA SOLUCIÓN TÉCNICA")

add_heading_2(doc, "A. Filosofía Offline-First con SQLite WAL")
add_paragraph(doc, "La aplicación móvil no depende de un servidor para guardar datos. Toda la información de catálogo (operarios, variedades, camas, lotes de compra) se almacena localmente en la base de datos SQLite del teléfono con modo WAL (Write-Ahead Logging). Cada siembra se guarda en menos de 0.2 segundos sin importar si hay o no internet.")

add_heading_2(doc, "B. Sincronización a Demanda con Microsoft Access")
add_paragraph(doc, "Al finalizar la jornada o llegar a la oficina, el supervisor presiona el botón 'Sincronizar'. El sistema emite peticiones HTTP seguras hacia el backend, el cual inserta las siembras directamente en la base de datos empresarial histórica (`bmempresarial2021.accdb`), manteniendo intacta la infraestructura tecnológica preexistente de la compañía.")

add_heading_2(doc, "C. Diseño Táctil Adaptativo y Ultra-Fácil")
add_paragraph(doc, "La interfaz fue desarrollada con principios de accesibilidad cognitiva y visual: botones de gran tamaño, código de colores estandarizado, iconografía florícola, retroalimentación sonora y cálculo automático de fórmulas para que cualquier operario de campo pueda usarla sin curva de aprendizaje.")

# 4. MÓDULOS OPERATIVOS PRINCIPALES
add_heading_1(doc, "4. DESCRIPCIÓN DE LOS MÓDULOS OPERATIVOS")

modulos = [
    ("1. Dashboard y Monitoreo KPI", "Pantalla principal que muestra el resumen diario: total de siembras, conteo de esquejes/bulbos, bloques activos, filtros instantáneos por flor (Pompón, Cremón, Lirios, etc.) y tarjetas interactivas de cada cama."),
    ("2. Menú Visual de Cultivos", "Selector con tarjetas diferenciadas por colores e íconos para cada flor: Lirios, Cremón, Pompón, Girasol, Matsumoto, Gerbera, Alstroemeria, Planta Madre, Bancos y Núcleos de Propagación."),
    ("3. División Bilateral de Cama (Pompón y Cremón)", "Resuelve la siembra compartida entre dos sembradores. Permite seleccionar con un toque: Lado A (11 esq/lín), Lado B (11 esq/lín), Cama Completa (22 esq/lín) y el botón 'Pasó al otro lado' para operarios rápidos que apoyan al compañero."),
    ("4. Áreas Especiales (Propagación)", "Módulo especializado para Plantas Madre, Bancos de Enraizamiento y Núcleos Élite donde se excluye automáticamente la asignación de sembrador individual para no distorsionar las métricas de rendimiento."),
    ("5. Módulo Especializado de Lirios", "Revoluciona el conteo de bulbos: sustituye las líneas por PARRILLAS de alambre. Calcula automáticamente según la especie: Lirio LA a 143 bulbos/parrilla y Orientales (LO/OT) a 63 bulbos/parrilla. Vincula lotes de compra de la Tabla 187, contenedor y semanas de frío."),
    ("6. Rendimiento de Lirios por Canastas", "Mide la labor colectiva de siembra registrando canastas individuales entregadas por operario. Ofrece botones rápidos de 400, 425 y 450 bulbos (o 200, 225 y 250 bulbos) y campo para canastas atípicas."),
    ("7. Seguridad e Inmutabilidad a 2 Días", "Mecanismo de seguridad que permite editar o corregir registros durante 48 horas. Cumplido este plazo, la siembra se bloquea con candado dorado para garantizar la integridad fiscal y agronómica."),
    ("8. Ranking de Rendimiento y Podio de Medallas", "Evalúa la productividad de los sembradores premiando el esfuerzo diario y semanal con medallas de honor: 🥇 Oro (primer puesto), 🥈 Plata (segundo) y 🥉 Bronce (tercero)."),
    ("9. Reportes Oficiales en PDF y WhatsApp", "Generador de informes profesionales en PDF que agrupa camas, variedades, tallos y líderes de rendimiento. Permite previsualizar, guardar o compartir el documento por WhatsApp en segundos."),
    ("10. Motor de Variedades Temporales y Sincronización", "Permite registrar flores nuevas o de ensayo de manera provisional sin detener la siembra, y sincronizar por lotes con la base empresarial al retomar conectividad.")
]

t_mod = doc.add_table(rows=len(modulos) + 1, cols=2)
t_mod.alignment = WD_TABLE_ALIGNMENT.CENTER
t_mod.columns[0].width = Inches(2.2)
t_mod.columns[1].width = Inches(4.3)

h_m = t_mod.rows[0].cells
h_m[0].text = "MÓDULO DEL SISTEMA"
h_m[1].text = "ALCANCE Y FUNCIONALIDAD PRINCIPAL"
set_cell_background(h_m[0], "1B5E20")
set_cell_background(h_m[1], "1B5E20")
for c in h_m:
    for p in c.paragraphs:
        for r in p.runs:
            r.bold = True
            r.font.name = "Arial"
            r.font.color.rgb = RGBColor(255, 255, 255)
            r.font.size = Pt(9.5)

for idx, (mod, desc) in enumerate(modulos):
    row_c = t_mod.rows[idx + 1].cells
    row_c[0].text = mod
    row_c[1].text = desc
    bg = "F9FBE7" if idx % 2 == 0 else "FFFFFF"
    set_cell_background(row_c[0], bg)
    set_cell_background(row_c[1], bg)
    for c in row_c:
        for p in c.paragraphs:
            for r in p.runs:
                r.font.name = "Arial"
                r.font.size = Pt(9)
                r.font.color.rgb = RGBColor(38, 50, 56)

# 5. BENEFICIOS E IMPACTO MEDIBLE
add_heading_1(doc, "5. BENEFICIOS E IMPACTO EN LA OPERACIÓN")

add_paragraph(doc, "La implementación del Sistema de Siembras genera ventajas operativas medibles y cuantificables en los invernaderos:")

beneficios = [
    ("Tiempo de Registro", "De 3-5 minutos por cama en papel a menos de 15 segundos en el celular."),
    ("Disponibilidad de Información", "De 24 a 72 horas de espera a Disponibilidad Inmediata en tiempo real."),
    ("Tasa de Error en Captura", "Reducción estimada del 98% en errores de variedad, camas equivocadas o cifras ilegibles."),
    ("Trazabilidad de Bulbos", "Control 100% digitalizado de lotes de importación (Tabla 187), proveedores y contenedores."),
    ("Clima Laboral y Transparencia", "El personal conoce su rendimiento diario exacto y las medallas obtenidas, incentivando la productividad y la equidad salarial."),
    ("Cero Pérdida de Datos", "Almacenamiento persistente en base de datos local resistente a reinicios, cortes de batería y zonas sin internet.")
]

t_ben = doc.add_table(rows=len(beneficios) + 1, cols=2)
t_ben.alignment = WD_TABLE_ALIGNMENT.CENTER
t_ben.columns[0].width = Inches(2.2)
t_ben.columns[1].width = Inches(4.3)

h_b = t_ben.rows[0].cells
h_b[0].text = "ÁREA DE IMPACTO"
h_b[1].text = "MEJORA CUANTIFICABLE CON EL SISTEMA"
set_cell_background(h_b[0], "2E7D32")
set_cell_background(h_b[1], "2E7D32")
for c in h_b:
    for p in c.paragraphs:
        for r in p.runs:
            r.bold = True
            r.font.name = "Arial"
            r.font.color.rgb = RGBColor(255, 255, 255)
            r.font.size = Pt(9.5)

for idx, (area, mej) in enumerate(beneficios):
    row_c = t_ben.rows[idx + 1].cells
    row_c[0].text = area
    row_c[1].text = mej
    bg = "F9FBE7" if idx % 2 == 0 else "FFFFFF"
    set_cell_background(row_c[0], bg)
    set_cell_background(row_c[1], bg)
    for c in row_c:
        for p in c.paragraphs:
            for r in p.runs:
                r.font.name = "Arial"
                r.font.size = Pt(9)
                r.font.color.rgb = RGBColor(38, 50, 56)

p_foot = doc.add_paragraph()
p_foot.paragraph_format.space_before = Pt(24)
p_foot.alignment = WD_ALIGN_PARAGRAPH.CENTER
r_foot = p_foot.add_run("PROYECTO SIEMBRAS • BUENAVISTA FLOWERS\nTecnología Móvil al Servicio del Campo Colombiano")
r_foot.bold = True
r_foot.font.name = "Arial"
r_foot.font.size = Pt(10.5)
r_foot.font.color.rgb = RGBColor(46, 125, 50)

doc.save(DOCX_PATH)
print(f"¡DOCUMENTO DESCRIPTIVO GENERADO CON ÉXITO EN: {DOCX_PATH}!")
