extends RigidBody2D

enum States {
	IDLE,
	HOP,
	GRAPPLE
}
enum Direction {
	LEFT=-1,
	RIGHT=1,
	NONE=0
}

@export var max_jump_impulse = 3000
@export var hop_impulse = 500
@export var charge_duration = 1
@export var air_control = 50
@export var jump_angle = 45
@export var grapple_force = 120
@export var tongue_length = 200
@export var gravity_scl = 1.0 # defaults to 1
@export var forward_impulse = 100

@onready var game_manager = %GameManager

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var state = States.IDLE
var direction = Direction.NONE  # Current pressed direction on keyboard, usually NONE
var facing_direction = Direction.RIGHT  # Direction Frog is facing, guaranteed to not be NONE
var touched_ground_last_frame = false
var floors_in_contact = 0
var last_jump = -1
var jump_charge = 0
var effective_jump_charge = 0
var last_jump_charge = 0 
var grapple_pos = null  # Vector2
var buffered_jump_charge = -1
var buffered_jump_timer = -1


# Temp flags
var grapple_broke = false


const jump_buffer_window_seconds = 5
const num_jump_charge_chunks = 4


func _ready() -> void:
	self.gravity_scale = gravity_scl

func calculate_grapple_pos():
	# TODO: Keep track of separate direction that doesn't get set to null (current solution is hacky)
	if $AnimatedSprite2D.flip_h:
		$TongueRay.target_position.x = -tongue_length
	else:
		$TongueRay.target_position.x = tongue_length
	
		
	if $TongueRay.is_colliding():
		var p = $TongueRay.get_collision_point()
		var diff = p - self.position
		if diff.length_squared() < 100:
			set_grapple_pos(null)
		else: 
			set_grapple_pos(p)
	else:
		set_grapple_pos(null)
	return grapple_pos
	
func set_grapple_pos(pos):
	grapple_pos = pos
	$Tongue.grapple_pos = pos

func apply_jump_impulse(vert_impulse):
	self.apply_impulse(Vector2(forward_impulse * direction * mass, 0), Vector2.ZERO)
	self.apply_impulse(Vector2(0, -vert_impulse), Vector2.ZERO)
	last_jump = 0

func calc_effective_jump_charge():
	const chunk_size = 1.0 / num_jump_charge_chunks
	var c = 1.0
	while(1):
		if c <= 0:
			effective_jump_charge = 0
			return
		if jump_charge >= c:
			effective_jump_charge = c
			return
		c -= chunk_size
		
func should_break_grapple():
	var tongue_vector = (grapple_pos - self.position)
	if tongue_vector.length_squared() < 100 || !Input.is_action_pressed("grapple"):
		return true
	var player_direction = Vector2(facing_direction, 0)
	var angle_too_large = abs(player_direction.angle_to(tongue_vector)) > PI / 2
	if angle_too_large:
		print("Breaking grapple because angle is too large")
	return angle_too_large
	
func reset_flags():
	grapple_broke = false

func update_charge(delta):
	if Input.is_action_pressed("ui_accept"):
		jump_charge = move_toward(jump_charge, 1, delta / charge_duration)
	else:
		jump_charge = 0
	
	calc_effective_jump_charge()
		
	if game_manager:
		game_manager.jump_charge = jump_charge
		game_manager.effective_jump_charge = effective_jump_charge
	return jump_charge

func update_direction() -> int:
	var d := Input.get_axis("ui_left", "ui_right")
	if d == 1:
		direction = Direction.RIGHT
		facing_direction = Direction.RIGHT
	elif d == -1:
		direction = Direction.LEFT
		facing_direction = Direction.LEFT
	elif d == 0:
		direction = Direction.NONE
		
	if direction == Direction.LEFT:
		set_flipped(true)
	elif direction == Direction.RIGHT:
		set_flipped(false)
	return direction
	
func touching_ground() -> bool:
	return floors_in_contact > 0
	
func set_flipped(flipped):
	$AnimatedSprite2D.flip_h = flipped
	if flipped:
		$Tongue.position.x = -abs($Tongue.position.x)
	else:
		$Tongue.position.x = abs($Tongue.position.x)

func jump():
	var impulse = lerpf(hop_impulse, max_jump_impulse * mass, last_jump_charge)
	apply_jump_impulse(impulse)
	
func hop():
	if touching_ground() && direction != Direction.NONE && last_jump == -1:
		var impulse = hop_impulse * mass
		apply_jump_impulse(impulse)
	

func idle_state(delta: float) -> void:
	if !touching_ground():
		state = States.HOP
		hop_state(delta)
		return

	if last_jump_charge != 0 && jump_charge == 0:
		print("jumping")
		jump()
	elif buffered_jump_timer != -1 && buffered_jump_timer < jump_buffer_window_seconds:
		print("buffering jump")
		last_jump_charge = buffered_jump_charge
		state = States.HOP
		jump()
	elif jump_charge == 0 && direction != Direction.NONE:
		print("hopping")
		state = States.HOP
		hop()
	buffered_jump_charge = -1
	buffered_jump_timer = -1

func hop_state(delta):
	if touching_ground() && last_jump == -1:
		state = States.IDLE
	else:
		apply_central_force(Vector2(air_control * mass * direction, 0))
		if jump_charge == 0 && last_jump_charge != 0:
			buffered_jump_charge = last_jump_charge
			buffered_jump_timer = 0
		if Input.is_action_pressed("grapple") && calculate_grapple_pos() && !grapple_broke:
			state = States.GRAPPLE
			grapple_state(delta)
		
	
func grapple_state(delta):
	if grapple_pos == null:
		state = States.IDLE
		idle_state(delta)
		return
	
	if should_break_grapple():
		set_grapple_pos(null)
		grapple_broke = true
		state = States.IDLE
		idle_state(delta)
		
		return

	var force_vector = grapple_force * (grapple_pos - self.position)
	apply_central_force(force_vector)

func process_state(delta):
	if state == States.IDLE:
		idle_state(delta)
	elif state == States.HOP:
		hop_state(delta)
	elif state == States.GRAPPLE:
		grapple_state(delta)
	else:
		pass

func _physics_process(delta: float) -> void:
	last_jump_charge = effective_jump_charge
	update_charge(delta)
	update_direction()
	
	process_state(delta)

	reset_flags()
	if last_jump != -1:
		last_jump += delta
	if buffered_jump_timer != -1:
		buffered_jump_timer += delta

func _on_body_entered(body: Node) -> void:
	last_jump = -1
	floors_in_contact += 1


func _on_body_exited(body: Node) -> void:
	floors_in_contact -= 1
