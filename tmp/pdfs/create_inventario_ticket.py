from pathlib import Path
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm


OUT = Path(__file__).resolve().parents[2] / "output" / "pdf" / "inventario_conduce_legalidad_ejemplo.pdf"
PAGE_W = 80 * mm
PAGE_H = 215 * mm
MARGIN = 4 * mm
CONTENT_W = PAGE_W - 2 * MARGIN


def register_fonts():
    regular = Path(r"C:\Windows\Fonts\consola.ttf")
    bold = Path(r"C:\Windows\Fonts\consolab.ttf")
    if regular.exists() and bold.exists():
        pdfmetrics.registerFont(TTFont("Ticket", str(regular)))
        pdfmetrics.registerFont(TTFont("TicketBold", str(bold)))
        return "Ticket", "TicketBold"
    return "Courier", "Courier-Bold"


FONT, FONT_BOLD = register_fonts()
c = canvas.Canvas(str(OUT), pagesize=(PAGE_W, PAGE_H))
c.setTitle("Inventario de vehículo remitido - Conduce con Legalidad")
y = PAGE_H - 6 * mm


def wrap(text, font=FONT, size=7.4, max_width=CONTENT_W):
    words = text.split()
    lines, current = [], ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if pdfmetrics.stringWidth(candidate, font, size) <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines or [""]


def centered(text, size=8.0, bold=False, gap=9.6):
    global y
    font = FONT_BOLD if bold else FONT
    c.setFont(font, size)
    c.drawCentredString(PAGE_W / 2, y, text)
    y -= gap


def rule(gap_before=2.5, gap_after=7.0):
    global y
    y -= gap_before
    c.setLineWidth(0.55)
    c.setDash(2.2, 1.4)
    c.line(MARGIN, y, PAGE_W - MARGIN, y)
    c.setDash()
    y -= gap_after


def section(text):
    global y
    c.setFont(FONT_BOLD, 7.8)
    c.drawCentredString(PAGE_W / 2, y, text)
    y -= 10.5


def block(label, value, size=7.3):
    global y
    c.setFont(FONT_BOLD, size)
    c.drawString(MARGIN, y, f"{label}:")
    y -= 8.8
    c.setFont(FONT, size)
    for line in wrap(value, size=size):
        c.drawString(MARGIN, y, line)
        y -= 8.8
    y -= 1.5


def pair(left_label, left_value, right_label, right_value):
    global y
    right_x = PAGE_W / 2 + 2 * mm
    c.setFont(FONT_BOLD, 7.0)
    c.drawString(MARGIN, y, f"{left_label}:")
    c.drawString(right_x, y, f"{right_label}:")
    y -= 8.5
    c.setFont(FONT, 7.0)
    c.drawString(MARGIN, y, left_value)
    c.drawString(right_x, y, right_value)
    y -= 10.5


def write_lines(count, height=12):
    global y
    c.setLineWidth(0.45)
    for _ in range(count):
        y -= height
        c.line(MARGIN, y, PAGE_W - MARGIN, y)
    y -= 4


def paragraph(text, size=6.5):
    global y
    c.setFont(FONT, size)
    for line in wrap(text, size=size):
        c.drawString(MARGIN, y, line)
        y -= 8.2
    y -= 2


def signature(title, name_lines):
    global y
    c.setFont(FONT_BOLD, 7.3)
    c.drawString(MARGIN, y, title)
    y -= 9
    c.setFont(FONT, 7.1)
    for line in name_lines:
        for wrapped in wrap(line, size=7.1):
            c.drawString(MARGIN, y, wrapped)
            y -= 8.5
    y -= 11
    c.setLineWidth(0.45)
    c.line(MARGIN, y, PAGE_W - MARGIN, y)
    y -= 10


centered("SECRETARÍA DE SEGURIDAD PÚBLICA", 7.5, True, 9.5)
centered("INVENTARIO DE VEHÍCULO REMITIDO", 8.6, True, 10.8)
centered("PREVIO AL ARRASTRE - ARTÍCULO 352", 7.0, True, 9.0)
rule()
pair("Folio", "CL-2026-00125", "Inventario", "00001")
pair("Fecha", "21/10/2026", "Hora", "09:30")
block("Lugar", "Av. Camelinas y Ventura Puente, Morelia")
rule()
section("DATOS DEL VEHÍCULO")
pair("Placas/permiso", "ABC1D", "Estado", "Michoacán")
block("Descripción", "Motocicleta Italika FT150, modelo 2024, color negro")
block("Serie/NIV", "3SCPFTDEMO0000001")
rule()
section("TRASLADO Y CUSTODIA")
block("Grúa", "Grúas Morelia 03")
block("Corralón", "Depósito Vehicular Morelia")
block("Número de sello", "")
write_lines(1, 8)
rule()
section("CONDICIONES Y CONTENIDO")
block("Daños o partes afectadas", "Rayón leve en costado derecho.")
block("Observaciones registradas", "Espejos completos; asiento y faro en buen estado.")
c.setFont(FONT, 7.2)
c.drawString(MARGIN, y, "Objetos y accesorios inventariados:")
y -= 2
write_lines(3, 13)
paragraph(
    "Inventario elaborado antes de iniciar el arrastre y sellado del vehículo, "
    "conforme al artículo 352. Las condiciones, daños y objetos asentados se "
    "reciben para su guarda y custodia."
)
rule()
section("NOMBRES Y FIRMAS DE ENTREGA")
signature("PROPIETARIO / CONDUCTOR", ["Juan Perez Lopez"])
signature("AGENTE QUE ELABORA", ["Agente de Seguridad Vial - Placa 0472"])
signature("OPERADOR DE GRÚA", ["Grúas Morelia 03", "Nombre del operador: ____________________"])
c.setFont(FONT_BOLD, 7.0)
c.drawCentredString(PAGE_W / 2, y, "Captura #125 / Operativo #1")

if y < 5 * mm:
    raise RuntimeError(f"Contenido fuera de página: y={y}")

c.showPage()
c.save()
print(OUT)
