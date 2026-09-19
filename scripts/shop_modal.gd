extends Control
class_name ShopModal

## Modal de Tienda y Mejoras para Idle Slayer V3
## Estructura con 2 franjas inferiores: multiplicadores y 5 pestañas de menú.

signal closed
signal tab_changed(tab_index: int, tab_name: String)
signal multiplier_changed(multiplier: String)

@onready var backdrop: ColorRect = $Backdrop
@onready var panel_window: PanelContainer = $CenterContainer/PanelWindow
@onready var btn_close: Button = $CenterContainer/PanelWindow/VBox/Header/CloseButton
@onready var content_label: Label = $CenterContainer/PanelWindow/VBox/ContentArea/Margin/VBox/TabTitleLabel
@onready var content_desc: Label = $CenterContainer/PanelWindow/VBox/ContentArea/Margin/VBox/TabDescLabel

# Franja 1: Multiplicadores de compra
@onready var mult_buttons: Array[Button] = [
	$CenterContainer/PanelWindow/VBox/MultiplierStrip/HBox/Btn1x,
	$CenterContainer/PanelWindow/VBox/MultiplierStrip/HBox/Btn10x,
	$CenterContainer/PanelWindow/VBox/MultiplierStrip/HBox/Btn50x,
	$CenterContainer/PanelWindow/VBox/MultiplierStrip/HBox/Btn100x,
	$CenterContainer/PanelWindow/VBox/MultiplierStrip/HBox/BtnMax
]

# Franja 2: 5 Pestañas de Menú
@onready var tab_buttons: Array[Button] = [
	$CenterContainer/PanelWindow/VBox/TabsStrip/HBox/TabEquipo,
	$CenterContainer/PanelWindow/VBox/TabsStrip/HBox/TabMejoras,
	$CenterContainer/PanelWindow/VBox/TabsStrip/HBox/TabMisiones,
	$CenterContainer/PanelWindow/VBox/TabsStrip/HBox/TabAscension,
	$CenterContainer/PanelWindow/VBox/TabsStrip/HBox/TabAjustes
]

const TAB_INFO: Array[Dictionary] = [
	{"name": "EQUIPO", "title": "⚔️ EQUIPO Y ARMAS", "desc": "Desbloquea y forja espadas, dagas y armaduras para potenciar tu daño."},
	{"name": "MEJORAS", "title": "⚡ MEJORAS PASIVAS", "desc": "Aumenta el valor de las monedas, velocidad y magnetismo."},
	{"name": "MISIONES", "title": "📜 MISIONES Y LOGROS", "desc": "Cumple objetivos para ganar gemas, almas y recompensas únicas."},
	{"name": "ASCENSIÓN", "title": "🔮 ÁRBOL DE ASCENSIÓN", "desc": "Reinicia tu progreso terrenal a cambio de Almas y Sabiduría Ancestral."},
	{"name": "AJUSTES", "title": "⚙️ AJUSTES Y ESTADÍSTICAS", "desc": "Configuración de audio, guardado y métricas de tu carrera."}
]

var active_tab_index: int = 0
var active_multiplier: String = "1x"
var is_open: bool = false

func _ready() -> void:
	visible = false
	btn_close.pressed.connect(close)
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	
	# Conectar botones de multiplicadores
	for i in range(mult_buttons.size()):
		var btn: Button = mult_buttons[i]
		var mult_text: String = btn.text.strip_edges()
		btn.pressed.connect(_on_multiplier_pressed.bind(mult_text, i))
	
	# Conectar botones de las 5 pestañas
	for i in range(tab_buttons.size()):
		var btn: Button = tab_buttons[i]
		btn.pressed.connect(_on_tab_pressed.bind(i))
	
	_select_tab(0)
	_select_multiplier(0)

func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	modulate.a = 0.0
	panel_window.scale = Vector2(0.92, 0.92)
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel_window, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not is_open:
		return
	is_open = false
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_property(panel_window, "scale", Vector2(0.94, 0.94), 0.12)
	await tween.finished
	visible = false
	emit_signal("closed")

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	# Clic fuera del panel principal cierra el modal
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _on_tab_pressed(index: int) -> void:
	_select_tab(index)

func _select_tab(index: int) -> void:
	active_tab_index = index
	for i in range(tab_buttons.size()):
		var btn: Button = tab_buttons[i]
		if i == index:
			btn.modulate = Color(1.0, 0.9, 0.5) # Destacado dorado/activo
		else:
			btn.modulate = Color(0.75, 0.75, 0.8) # Atenuado inactivo
	
	var info: Dictionary = TAB_INFO[index]
	content_label.text = info["title"]
	content_desc.text = info["desc"]
	emit_signal("tab_changed", index, info["name"])

func _on_multiplier_pressed(mult_str: String, index: int) -> void:
	_select_multiplier(index)

func _select_multiplier(index: int) -> void:
	for i in range(mult_buttons.size()):
		var btn: Button = mult_buttons[i]
		if i == index:
			active_multiplier = btn.text.strip_edges()
			btn.modulate = Color(0.4, 1.0, 0.5) # Verde activo
		else:
			btn.modulate = Color(0.8, 0.8, 0.85) # Normal
	emit_signal("multiplier_changed", active_multiplier)
