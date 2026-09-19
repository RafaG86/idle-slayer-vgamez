extends Area2D
class_name Coin

## Moneda de Bronce coleccionable (Idle Slayer V3)
## Implementada con Object Pooling y Zero GC.

signal collected(coin: Coin, value: int)

@export var value: int = 1

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sparkles: CPUParticles2D = $Sparkles

var is_active: bool = false
var is_collected: bool = false
var move_speed: float = 260.0
var base_scale: Vector2 = Vector2(1.0, 1.0)
var collect_timer: float = 0.0

func _ready() -> void:
	_ensure_nodes()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if anim_sprite:
		anim_sprite.play("spin")
	deactivate()

func _ensure_nodes() -> void:
	if anim_sprite == null:
		anim_sprite = get_node_or_null("AnimatedSprite2D")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if sparkles == null:
		sparkles = get_node_or_null("Sparkles")

func activate(spawn_pos: Vector2, speed: float = 260.0, coin_val: int = 1) -> void:
	_ensure_nodes()
	global_position = spawn_pos
	move_speed = speed
	value = coin_val
	is_active = true
	is_collected = false
	visible = true
	scale = base_scale
	modulate = Color(1, 1, 1, 1)
	
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	if anim_sprite:
		anim_sprite.play("spin")
	set_process(true)

func deactivate() -> void:
	_ensure_nodes()
	is_active = false
	is_collected = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_process(false)

func _process(delta: float) -> void:
	if not is_active:
		return
		
	if is_collected:
		collect_timer += delta
		# Animación de recogida: eleva ligeramente, brilla y se desvanece
		position.y -= 75.0 * delta
		scale += Vector2(0.8, 0.8) * delta
		modulate.a = max(0.0, 1.0 - (collect_timer / 0.22))
		if collect_timer >= 0.22:
			deactivate()
		return

	# Movimiento sincrónico con el desplazamiento del suelo
	position.x -= move_speed * delta
	
	# Desactivar y retornar al pool al salir por la izquierda de la pantalla
	if position.x < -100.0:
		deactivate()

func _on_body_entered(body: Node2D) -> void:
	if not is_active or is_collected:
		return
	if body.is_in_group("player") or body is CharacterBody2D:
		_collect()

func _on_area_entered(area: Area2D) -> void:
	# También permite recolectar la moneda con la hitbox de la espada
	if not is_active or is_collected:
		return
	if area.name == "SwordHitbox" or area.is_in_group("player"):
		_collect()

func _collect() -> void:
	if is_collected:
		return
	is_collected = true
	_ensure_nodes()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	collect_timer = 0.0
	
	# Destello de partículas
	if sparkles:
		sparkles.restart()
		sparkles.emitting = true
	
	emit_signal("collected", self, value)
