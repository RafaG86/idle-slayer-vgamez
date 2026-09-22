extends CharacterBody2D
class_name Player

## Controlador del Jugador (Auto-Runner) para Idle Slayer V3
## Sistema de impulso: trote → carrera → sprint | Squash & Stretch | Espada oculta al correr

signal jumped(phase: String)
signal attacked
signal attack_finished
signal landed

# ─── Física ───────────────────────────────────────────────────────────────────
const GRAVITY: float = 1400.0
const JUMP_MIN_VELOCITY: float = -490.0
const JUMP_SUSTAIN_FORCE: float = 1850.0
const MAX_JUMP_HOLD_TIME: float = 0.33
const FAST_FALL_MULTIPLIER: float = 1.8
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.15
const ATTACK_COOLDOWN: float = 0.32

# ─── Sprite Base ──────────────────────────────────────────────────────────────
const BASE_SCALE: Vector2 = Vector2(0.6, 0.6)
const SPRITE_BASE_OFFSET_X: float = 25.0

# ─── Sistema de Impulso (Trote → Carrera → Sprint) ────────────────────────────
enum RunPhase { TROT, RUN, SPRINT }
const TROT_DURATION: float = 1.2          # segundos en tierra hasta RUN
const SPRINT_DURATION: float = 3.2        # segundos en tierra hasta SPRINT
const TROT_ANIM_SPEED: float = 7.0        # FPS animación en trote
const RUN_ANIM_SPEED: float = 13.0        # FPS animación en carrera normal
const SPRINT_ANIM_SPEED: float = 19.0     # FPS animación en sprint máximo
const TROT_LEAN: float = 1.0              # inclinación en trote (grados)
const RUN_LEAN: float = 2.5               # inclinación en carrera normal
const SPRINT_LEAN: float = 5.5            # inclinación en sprint (inclinado al frente)
const TROT_GHOST_INTERVAL: float = 0.22   # estela fantasma cada N seg en trote
const RUN_GHOST_INTERVAL: float = 0.09    # estela en carrera
const SPRINT_GHOST_INTERVAL: float = 0.04 # estela intensa en sprint

# ─── Squash & Stretch ─────────────────────────────────────────────────────────
const SQUASH_LAUNCH: Vector2 = Vector2(0.672, 0.492)  # aplastamiento al saltar
const STRETCH_ASCEND: Vector2 = Vector2(0.540, 0.660) # estiramiento en ascenso
const STRETCH_FALL: Vector2 = Vector2(0.516, 0.684)   # estiramiento en caída
const SQUASH_LAND: Vector2 = Vector2(0.720, 0.456)    # aplastamiento al aterrizar
const SQUASH_RECOVER_SPEED: float = 16.0              # vel. de recuperación a escala base

# ─── Voltereta Aérea ──────────────────────────────────────────────────────────
const SPIN_SPEED: float = 1080.0

# ─── Estela Fantasma (Ghost Trail - Object Pooling) ───────────────────────────
const SCROLL_SPEED: float = 260.0
const GHOST_COUNT: int = 10
const GHOST_LIFETIME: float = 0.22

# ─── Nodos ────────────────────────────────────────────────────────────────────
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var sword_collision: CollisionShape2D = $SwordHitbox/CollisionShape2D
@onready var dust_particles: CPUParticles2D = $DustParticles

# ─── Estado de Salto ──────────────────────────────────────────────────────────
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var was_on_floor: bool = true
var is_attacking: bool = false

var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var current_jump_phase: String = "PEQUEÑO"
var jump_input_held: bool = false
var jump_triggered: bool = false

# ─── Voltereta ────────────────────────────────────────────────────────────────
var is_spinning: bool = false
var spin_degrees: float = 0.0
var spin_target_degrees: float = 360.0

# ─── Estado de Impulso ────────────────────────────────────────────────────────
var run_phase: RunPhase = RunPhase.TROT
var run_timer: float = 0.0            # tiempo acumulado en tierra (se congela en el aire)
var current_anim_speed: float = TROT_ANIM_SPEED
var current_lean: float = TROT_LEAN
var current_ghost_interval: float = TROT_GHOST_INTERVAL

# ─── Squash & Stretch ─────────────────────────────────────────────────────────
var sprite_scale_target: Vector2 = BASE_SCALE
var was_falling: bool = false

# ─── Estela Fantasma ──────────────────────────────────────────────────────────
var ghost_pool: Array[Sprite2D] = []
var ghost_timer: float = 0.0
var ghost_index: int = 0

# ─── Shader de Espada ─────────────────────────────────────────────────────────
var sword_mask_material: ShaderMaterial = null


func _ready() -> void:
	sword_collision.disabled = true
	anim_sprite.animation_finished.connect(_on_animation_finished)
	anim_sprite.frame_changed.connect(_on_frame_changed)
	anim_sprite.scale = BASE_SCALE
	anim_sprite.play("run")

	dust_particles.one_shot = true
	dust_particles.emitting = false
	dust_particles.amount = 4

	_setup_sword_shader()
	_set_sword_visible(false)   # Espada oculta al comenzar
	_init_ghost_pool()


# ─── Shader HSV: enmascara los píxeles cian de la espada por rango de matiz ───
func _setup_sword_shader() -> void:
	var shd: Shader = Shader.new()
	# La espada tiene hue ~185-215° (azul-cian). La armadura/piel tienen hues
	# completamente distintos, así que el filtro por rango HSV es muy selectivo.
	shd.code = """
shader_type canvas_item;

uniform bool mask_active = true;
uniform float hue_min : hint_range(0.0, 1.0) = 0.500;
uniform float hue_max : hint_range(0.0, 1.0) = 0.600;
uniform float sat_min : hint_range(0.0, 1.0) = 0.40;
uniform float val_min : hint_range(0.0, 1.0) = 0.28;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    if (!mask_active || col.a < 0.05) {
        COLOR = col;
        return;
    }
    vec3 hsv = rgb2hsv(col.rgb);
    bool in_hue = (hsv.x >= hue_min && hsv.x <= hue_max);
    bool in_sat = (hsv.y >= sat_min);
    bool in_val = (hsv.z >= val_min);
    if (in_hue && in_sat && in_val) {
        float hue_mid = (hue_min + hue_max) * 0.5;
        float hue_half = (hue_max - hue_min) * 0.5;
        float edge = abs(hsv.x - hue_mid) / hue_half;
        float alpha_factor = smoothstep(0.55, 1.0, edge);
        COLOR = vec4(col.rgb, col.a * alpha_factor);
    } else {
        COLOR = col;
    }
}
"""
	sword_mask_material = ShaderMaterial.new()
	sword_mask_material.shader = shd
	sword_mask_material.set_shader_parameter("mask_active", true)
	sword_mask_material.set_shader_parameter("hue_min", 0.500)
	sword_mask_material.set_shader_parameter("hue_max", 0.597)
	sword_mask_material.set_shader_parameter("sat_min", 0.38)
	sword_mask_material.set_shader_parameter("val_min", 0.28)
	anim_sprite.material = sword_mask_material


func _set_sword_visible(vis: bool) -> void:
	if sword_mask_material != null:
		# mask_active=true → máscara ON (espada invisible al correr)
		# mask_active=false → máscara OFF (espada visible al atacar)
		sword_mask_material.set_shader_parameter("mask_active", not vis)


func _exit_tree() -> void:
	for ghost in ghost_pool:
		if is_instance_valid(ghost) and ghost.get_parent() == null:
			ghost.queue_free()


func _init_ghost_pool() -> void:
	for i in range(GHOST_COUNT):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.visible = false
		ghost.z_index = -1
		ghost_pool.append(ghost)


# ─── Entrada ──────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
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


# ─── Bucle de Física ──────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Polling de tecla sostenida (respaldo para web)
	if not jump_input_held:
		jump_input_held = Input.is_action_pressed("jump") or \
			Input.is_key_pressed(KEY_SPACE) or \
			Input.is_key_pressed(KEY_UP) or \
			Input.is_key_pressed(KEY_W)

	_apply_physics(delta)
	_check_and_execute_jump()
	move_and_slide()
	_update_floor_status(delta)
	_update_run_impulse(delta)

	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	_update_visuals(delta)
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

		if is_jumping and velocity.y < 0.0:
			if jump_input_held and jump_hold_timer < MAX_JUMP_HOLD_TIME:
				jump_hold_timer += delta
				velocity.y -= JUMP_SUSTAIN_FORCE * delta

				# Fase MEDIANO → voltereta simple (360°)
				if jump_hold_timer >= 0.10 and not is_spinning and spin_degrees == 0.0:
					is_spinning = true
					spin_target_degrees = 360.0
					if current_jump_phase == "PEQUEÑO":
						current_jump_phase = "MEDIANO"
						emit_signal("jumped", current_jump_phase)

				# Fase ALTO → voltereta doble (720°)
				if jump_hold_timer >= 0.22 and current_jump_phase != "ALTO":
					current_jump_phase = "ALTO"
					spin_target_degrees = 720.0
					emit_signal("jumped", current_jump_phase)
			else:
				is_jumping = false
				current_gravity *= FAST_FALL_MULTIPLIER
		else:
			is_jumping = false
			if velocity.y >= 0.0:
				current_gravity *= 1.15

		# Squash & Stretch en el aire
		if not is_attacking:
			if velocity.y < -60.0:
				# Ascenso: leve stretch vertical
				sprite_scale_target = STRETCH_ASCEND
				was_falling = false
			elif velocity.y > 80.0 and not was_falling:
				# Inicio de caída: stretch de caída
				sprite_scale_target = STRETCH_FALL
				was_falling = true

		# Cinemática del giro aéreo
		if is_attacking:
			is_spinning = false
			anim_sprite.rotation_degrees = 0.0
		elif is_spinning:
			spin_degrees += SPIN_SPEED * delta
			anim_sprite.rotation_degrees = spin_degrees
			if spin_degrees >= spin_target_degrees or velocity.y >= 0.0:
				is_spinning = false
		else:
			anim_sprite.rotation = lerp_angle(anim_sprite.rotation, 0.0, 16.0 * delta)

		velocity.y += current_gravity * delta


# ─── Sistema de Impulso de Carrera ────────────────────────────────────────────
func _update_run_impulse(delta: float) -> void:
	# El timer avanza solo cuando está en tierra y no ataca
	if is_on_floor() and not is_attacking:
		run_timer += delta
	# Al saltar NO se resetea — el impulso se mantiene (feeling de "momentum")

	# Determinar fase según el tiempo acumulado
	var new_phase: RunPhase
	if run_timer < TROT_DURATION:
		new_phase = RunPhase.TROT
	elif run_timer < SPRINT_DURATION:
		new_phase = RunPhase.RUN
	else:
		new_phase = RunPhase.SPRINT

	run_phase = new_phase

	# Interpolar suavemente velocidad, inclinación e intervalo de estela
	match run_phase:
		RunPhase.TROT:
			current_anim_speed = lerpf(current_anim_speed, TROT_ANIM_SPEED, delta * 5.0)
			current_lean = lerpf(current_lean, TROT_LEAN, delta * 5.0)
			current_ghost_interval = TROT_GHOST_INTERVAL
		RunPhase.RUN:
			current_anim_speed = lerpf(current_anim_speed, RUN_ANIM_SPEED, delta * 3.5)
			current_lean = lerpf(current_lean, RUN_LEAN, delta * 3.5)
			current_ghost_interval = RUN_GHOST_INTERVAL
		RunPhase.SPRINT:
			current_anim_speed = lerpf(current_anim_speed, SPRINT_ANIM_SPEED, delta * 2.0)
			current_lean = lerpf(current_lean, SPRINT_LEAN, delta * 2.0)
			current_ghost_interval = SPRINT_GHOST_INTERVAL


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
	was_falling = false
	# Squash de lanzamiento (aplastamiento horizontal al despegar)
	anim_sprite.scale = SQUASH_LAUNCH
	sprite_scale_target = STRETCH_ASCEND
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
		anim_sprite.speed_scale = 1.0   # velocidad normal para el slash
		is_spinning = false
		anim_sprite.rotation_degrees = 0.0
		anim_sprite.position.x = SPRITE_BASE_OFFSET_X
		anim_sprite.position.y = -10.0
		_set_sword_visible(true)   # ← La espada aparece al atacar
		if is_on_floor():
			dust_particles.position = Vector2(8, 34)
			dust_particles.restart()
			dust_particles.emitting = true
		emit_signal("attacked")


# ─── Callbacks de AnimatedSprite2D ────────────────────────────────────────────
func _on_frame_changed() -> void:
	if is_attacking and anim_sprite.animation == "slash":
		# Hitbox activa solo en frames de impacto (1 y 2)
		sword_collision.disabled = (anim_sprite.frame < 1 or anim_sprite.frame > 2)

		# Offsets dinámicos por frame para mantener el arco de luz visible en pantalla
		match anim_sprite.frame:
			0:  # Preparación: agachado, espada al frente bajo
				anim_sprite.position.x = SPRITE_BASE_OFFSET_X - 4.0
				anim_sprite.position.y = -6.0
			1:  # Golpe principal: arco horizontal máximo hacia adelante
				anim_sprite.position.x = SPRITE_BASE_OFFSET_X + 26.0
				anim_sprite.position.y = -10.0
			2:  # Arco descendente: el arco baja y se extiende hacia abajo-adelante
				anim_sprite.position.x = SPRITE_BASE_OFFSET_X + 18.0
				anim_sprite.position.y = -14.0
			3:  # Follow-through: chispa final, volver a posición neutra
				anim_sprite.position.x = SPRITE_BASE_OFFSET_X + 8.0
				anim_sprite.position.y = -10.0

	elif is_on_floor() and anim_sprite.animation == "run":
		# Pisadas rítmicas: destello de polvo en contacto de talón
		if anim_sprite.frame == 0:
			dust_particles.position = Vector2(-18, 34)
			dust_particles.restart()
			dust_particles.emitting = true
			anim_sprite.position.y = -8.5   # Amortiguación de impacto
		elif anim_sprite.frame == 3:
			dust_particles.position = Vector2(-10, 34)
			dust_particles.restart()
			dust_particles.emitting = true
			anim_sprite.position.y = -8.5
		else:
			anim_sprite.position.y = -10.0  # Elevación en zancada


func _on_animation_finished() -> void:
	if is_attacking and anim_sprite.animation == "slash":
		is_attacking = false
		sword_collision.disabled = true
		anim_sprite.position.x = SPRITE_BASE_OFFSET_X
		_set_sword_visible(false)   # ← La espada desaparece al terminar el ataque
		emit_signal("attack_finished")
		if is_on_floor():
			anim_sprite.play("run")
		else:
			anim_sprite.play("jump")


# ─── Estado del Suelo ─────────────────────────────────────────────────────────
func _update_floor_status(_delta: float) -> void:
	if is_on_floor():
		if not was_on_floor:
			emit_signal("landed")
			# Squash de aterrizaje
			anim_sprite.scale = SQUASH_LAND
			sprite_scale_target = BASE_SCALE
			was_falling = false
			dust_particles.position = Vector2(-14, 34)
			dust_particles.restart()
			dust_particles.emitting = true
		was_on_floor = true
	else:
		was_on_floor = false


# ─── Actualización Visual ─────────────────────────────────────────────────────
func _update_visuals(delta: float) -> void:
	# Recuperar escala suavemente hacia el objetivo (squash & stretch)
	anim_sprite.scale = anim_sprite.scale.lerp(sprite_scale_target, SQUASH_RECOVER_SPEED * delta)

	if is_attacking:
		anim_sprite.rotation_degrees = 0.0
		return

	anim_sprite.position.x = SPRITE_BASE_OFFSET_X

	if not is_on_floor():
		if anim_sprite.animation != "jump":
			anim_sprite.play("jump")
			anim_sprite.speed_scale = 1.0
		anim_sprite.position.y = -10.0
	else:
		if anim_sprite.animation != "run":
			anim_sprite.play("run")
			_set_sword_visible(false)   # Asegurar espada oculta al volver a correr
		# Aplicar velocidad de animación dinámica según fase de impulso
		anim_sprite.speed_scale = current_anim_speed / 15.0
		# Inclinación aerodinámica dinámica (trote=suave, sprint=atlético)
		anim_sprite.rotation_degrees = current_lean
		# Mantener objetivo de escala base en tierra
		if not (was_on_floor == false):
			sprite_scale_target = BASE_SCALE


# ─── Estela Fantasma (Ghost Trail) ───────────────────────────────────────────
func _update_ghost_trail(delta: float) -> void:
	# 1. Desplazar estelas activas y desvanecer
	for ghost in ghost_pool:
		if ghost.visible:
			ghost.global_position.x -= SCROLL_SPEED * delta
			ghost.modulate.a -= (delta / GHOST_LIFETIME) * 0.45
			if ghost.modulate.a <= 0.0:
				ghost.visible = false

	# 2. Emitir nueva estela periódica solo al correr en tierra
	if is_on_floor() and anim_sprite.animation == "run" and not is_attacking:
		ghost_timer += delta
		if ghost_timer >= current_ghost_interval:
			ghost_timer = 0.0
			_spawn_ghost()
	else:
		ghost_timer = 0.0


func _spawn_ghost() -> void:
	var ghost: Sprite2D = ghost_pool[ghost_index]
	ghost_index = (ghost_index + 1) % GHOST_COUNT

	if ghost.get_parent() == null:
		var parent_node: Node = get_parent()
		if parent_node != null:
			parent_node.add_child.call_deferred(ghost)

	var current_tex: Texture2D = anim_sprite.sprite_frames.get_frame_texture(
		anim_sprite.animation, anim_sprite.frame)
	if current_tex != null:
		ghost.texture = current_tex
		ghost.scale = anim_sprite.scale
		ghost.global_position = anim_sprite.global_position
		ghost.rotation = anim_sprite.rotation
		# Color de estela varía según la fase de impulso actual
		match run_phase:
			RunPhase.TROT:
				ghost.modulate = Color(0.65, 0.70, 0.92, 0.22)  # Azulado suave (trote)
			RunPhase.RUN:
				ghost.modulate = Color(0.95, 0.22, 0.28, 0.38)  # Carmesí (carrera)
			RunPhase.SPRINT:
				ghost.modulate = Color(1.00, 0.55, 0.10, 0.55)  # Naranja intenso (sprint)
		ghost.visible = true
