extends Area2D
class_name Slime

## Mob Terrestre: Earth Slime (Idle Slayer V3)
## Implementado con Object Pooling y Zero GC.

signal killed(reward: int, position: Vector2)

enum State { INACTIVE, ACTIVE, DYING }

@export var reward_coins: int = 1
@export var move_speed: float = 260.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var splat_particles: CPUParticles2D = $SplatParticles

var current_state: State = State.INACTIVE
var base_scale: Vector2 = Vector2(1.0, 1.0)
var death_timer: float = 0.0

func _ready() -> void:
	_ensure_nodes()
	area_entered.connect(_on_area_entered)
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)
	deactivate()

func _ensure_nodes() -> void:
	if anim_sprite == null:
		anim_sprite = get_node_or_null("AnimatedSprite2D")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if splat_particles == null:
		splat_particles = get_node_or_null("SplatParticles")

func activate(spawn_pos: Vector2, speed: float = 260.0, reward: int = 1) -> void:
	_ensure_nodes()
	global_position = spawn_pos
	move_speed = speed
	reward_coins = reward
	current_state = State.ACTIVE
	visible = true
	scale = base_scale
	modulate = Color(1, 1, 1, 1)
	death_timer = 0.0

	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)

	if anim_sprite:
		anim_sprite.play("walk")
	set_process(true)

func deactivate() -> void:
	_ensure_nodes()
	current_state = State.INACTIVE
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if splat_particles:
		splat_particles.emitting = false
	set_process(false)

func _process(delta: float) -> void:
	match current_state:
		State.ACTIVE:
			position.x -= move_speed * delta
			# Despawn fuera del límite izquierdo de la pantalla
			if position.x < -100.0:
				deactivate()

		State.DYING:
			# Seguir desplazándose levemente con el suelo durante la animación de impacto
			position.x -= (move_speed * 0.4) * delta
			death_timer += delta
			# Respaldo por si no dispara el evento de animación
			if death_timer >= 0.45:
				deactivate()

func take_hit() -> void:
	if current_state != State.ACTIVE:
		return

	current_state = State.DYING
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Emitir señal de muerte con recompensa
	emit_signal("killed", reward_coins, global_position)

	# Partículas de baba verde
	if splat_particles:
		splat_particles.restart()
		splat_particles.emitting = true

	# Animación de muerte (impacto -> splat -> disolución)
	if anim_sprite:
		anim_sprite.play("death")

func _on_area_entered(area: Area2D) -> void:
	# Detectar la espada del jugador (SwordHitbox)
	if current_state == State.ACTIVE and (area.name == "SwordHitbox" or area.collision_layer == 2):
		take_hit()

func _on_animation_finished() -> void:
	if current_state == State.DYING and anim_sprite.animation == "death":
		deactivate()
