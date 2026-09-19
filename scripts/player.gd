extends CharacterBody2D
class_name Player

## Controlador del Jugador (Auto-Runner) para Idle Slayer V3
## Cinemática articulada de carrera: zancada a 15 FPS, pisadas rítmicas, peso físico y ghost trail.

signal jumped(phase: String)
signal attacked
signal attack_finished
signal landed

# Constantes de Física Calibradas
const GRAVITY: float = 1400.0
const JUMP_MIN_VELOCITY: float = -490.0    # Fase 1: Salto Pequeño instantáneo (h ≈ 100px)
const JUMP_SUSTAIN_FORCE: float = 1850.0   # Fuerza continua para alcanzar la altura de la luna
const MAX_JUMP_HOLD_TIME: float = 0.33     # Límite para alcanzar Salto Alto (Y ≈ 180px, nivel de la luna)
const FAST_FALL_MULTIPLIER: float = 1.8
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.15
const ATTACK_COOLDOWN: float = 0.32
const SPRITE_BASE_OFFSET_X: float = 25.0    # Alineación anatómica en lienzo de 340px
const ATTACK_LUNGE_OFFSET_X: float = 31.0   # Estocada marcial hacia adelante (+6px)

# Cinemática de Volteretas Aéreas (Somersault)
const SPIN_SPEED: float = 1080.0          # Grados por segundo de giro dinámico

# Cinemática y Efectos de Carrera (Articulación)
const RUN_LEAN_ANGLE: float = 2.5          # Inclinación atlética hacia adelante (grados)
const SCROLL_SPEED: float = 260.0          # Velocidad de arrastre de estelas
const GHOST_COUNT: int = 5                # Tamaño del pool de estelas (Object Pooling)
const GHOST_INTERVAL: float = 0.07        # Intervalo de emisión de estela fantasma (segundos)
const GHOST_LIFETIME: float = 0.22        # Duración de desvanecimiento de cada estela

# Nodos
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var sword_collision: CollisionShape2D = $SwordHitbox/CollisionShape2D
@onready var dust_particles: CPUParticles2D = $DustParticles

# Variables de Estado de Salto
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var was_on_floor: bool = true
var is_attacking: bool = false

# Salto en 3 Fases y Giros Aéreos
var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var current_jump_phase: String = "PEQUEÑO"
var jump_input_held: bool = false
var jump_triggered: bool = false

# Control de Voltereta (Somersault)
var is_spinning: bool = false
var spin_degrees: float = 0.0
var spin_target_degrees: float = 360.0

# Pool de Estelas Fantasma (Zero Garbage Collection)
var ghost_pool: Array[Sprite2D] = []
var ghost_timer: float = 0.0
var ghost_index: int = 0

func _ready() -> void:
	sword_collision.disabled = true
	anim_sprite.animation_finished.connect(_on_animation_finished)
	anim_sprite.frame_changed.connect(_on_frame_changed)
	anim_sprite.play("run")
	
	# Configurar partículas para estallidos rítmicos
	dust_particles.one_shot = true
	dust_particles.emitting = false
	dust_particles.amount = 4
	
	_init_ghost_pool()

func _exit_tree() -> void:
	for ghost in ghost_pool:
		if is_instance_valid(ghost) and ghost.get_parent() == null:
			ghost.queue_free()

func _init_ghost_pool() -> void:
	for i in range(GHOST_COUNT):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.visible = false
		ghost.z_index = -1  # Dibujado detrás del jugador
		ghost_pool.append(ghost)

func _input(event: InputEvent) -> void:
	# Captura de eventos directa (Zero-lag)
	if event.is_action_pressed("jump") or _is_key_jump(event, true):
		jump_input_held = true
		jump_triggered = true
	elif event.is_action_released("jump") or _is_key_jump(event, false):
		jump_input_held = false

	if event.is_action_pressed("attack") or _is_key_attack(event):
		attack()

func _is_key_jump(event: InputEvent, pressed_state: bool) -> bool:
	if event is InputEventKey:
		if event.pressed == pressed_state:
			var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
			return code == KEY_SPACE or code == KEY_UP or code == KEY_W
	return false

func _is_key_attack(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
		return code == KEY_Z or code == KEY_X or code == KEY_J
	return false

func _physics_process(delta: float) -> void:
	# 1. Comprobar polling como respaldo de tecla sostenida
	if not jump_input_held:
		jump_input_held = Input.is_action_pressed("jump") or \
			Input.is_key_pressed(KEY_SPACE) or \
			Input.is_key_pressed(KEY_UP) or \
			Input.is_key_pressed(KEY_W)

	# 2. Gestión de Gravedad, Sustentación y Cinemática de Giro
	_apply_physics(delta)
	
	# 3. Disparar Salto si hay solicitud pendiente
	_check_and_execute_jump()
	
	# 4. Mover el cuerpo físico
	move_and_slide()
	
	# 5. Actualizar estado del suelo tras la colisión física
	_update_floor_status(delta)
	
	# 6. Temporizador de ataque
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	
	# 7. Actualización visual de articulación y estela fantasma
	_update_visuals()
	_update_ghost_trail(delta)

func _apply_physics(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		coyote_timer = COYOTE_TIME
		is_jumping = false
		is_spinning = false
		spin_degrees = 0.0
	else:
		if coyote_timer > 0.0:
			coyote_timer -= delta
			
		var current_gravity: float = GRAVITY
		
		# Fase de Ascenso (Subiendo)
		if is_jumping and velocity.y < 0.0:
			if jump_input_held and jump_hold_timer < MAX_JUMP_HOLD_TIME:
				jump_hold_timer += delta
				velocity.y -= JUMP_SUSTAIN_FORCE * delta
				
				# Transición a Salto Medio -> Iniciar voltereta hacia adelante (360°)
				if jump_hold_timer >= 0.10 and not is_spinning and spin_degrees == 0.0:
					is_spinning = true
					spin_target_degrees = 360.0
					if current_jump_phase == "PEQUEÑO":
						current_jump_phase = "MEDIANO"
						emit_signal("jumped", current_jump_phase)
				
				# Transición a Salto Alto (Nivel de la Luna) -> Voltereta doble (720°)
				if jump_hold_timer >= 0.22 and current_jump_phase != "ALTO":
					current_jump_phase = "ALTO"
					spin_target_degrees = 720.0
					emit_signal("jumped", current_jump_phase)
			else:
				# Si suelta antes: corta el impulso hacia arriba
				is_jumping = false
				current_gravity *= FAST_FALL_MULTIPLIER
		else:
			is_jumping = false
			if velocity.y >= 0.0:
				current_gravity *= 1.15
		
		# Cinemática del Giro Aéreo (Somersault) y Estabilización Erguida
		if is_attacking:
			is_spinning = false
			anim_sprite.rotation_degrees = 0.0
		elif is_spinning:
			spin_degrees += SPIN_SPEED * delta
			anim_sprite.rotation_degrees = spin_degrees
			if spin_degrees >= spin_target_degrees or velocity.y >= 0.0:
				is_spinning = false
		else:
			# Descenso: recuperación suave hacia la posición vertical erguida (0°)
			anim_sprite.rotation = lerp_angle(anim_sprite.rotation, 0.0, 16.0 * delta)
			
		velocity.y += current_gravity * delta

func _check_and_execute_jump() -> void:
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= get_physics_process_delta_time()

	if jump_triggered:
		jump_triggered = false
		if is_on_floor() or coyote_timer > 0.0:
			_start_jump()
		else:
			jump_buffer_timer = JUMP_BUFFER_TIME
	elif jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
		jump_buffer_timer = 0.0
		_start_jump()

func _start_jump() -> void:
	velocity.y = JUMP_MIN_VELOCITY
	coyote_timer = 0.0
	is_jumping = true
	jump_hold_timer = 0.0
	current_jump_phase = "PEQUEÑO"
	is_spinning = false
	spin_degrees = 0.0
	dust_particles.position = Vector2(-12, 34)
	dust_particles.restart()
	dust_particles.emitting = true
	emit_signal("jumped", current_jump_phase)

func set_jump_input(is_down: bool) -> void:
	jump_input_held = is_down
	if is_down:
		jump_triggered = true
	else:
		is_jumping = false

func jump() -> void:
	set_jump_input(true)

func attack() -> void:
	if attack_cooldown_timer <= 0.0 and not is_attacking:
		is_attacking = true
		attack_cooldown_timer = ATTACK_COOLDOWN
		anim_sprite.play("slash")
		is_spinning = false
		anim_sprite.rotation_degrees = 0.0
		anim_sprite.position.x = SPRITE_BASE_OFFSET_X
		anim_sprite.position.y = -10.0
		if is_on_floor():
			# Soplido de polvo bajo la bota de apoyo al clavar los pies para el corte
			dust_particles.position = Vector2(8, 34)
			dust_particles.restart()
			dust_particles.emitting = true
		emit_signal("attacked")

func _on_frame_changed() -> void:
	if is_attacking and anim_sprite.animation == "slash":
		sword_collision.disabled = (anim_sprite.frame < 1 or anim_sprite.frame > 2)
		# Articulación marcial: estocada hacia adelante (+6px) en fotogramas de mayor impacto
		if anim_sprite.frame == 1 or anim_sprite.frame == 2:
			anim_sprite.position.x = ATTACK_LUNGE_OFFSET_X
		else:
			anim_sprite.position.x = SPRITE_BASE_OFFSET_X
	elif is_on_floor() and anim_sprite.animation == "run":
		# Articulación de pisada: estallido de polvo en impacto de talón y micro-rebote
		if anim_sprite.frame == 0:
			dust_particles.position = Vector2(-18, 34)
			dust_particles.restart()
			dust_particles.emitting = true
			anim_sprite.position.y = -8.5  # Amortiguación de impacto
		elif anim_sprite.frame == 3:
			dust_particles.position = Vector2(-10, 34)
			dust_particles.restart()
			dust_particles.emitting = true
			anim_sprite.position.y = -8.5  # Amortiguación de impacto
		else:
			anim_sprite.position.y = -10.0 # Elevación en zancada

func _on_animation_finished() -> void:
	if is_attacking and anim_sprite.animation == "slash":
		is_attacking = false
		sword_collision.disabled = true
		anim_sprite.position.x = SPRITE_BASE_OFFSET_X
		emit_signal("attack_finished")
		if is_on_floor():
			anim_sprite.play("run")
		else:
			anim_sprite.play("jump")

func _update_floor_status(_delta: float) -> void:
	if is_on_floor():
		if not was_on_floor:
			emit_signal("landed")
			dust_particles.position = Vector2(-14, 34)
			dust_particles.restart()
			dust_particles.emitting = true
		was_on_floor = true
	else:
		was_on_floor = false

func _update_visuals() -> void:
	if is_attacking:
		anim_sprite.rotation_degrees = 0.0
		anim_sprite.position.y = -10.0
		return
	
	anim_sprite.position.x = SPRITE_BASE_OFFSET_X
	if not is_on_floor():
		if anim_sprite.animation != "jump":
			anim_sprite.play("jump")
		anim_sprite.position.y = -10.0
	else:
		if anim_sprite.animation != "run":
			anim_sprite.play("run")
		# Inclinación aerodinámica de carrera (2.5° hacia adelante)
		anim_sprite.rotation_degrees = RUN_LEAN_ANGLE

func _update_ghost_trail(delta: float) -> void:
	# 1. Desplazar estelas activas hacia atrás a la velocidad del mundo
	for ghost in ghost_pool:
		if ghost.visible:
			ghost.global_position.x -= SCROLL_SPEED * delta
			ghost.modulate.a -= (delta / GHOST_LIFETIME) * 0.45
			if ghost.modulate.a <= 0.0:
				ghost.visible = false
	
	# 2. Emitir nueva estela periódica al correr en el suelo
	if is_on_floor() and anim_sprite.animation == "run" and not is_attacking:
		ghost_timer += delta
		if ghost_timer >= GHOST_INTERVAL:
			ghost_timer = 0.0
			_spawn_ghost()
	else:
		ghost_timer = 0.0

func _spawn_ghost() -> void:
	var ghost: Sprite2D = ghost_pool[ghost_index]
	ghost_index = (ghost_index + 1) % GHOST_COUNT
	
	# Añadir al árbol si aún no tiene padre (como hermano del jugador)
	if ghost.get_parent() == null:
		var parent_node: Node = get_parent()
		if parent_node != null:
			parent_node.add_child.call_deferred(ghost)
	
	var current_tex: Texture2D = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
	if current_tex != null:
		ghost.texture = current_tex
		ghost.scale = anim_sprite.scale
		ghost.global_position = anim_sprite.global_position
		ghost.rotation = anim_sprite.rotation
		ghost.modulate = Color(0.95, 0.22, 0.28, 0.42) # Tinte carmesí translúcido
		ghost.visible = true
