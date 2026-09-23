extends Node2D

## Controlador del Mundo y Escenario Infinito para Idle Slayer V3

const GAME_SPEED: float = 260.0

@onready var player: Player = $Player
@onready var sky: Sprite2D = $Sky
@onready var ground1: Sprite2D = $GroundLayers/Ground1
@onready var ground2: Sprite2D = $GroundLayers/Ground2
@onready var ground3: Sprite2D = $GroundLayers/Ground3

@onready var bg_mountains1: Sprite2D = $ParallaxLayers/Mountains1
@onready var bg_mountains2: Sprite2D = $ParallaxLayers/Mountains2
@onready var bg_mountains3: Sprite2D = $ParallaxLayers/Mountains3

@onready var bg_trees1: Sprite2D = $ParallaxLayers/Trees1
@onready var bg_trees2: Sprite2D = $ParallaxLayers/Trees2
@onready var bg_trees3: Sprite2D = $ParallaxLayers/Trees3

# Referencias de HUD
@onready var label_state: Label = $HUD/TopBar/Margin/HBox/StateBadge/StateLabel
@onready var label_coins: Label = $HUD/TopBar/Margin/HBox/CenterCoinContainer/CoinBadge/Margin/HBox/CoinsLabel
@onready var coin_badge: PanelContainer = $HUD/TopBar/Margin/HBox/CenterCoinContainer/CoinBadge
@onready var coin_container: Node2D = $CoinContainer
@onready var enemy_container: Node2D = $EnemyContainer
@onready var btn_jump: Button = $HUD/Controls/JumpButton
@onready var btn_attack: Button = $HUD/Controls/AttackButton
@onready var btn_shop: Button = $HUD/TopBar/Margin/HBox/ShopButton
@onready var shop_modal: ShopModal = $HUD/ShopModal

# Listas de sprites para desplazamiento infinito ultra-ancho
var _ground_sprites: Array[Sprite2D] = []
var _tree_sprites: Array[Sprite2D] = []
var _mountain_sprites: Array[Sprite2D] = []

# Sistema de Monedas (Object Pooling - Zero GC)
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const COIN_POOL_SIZE: int = 20
const COIN_SPAWN_INTERVAL: float = 5.0

var coin_pool: Array[Coin] = []
var coin_spawn_timer: float = 2.0   # Aparece el primer patrón a los 3s de inicio
var coins_collected: int = 0
var distance_run: float = 0.0

# Sistema de Slimes de Tierra (Object Pooling - Zero GC)
const SLIME_SCENE: PackedScene = preload("res://scenes/slime.tscn")
const SLIME_POOL_SIZE: int = 6
const SLIME_SPAWN_INTERVAL_MIN: float = 4.0
const SLIME_SPAWN_INTERVAL_MAX: float = 7.0

var slime_pool: Array[Slime] = []
var slime_spawn_timer: float = 0.0
var slime_next_spawn_time: float = 2.5

func _ready() -> void:
	# Asegurar que ningún botón tome el foco del teclado
	btn_jump.focus_mode = Control.FOCUS_NONE
	btn_attack.focus_mode = Control.FOCUS_NONE
	
	# Conectar señales del jugador
	player.jumped.connect(_on_player_jumped)
	player.attacked.connect(_on_player_attacked)
	player.attack_finished.connect(_on_player_attack_finished)
	player.landed.connect(_on_player_landed)
	
	# Botón de Salto táctil: button_down y button_up
	btn_jump.button_down.connect(_on_jump_down)
	btn_jump.button_up.connect(_on_jump_up)
	
	# Botón de Ataque
	btn_attack.pressed.connect(_on_attack_pressed)
	
	# Botón de Tienda
	btn_shop.focus_mode = Control.FOCUS_NONE
	btn_shop.pressed.connect(_on_shop_pressed)
	
	_ground_sprites = [ground1, ground2, ground3]
	_tree_sprites = [bg_trees1, bg_trees2, bg_trees3]
	_mountain_sprites = [bg_mountains1, bg_mountains2, bg_mountains3]
	
	# Adaptación responsive a cambios de tamaño de ventana/pantalla
	get_viewport().size_changed.connect(_update_viewport_layout)
	_update_viewport_layout()
	
	_update_state_label("CORRIENDO", Color(0.3, 0.9, 0.4))
	_init_coin_pool()
	_init_slime_pool()
	_update_coin_display()

func _update_viewport_layout() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if is_instance_valid(sky):
		sky.position = Vector2(vp_size.x * 0.5, vp_size.y * 0.5)
		var scale_x: float = max(1.0, vp_size.x / 1280.0)
		var scale_y: float = max(1.0, vp_size.y / 720.0)
		var s: float = max(scale_x, scale_y)
		sky.scale = Vector2(s, s)

func _init_coin_pool() -> void:
	for i in range(COIN_POOL_SIZE):
		var coin: Coin = COIN_SCENE.instantiate() as Coin
		coin_container.add_child(coin)
		coin.collected.connect(_on_coin_collected)
		coin_pool.append(coin)

func _init_slime_pool() -> void:
	for i in range(SLIME_POOL_SIZE):
		var slime: Slime = SLIME_SCENE.instantiate() as Slime
		enemy_container.add_child(slime)
		slime.killed.connect(_on_slime_killed)
		slime_pool.append(slime)

func _process(delta: float) -> void:
	# 1. Desplazamiento del Suelo Continuo (3 sprites en bucle infinito)
	_scroll_sprites(_ground_sprites, 1280.0, GAME_SPEED * delta)
	
	# 2. Desplazamiento Parallax de Capas
	_scroll_sprites(_tree_sprites, 1280.0, GAME_SPEED * 0.4 * delta)
	_scroll_sprites(_mountain_sprites, 1280.0, GAME_SPEED * 0.15 * delta)
	
	# 3. Métricas de distancia
	distance_run += (GAME_SPEED * delta) / 100.0
	
	# 4. Spawner de Patrones de Monedas cada 5 segundos
	coin_spawn_timer += delta
	if coin_spawn_timer >= COIN_SPAWN_INTERVAL:
		coin_spawn_timer = 0.0
		_spawn_coin_pattern()

	# 5. Spawner de Slimes de Tierra
	slime_spawn_timer += delta
	if slime_spawn_timer >= slime_next_spawn_time:
		slime_spawn_timer = 0.0
		slime_next_spawn_time = randf_range(SLIME_SPAWN_INTERVAL_MIN, SLIME_SPAWN_INTERVAL_MAX)
		_spawn_slime()

func _spawn_coin_pattern() -> void:
	var count: int = randi_range(1, 3)
	var vp_width: float = get_viewport_rect().size.x
	var spawn_x: float = max(1330.0, vp_width + 80.0)
	var pattern_type: int = randi() % 3
	
	match pattern_type:
		0:
			# Patrón A: Línea terrestre a nivel de carrera (Y=525)
			for i in range(count):
				_spawn_single_coin(Vector2(spawn_x + i * 55.0, 525.0))
		1:
			# Patrón B: Arco de salto mediano
			if count == 1:
				_spawn_single_coin(Vector2(spawn_x, 440.0))
			elif count == 2:
				_spawn_single_coin(Vector2(spawn_x, 470.0))
				_spawn_single_coin(Vector2(spawn_x + 60.0, 430.0))
			else:
				_spawn_single_coin(Vector2(spawn_x, 475.0))
				_spawn_single_coin(Vector2(spawn_x + 65.0, 415.0))
				_spawn_single_coin(Vector2(spawn_x + 130.0, 475.0))
		2:
			# Patrón C: Ascendente hacia la luna (requiere salto alto)
			if count == 1:
				_spawn_single_coin(Vector2(spawn_x, 380.0))
			elif count == 2:
				_spawn_single_coin(Vector2(spawn_x, 430.0))
				_spawn_single_coin(Vector2(spawn_x + 70.0, 310.0))
			else:
				_spawn_single_coin(Vector2(spawn_x, 440.0))
				_spawn_single_coin(Vector2(spawn_x + 75.0, 320.0))
				_spawn_single_coin(Vector2(spawn_x + 150.0, 210.0))

func _spawn_single_coin(pos: Vector2) -> void:
	for coin in coin_pool:
		if not coin.is_active:
			coin.activate(pos, GAME_SPEED, 1)
			return

func _spawn_slime() -> void:
	var vp_width: float = get_viewport_rect().size.x
	var spawn_x: float = max(1360.0, vp_width + 120.0)
	var spawn_y: float = 540.0
	for slime in slime_pool:
		if slime.current_state == Slime.State.INACTIVE:
			slime.activate(Vector2(spawn_x, spawn_y), GAME_SPEED, randi_range(1, 2))
			return

func _on_coin_collected(_coin: Coin, val: int) -> void:
	coins_collected += val
	_update_coin_display()

func _on_slime_killed(reward: int, _pos: Vector2) -> void:
	coins_collected += reward
	_update_coin_display()
	_update_state_label("¡SLIME DERROTADO! +" + str(reward), Color(0.4, 1.0, 0.5))

func _update_coin_display() -> void:
	label_coins.text = str(coins_collected)
	# Destello / micro-pulso visual en el contador central
	if is_instance_valid(label_coins):
		label_coins.modulate = Color(1.6, 1.4, 0.7)
		var tween: Tween = create_tween()
		tween.tween_property(label_coins, "modulate", Color(1.0, 0.9, 0.55), 0.18)

func _scroll_sprites(sprites: Array[Sprite2D], width: float, move_amount: float) -> void:
	for s in sprites:
		s.position.x -= move_amount
	for s in sprites:
		if s.position.x <= -width:
			var max_x: float = s.position.x
			for other in sprites:
				if other != s and other.position.x > max_x:
					max_x = other.position.x
			s.position.x = max_x + width

func _unhandled_input(event: InputEvent) -> void:
	# Atajo de teclado para abrir/cerrar tienda: B o E
	if event is InputEventKey and event.pressed:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if code == KEY_B or code == KEY_E:
			shop_modal.toggle()
			return

	# Si la tienda está abierta, no procesar saltos ni ataques en el fondo
	if shop_modal.is_open:
		return

	# Soporte táctil / clic en pantalla para navegadores
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var screen_w: float = get_viewport_rect().size.x
			if event.position.x > screen_w * 0.6:
				if event.pressed:
					player.attack()
			else:
				player.set_jump_input(event.pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			player.attack()

func _on_player_jumped(phase: String) -> void:
	match phase:
		"PEQUEÑO":
			_update_state_label("🟢 SALTO CORTO", Color(0.4, 0.95, 0.4))
		"MEDIANO":
			_update_state_label("🟡 SALTO MEDIO", Color(1.0, 0.88, 0.2))
		"ALTO":
			_update_state_label("🟣 SALTO ALTO", Color(0.85, 0.45, 1.0))
		_:
			_update_state_label("SALTANDO", Color(0.4, 0.7, 1.0))

func _on_player_attacked() -> void:
	_update_state_label("¡ATAQUE!", Color(1.0, 0.3, 0.3))

func _on_player_attack_finished() -> void:
	if player.is_on_floor():
		_update_state_label("CORRIENDO", Color(0.3, 0.9, 0.4))

func _on_player_landed() -> void:
	_update_state_label("CORRIENDO", Color(0.3, 0.9, 0.4))

func _on_jump_down() -> void:
	player.set_jump_input(true)

func _on_jump_up() -> void:
	player.set_jump_input(false)

func _on_attack_pressed() -> void:
	player.attack()

func _on_shop_pressed() -> void:
	shop_modal.toggle()

func _update_state_label(text_val: String, color_val: Color) -> void:
	label_state.text = text_val
	label_state.modulate = color_val
