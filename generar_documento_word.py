import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, fill_hex):
    """Establece el color de fondo de una celda."""
    shading_elm = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    cell._tc.get_or_add_tcPr().append(shading_elm)

def set_cell_margins(cell, top=120, bottom=120, left=160, right=160):
    """Establece márgenes internos (padding) de la celda en dxa (1 pt = 20 dxa)."""
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for m, val in [('top', top), ('bottom', bottom), ('left', left), ('right', right)]:
        node = OxmlElement(f'w:{m}')
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tcMar.append(node)
    tcPr.append(tcMar)

def set_cell_border_left_only(cell, color_hex="2E7D32", sz="36"):
    """Crea una barra de resalte a la izquierda de la celda (estilo callout)."""
    tcPr = cell._tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    
    # Left border grueso
    left = OxmlElement('w:left')
    left.set(qn('w:val'), 'single')
    left.set(qn('w:sz'), sz) # 36 = 4.5 pt
    left.set(qn('w:space'), '0')
    left.set(qn('w:color'), color_hex)
    tcBorders.append(left)
    
    # Resto de bordes invisibles
    for b_name in ['top', 'bottom', 'right']:
        b = OxmlElement(f'w:{b_name}')
        b.set(qn('w:val'), 'none')
        tcBorders.append(b)
        
    tcPr.append(tcBorders)

def set_table_borders(table, color="D0D7DE", sz="4"):
    """Aplica bordes sutiles a toda la tabla."""
    tblPr = table._tbl.tblPr
    tblBorders = OxmlElement('w:tblBorders')
    for b_name in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
        border = OxmlElement(f'w:{b_name}')
        border.set(qn('w:val'), 'single')
        border.set(qn('w:sz'), sz)
        border.set(qn('w:space'), '0')
        border.set(qn('w:color'), color)
        tblBorders.append(border)
    tblPr.append(tblBorders)

def crear_callout(doc, titulo, texto, tipo="info"):
    """Crea un cuadro de texto destacado (callout)."""
    colores = {
        "info": {"bg": "F1F8E9", "border": "33691E", "title_color": RGBColor(0x33, 0x69, 0x1E)},
        "warning": {"bg": "FFF8E1", "border": "E65100", "title_color": RGBColor(0xE6, 0x51, 0x00)},
        "success": {"bg": "E8F5E9", "border": "2E7D32", "title_color": RGBColor(0x2E, 0x7D, 0x32)},
    }
    cfg = colores.get(tipo, colores["info"])
    
    tbl = doc.add_table(rows=1, cols=1)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    tbl.autofit = False
    tbl.columns[0].width = Inches(6.5)
    
    cell = tbl.cell(0, 0)
    set_cell_background(cell, cfg["bg"])
    set_cell_border_left_only(cell, cfg["border"], sz="36")
    set_cell_margins(cell, top=140, bottom=140, left=200, right=180)
    
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    run_t = p.add_run(f"📌 {titulo}\n")
    run_t.bold = True
    run_t.font.size = Pt(11)
    run_t.font.name = "Calibri"
    run_t.font.color.rgb = cfg["title_color"]
    
    run_c = p.add_run(texto)
    run_c.font.size = Pt(10)
    run_c.font.name = "Calibri"
    run_c.font.color.rgb = RGBColor(0x26, 0x32, 0x38)
    
    # Espacio después del callout
    p_after = doc.add_paragraph()
    p_after.paragraph_format.space_before = Pt(0)
    p_after.paragraph_format.space_after = Pt(6)

def generar_documento():
    doc = Document()
    
    # Configuración de Márgenes (Estándar 1 pulgada)
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        
    # Paleta de Colores Corporativa
    COLOR_PRIMARY = RGBColor(0x1B, 0x5E, 0x20)    # Verde Oscuro Bosque
    COLOR_SECONDARY = RGBColor(0x33, 0x69, 0x1E)  # Verde Agronómico
    COLOR_MUTED = RGBColor(0x55, 0x8B, 0x2F)      # Verde Oliva
    COLOR_TEXT = RGBColor(0x26, 0x32, 0x38)       # Gris Grafito
    COLOR_WARNING = RGBColor(0xE6, 0x51, 0x00)    # Naranja Alerta
    
    # ----------------------------------------------------
    # ENCABEZADO Y TÍTULO PRINCIPAL
    # ----------------------------------------------------
    p_empresa = doc.add_paragraph()
    p_empresa.paragraph_format.space_before = Pt(0)
    p_empresa.paragraph_format.space_after = Pt(2)
    p_empresa.alignment = WD_ALIGN_PARAGRAPH.LEFT
    r_empresa = p_empresa.add_run("BUENAVISTA FLOWERS • SISTEMA DE GESTIÓN INTEGRAL DE SIEMBRAS")
    r_empresa.bold = True
    r_empresa.font.name = "Calibri"
    r_empresa.font.size = Pt(9.5)
    r_empresa.font.color.rgb = COLOR_MUTED
    
    p_title = doc.add_paragraph()
    p_title.paragraph_format.space_before = Pt(2)
    p_title.paragraph_format.space_after = Pt(6)
    r_title = p_title.add_run("PROTOCOLO OPERATIVO Y SOLUCIÓN TÉCNICA:\nDESBLOQUEO DE CAMAS POR ADELANTO DE CICLO VEGETATIVO NATURAL")
    r_title.bold = True
    r_title.font.name = "Calibri"
    r_title.font.size = Pt(17)
    r_title.font.color.rgb = COLOR_PRIMARY
    
    p_meta = doc.add_paragraph()
    p_meta.paragraph_format.space_before = Pt(0)
    p_meta.paragraph_format.space_after = Pt(14)
    r_meta = p_meta.add_run("Procedimiento Estándar (SOP-AGRO-004) | Aplicación Móvil & Base de Datos Access | Octubre 2026")
    r_meta.italic = True
    r_meta.font.name = "Calibri"
    r_meta.font.size = Pt(9.5)
    r_meta.font.color.rgb = RGBColor(0x75, 0x75, 0x75)
    
    # Línea divisoria decorativa
    p_line = doc.add_paragraph()
    p_line.paragraph_format.space_before = Pt(0)
    p_line.paragraph_format.space_after = Pt(12)
    r_line = p_line.add_run("―" * 55)
    r_line.font.color.rgb = RGBColor(0xC8, 0xE6, 0xC9)
    r_line.bold = True

    # ----------------------------------------------------
    # 1. RESUMEN EJECUTIVO Y DEFINICIÓN DEL CASO
    # ----------------------------------------------------
    h1 = doc.add_heading("1. Descripción del Caso Hipotético", level=1)
    h1.paragraph_format.space_before = Pt(10)
    h1.paragraph_format.space_after = Pt(4)
    h1.runs[0].font.name = "Calibri"
    h1.runs[0].font.size = Pt(13)
    h1.runs[0].font.color.rgb = COLOR_PRIMARY
    
    p_caso = doc.add_paragraph()
    p_caso.paragraph_format.line_spacing = 1.15
    p_caso.paragraph_format.space_after = Pt(8)
    p_caso.add_run(
        "Caso planteado: «Si alguna variedad se adelanta en el ciclo por factores naturales "
        "(radiación solar favorable, temperaturas altas, excelente enraizamiento, etc.), "
        "se procede al corte completo de la flor en la cama y se necesita utilizar y sembrar de nuevo de inmediato; "
        "sin embargo, el sistema y la base de datos mantienen la cama bloqueada indicando que el ciclo agronómico "
        "teórico aún no se ha cumplido. ¿Cómo se soluciona de forma operativa y definitiva?»"
    ).italic = True

    crear_callout(
        doc,
        "Diagnóstico Rápido del Problema",
        "El bloqueo ocurre porque el software implementa una regla agronómica de seguridad preventiva "
        "diseñada para evitar que dos lotes choquen o se sobre-siembren por error. "
        "Cuando el clima o la biología adelantan la cosecha real respecto a la fecha teórica estimada, "
        "el sistema requiere una confirmación formal de corte o ajuste de parámetros para liberar la cama.",
        tipo="info"
    )

    # ----------------------------------------------------
    # 2. ¿POR QUÉ OCURRE EL BLOQUEO EN EL SISTEMA?
    # ----------------------------------------------------
    h2 = doc.add_heading("2. Diagnóstico Técnico: Los Dos Mecanismos de Bloqueo", level=1)
    h2.paragraph_format.space_before = Pt(12)
    h2.paragraph_format.space_after = Pt(4)
    h2.runs[0].font.name = "Calibri"
    h2.runs[0].font.size = Pt(13)
    h2.runs[0].font.color.rgb = COLOR_PRIMARY
    
    p_diag = doc.add_paragraph()
    p_diag.paragraph_format.line_spacing = 1.15
    p_diag.paragraph_format.space_after = Pt(6)
    p_diag.add_run(
        "En el ecosistema tecnológico de Siembras (App Móvil Flutter + SQLite local + Base de Datos Central Access bmempresarial2021.accdb), "
        "el estado de una cama está gobernado por dos validaciones concurrentes:"
    )

    # Tabla explicativa de las 2 causas
    tbl_causas = doc.add_table(rows=3, cols=3)
    tbl_causas.alignment = WD_TABLE_ALIGNMENT.CENTER
    tbl_causas.autofit = False
    tbl_causas.columns[0].width = Inches(1.3)
    tbl_causas.columns[1].width = Inches(2.2)
    tbl_causas.columns[2].width = Inches(3.0)
    set_table_borders(tbl_causas)
    
    headers = ["Componente", "Causa del Bloqueo", "Efecto en Pantalla"]
    for i, title in enumerate(headers):
        cell = tbl_causas.cell(0, i)
        set_cell_background(cell, "2E7D32")
        set_cell_margins(cell, top=100, bottom=100, left=120, right=120)
        p = cell.paragraphs[0]
        r = p.add_run(title)
        r.bold = True
        r.font.name = "Calibri"
        r.font.size = Pt(10)
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        
    filas_causas = [
        ("Causa A:\nEstado de Siembra", "La siembra previa permanece en estado 'ACTIVA' porque el corte no fue reportado en la app.", "Al intentar sembrar, la app reporta: 'Cama Ocupada / Cupo Lleno' y prohíbe nueva siembra."),
        ("Causa B:\nCiclo Mínimo", "La variedad tiene parametrizados días teóricos (ej. 90 días) y han transcurrido menos días (ej. 75 días).", "La app reporta: 'Restricción de Ciclo Agronómico: La siembra requiere un mínimo de 90 días (faltan 15 días)'.")
    ]
    for row_idx, (comp, causa, efecto) in enumerate(filas_causas, start=1):
        bg = "F9FBE7" if row_idx % 2 == 1 else "FFFFFF"
        for col_idx, texto in enumerate([comp, causa, efecto]):
            cell = tbl_causas.cell(row_idx, col_idx)
            set_cell_background(cell, bg)
            set_cell_margins(cell, top=80, bottom=80, left=100, right=100)
            p = cell.paragraphs[0]
            p.paragraph_format.line_spacing = 1.1
            r = p.add_run(texto)
            r.font.name = "Calibri"
            r.font.size = Pt(9.5)
            r.font.color.rgb = COLOR_TEXT
            if col_idx == 0:
                r.bold = True
                
    doc.add_paragraph().paragraph_format.space_after = Pt(6)

    # ----------------------------------------------------
    # 3. MÉTODOS DE SOLUCIÓN PASO A PASO
    # ----------------------------------------------------
    h3 = doc.add_heading("3. Métodos de Solución Inmediatos", level=1)
    h3.paragraph_format.space_before = Pt(12)
    h3.paragraph_format.space_after = Pt(4)
    h3.runs[0].font.name = "Calibri"
    h3.runs[0].font.size = Pt(13)
    h3.runs[0].font.color.rgb = COLOR_PRIMARY

    # MÉTODO 1
    doc.add_heading("Método 1: Solución Estándar desde la App Móvil (Finalización de Ciclo y Registro de Corte)", level=2)
    p_m1 = doc.add_paragraph()
    p_m1.paragraph_format.line_spacing = 1.15
    p_m1.paragraph_format.space_after = Pt(4)
    p_m1.add_run(
        "Es el procedimiento operativo natural en campo. No requiere acceso a computadores ni conocimientos técnicos de bases de datos:"
    )
    
    pasos_m1 = [
        ("Paso 1: Localizar la Cama en el Dashboard Móvil", "En la pantalla principal de la tablet o celular, ubique el registro de la siembra correspondiente a la cama que acaba de ser cortada (puede usar el buscador de variedades, bloques o camas)."),
        ("Paso 2: Abrir las Opciones del Registro", "Toque la fila de la siembra en la tabla. Se desplegará el menú inferior de opciones de la cama."),
        ("Paso 3: Seleccionar «Finalizar Ciclo de Siembra»", "Pulse el botón «Finalizar Ciclo de Siembra» (ícono de calendario con check verde)."),
        ("Paso 4: Ingresar la Fecha Real de Corte", "El sistema abrirá un diálogo que muestra los días transcurridos y el aviso de «¡Ciclo Agronómico Incompleto! (Cosecha anticipada o descarte)». Ingrese o confirme la fecha real del corte (DD/MM/AAAA) y presione «Finalizar Ciclo»."),
        ("Paso 5: Sincronizar", "La siembra cambiará inmediatamente a estado 'FINALIZADA'. Pulse el botón superior 'SINCRONIZAR' para que la base de datos empresarial en el servidor PC reciba la fecha de corte y libere el histórico.")
    ]
    for p_title, p_desc in pasos_m1:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Inches(0.25)
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.15
        r_num = p.add_run(f"• {p_title}: ")
        r_num.bold = True
        r_num.font.name = "Calibri"
        r_num.font.size = Pt(10)
        r_num.font.color.rgb = COLOR_SECONDARY
        r_text = p.add_run(p_desc)
        r_text.font.name = "Calibri"
        r_text.font.size = Pt(9.5)
        r_text.font.color.rgb = COLOR_TEXT

    # MÉTODO 2
    doc.add_heading("Método 2: Ajuste de Días de Ciclo desde el Panel de Administrador de la App", level=2)
    p_m2 = doc.add_paragraph()
    p_m2.paragraph_format.line_spacing = 1.15
    p_m2.paragraph_format.space_after = Pt(4)
    p_m2.add_run(
        "Si la variedad se está cortando consistentemente antes debido a una temporada de calor o verano intenso, "
        "el Agrónomo o Administrador puede recalibrar los días oficiales del ciclo sin tocar código:"
    )
    
    pasos_m2 = [
        ("Paso 1: Ingreso al Panel Administrativo", "En la barra superior de la app móvil, presione el ícono de Escudo (Panel de Administrador). Ingrese el PIN de seguridad agronómica autorizado (ej. 2026)."),
        ("Paso 2: Administrar Variedades / Parámetros Agronómicos", "Seleccione la opción «Configuraciones Agronómicas» o busque la variedad en la lista del panel."),
        ("Paso 3: Modificar los «Días de Ciclo»", "Cambie el valor teórico de días (por ejemplo, reducir de 90 a 75 días o los días que duró la cosecha real)."),
        ("Paso 4: Guardar y Aplicar", "Presione «Guardar Cambios». El validador de camas tomará el nuevo umbral inmediatamente y la cama quedará habilitada para nueva siembra sin restricción alguna.")
    ]
    for p_title, p_desc in pasos_m2:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Inches(0.25)
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.15
        r_num = p.add_run(f"• {p_title}: ")
        r_num.bold = True
        r_num.font.name = "Calibri"
        r_num.font.size = Pt(10)
        r_num.font.color.rgb = COLOR_SECONDARY
        r_text = p.add_run(p_desc)
        r_text.font.name = "Calibri"
        r_text.font.size = Pt(9.5)
        r_text.font.color.rgb = COLOR_TEXT

    # MÉTODO 3
    doc.add_heading("Método 3: Desbloqueo y Gestión Directa en la Base de Datos Access (Oficina)", level=2)
    p_m3 = doc.add_paragraph()
    p_m3.paragraph_format.line_spacing = 1.15
    p_m3.paragraph_format.space_after = Pt(4)
    p_m3.add_run(
        "Cuando el ajuste se realiza directamente desde la oficina central en el archivo bmempresarial2021.accdb:"
    )
    
    pasos_m3 = [
        ("Tabla de Siembras (t50 / tb_siembras)", "Abrir la tabla de siembras en Access. Ubicar la siembra previa de la cama en cuestión. Actualizar el campo 'fecha_fin' con la fecha de corte y asegurar que el campo 'estado' sea 'FINALIZADA'."),
        ("Tabla de Variedades (t11)", "Si se desea ajustar el ciclo estándar de la variedad en toda la empresa, en la tabla t11 editar el campo correspondiente a días de rotación."),
        ("Sincronización Inalámbrica", "Al ejecutar la sincronización en los celulares, la app descargará los catálogos y el estado actualizado, desbloqueando la cama al instante.")
    ]
    for p_title, p_desc in pasos_m3:
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Inches(0.25)
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.15
        r_num = p.add_run(f"• {p_title}: ")
        r_num.bold = True
        r_num.font.name = "Calibri"
        r_num.font.size = Pt(10)
        r_num.font.color.rgb = COLOR_SECONDARY
        r_text = p.add_run(p_desc)
        r_text.font.name = "Calibri"
        r_text.font.size = Pt(9.5)
        r_text.font.color.rgb = COLOR_TEXT

    # ----------------------------------------------------
    # 4. MEJORA RECOMENDADA EN EL SOFTWARE (SOLUCIÓN DEFINITIVA)
    # ----------------------------------------------------
    h4 = doc.add_heading("4. Mejora Recomendada en el Software (Solución Automática Definitiva)", level=1)
    h4.paragraph_format.space_before = Pt(12)
    h4.paragraph_format.space_after = Pt(4)
    h4.runs[0].font.name = "Calibri"
    h4.runs[0].font.size = Pt(13)
    h4.runs[0].font.color.rgb = COLOR_PRIMARY

    p_sol_def = doc.add_paragraph()
    p_sol_def.paragraph_format.line_spacing = 1.15
    p_sol_def.paragraph_format.space_after = Pt(6)
    p_sol_def.add_run(
        "Para que los operarios y supervisores nunca vuelvan a quedar atrapados en este escenario sin necesidad de recurrir a la oficina, "
        "se recomienda una optimización directa en la lógica del validador de camas de la aplicación móvil:"
    )

    crear_callout(
        doc,
        "Lógica Inteligente de Corte Confirmado",
        "Regla a implementar: Si una cama tiene una siembra previa que ya fue marcada con fecha de corte ('fecha_fin') "
        "o finalizada explícitamente, la cama se considera FÍSICAMENTE VACÍA Y LIBERADA. "
        "El sistema no debe impedir la nueva siembra; simplemente debe emitir un mensaje informativo: "
        "«Cama disponible tras corte anticipado (Días de ciclo real: XX días de YY teóricos)». "
        "De este modo, se respeta la realidad agronómica del campo sin romper la trazabilidad histórica.",
        tipo="success"
    )

    # ----------------------------------------------------
    # 5. MATRIZ DE DECISIÓN Y BUENAS PRÁCTICAS AGRONÓMICAS
    # ----------------------------------------------------
    h5 = doc.add_heading("5. Matriz de Decisión Operativa para el Equipo de Campo", level=1)
    h5.paragraph_format.space_before = Pt(12)
    h5.paragraph_format.space_after = Pt(4)
    h5.runs[0].font.name = "Calibri"
    h5.runs[0].font.size = Pt(13)
    h5.runs[0].font.color.rgb = COLOR_PRIMARY

    tbl_matriz = doc.add_table(rows=4, cols=4)
    tbl_matriz.alignment = WD_TABLE_ALIGNMENT.CENTER
    tbl_matriz.autofit = False
    tbl_matriz.columns[0].width = Inches(1.8)
    tbl_matriz.columns[1].width = Inches(1.5)
    tbl_matriz.columns[2].width = Inches(1.5)
    tbl_matriz.columns[3].width = Inches(1.7)
    set_table_borders(tbl_matriz)
    
    m_headers = ["Escenario de Campo", "Acción Recomendada", "Responsable", "Tiempo de Solución"]
    for i, title in enumerate(m_headers):
        cell = tbl_matriz.cell(0, i)
        set_cell_background(cell, "1B5E20")
        set_cell_margins(cell, top=100, bottom=100, left=100, right=100)
        p = cell.paragraphs[0]
        r = p.add_run(title)
        r.bold = True
        r.font.name = "Calibri"
        r.font.size = Pt(9.5)
        r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        
    filas_matriz = [
        ("Corte anticipado puntual en 1 o pocas camas", "Usar 'Finalizar Ciclo' desde la app indicando fecha de corte.", "Supervisor de Bloque / Sembrador", "Inmediato (< 1 minuto)"),
        ("Toda la variedad se adelanta por temporada de calor", "Ajustar 'Días de Ciclo' en el Panel de Administrador de la app.", "Jefe de Cultivo / Agrónomo", "< 2 minutos en celular"),
        ("Ajuste masivo de rotación en planificación anual", "Modificar parámetros en tabla t11 de Access y sincronizar.", "Administrador de Sistemas / Oficina", "< 5 minutos en PC")
    ]
    for row_idx, (esc, acc, resp, tiempo) in enumerate(filas_matriz, start=1):
        bg = "F1F8E9" if row_idx % 2 == 1 else "FFFFFF"
        for col_idx, texto in enumerate([esc, acc, resp, tiempo]):
            cell = tbl_matriz.cell(row_idx, col_idx)
            set_cell_background(cell, bg)
            set_cell_margins(cell, top=80, bottom=80, left=90, right=90)
            p = cell.paragraphs[0]
            p.paragraph_format.line_spacing = 1.1
            r = p.add_run(texto)
            r.font.name = "Calibri"
            r.font.size = Pt(9)
            r.font.color.rgb = COLOR_TEXT
            if col_idx == 0:
                r.bold = True

    # ----------------------------------------------------
    # PIE DE PÁGINA Y CONTROL DE VERSIONES
    # ----------------------------------------------------
    doc.add_paragraph().paragraph_format.space_after = Pt(12)
    p_concl = doc.add_paragraph()
    p_concl.paragraph_format.line_spacing = 1.15
    p_concl.paragraph_format.space_after = Pt(8)
    r_c = p_concl.add_run(
        "Conclusión y Recomendación Final: La base de datos nunca debe ser un obstáculo para la continuidad del cultivo en campo. "
        "El procedimiento inmediato ante cualquier flor cortada antes de tiempo es registrar formalmente el cierre de ciclo en la app móvil. "
        "Si la empresa desea que el software permita la nueva siembra automáticamente en el momento en que se ingrese la fecha de corte sin bloquear por días teóricos, "
        "dicha regla ya se encuentra identificada en el código fuente para su activación inmediata."
    )
    r_c.font.name = "Calibri"
    r_c.font.size = Pt(10)
    r_c.italic = True
    r_c.font.color.rgb = RGBColor(0x37, 0x47, 0x4F)
    
    # Guardar documento
    output_path = r"d:\PROYECTO SIEMBRAS\SOLUCION_ADELANTO_CICLO_DESBLOQUEO_CAMAS.docx"
    doc.save(output_path)
    print(f"Documento Word guardado exitosamente en: {output_path}")

if __name__ == "__main__":
    generar_documento()
