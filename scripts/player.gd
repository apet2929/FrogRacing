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
@export var tongue_length = 600
@export var gravity_scl = 1.0 # defaults to 1
@export var forward_impulse = 100
@export var hop_friction_threshold = 350  # How fast you have to be going before friction is reduced (so you don't accelerate infinitely when you just hold right)
@export var friction_high = 0.85
@export var friction_low = 0.45
const jump_buffer_window_seconds = 5
const num_jump_charge_chunks = 4

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
var recursion_count = 0
var recursion_limit = 100
var grapple_attempt_timeout = false

# Temp flags
var grapple_broke = false


func process_state(delta):
	recursion_count += 1
	if recursion_count > recursion_limit:
		print("ERR - Recursion limit reached!")
		return
		
	if state == States.IDLE:
		idle_state(delta)
	elif state == States.HOP:
		hop_state(delta)
	elif state == States.GRAPPLE:
		grapple_state(delta)
	else:
		pass

func set_state(new_state, delta) -> void:
	state = new_state
	process_state(delta)
	
func reset_flags():
	grapple_broke = false
	
func process_timers(delta):
	
	if last_jump != -1:
		last_jump += delta
	if buffered_jump_timer != -1:
		buffered_jump_timer += delta
		
func process_physics_constants():
	if abs(self.linear_velocity.x) < hop_friction_threshold:
		self.physics_material_override.friction = friction_high
	else:
		self.physics_material_override.friction = friction_low
	

func _physics_process(delta: float) -> void:
	last_jump_charge = effective_jump_charge
	update_charge(delta) # moved from before process_state() to after. If this breaks anything, move back
	update_direction()
	recursion_count = 0
	
	process_state(delta)

	# cleanup
	reset_flags()
	process_physics_constants()
	process_timers(delta)
	
# SECTION: COMMON LOGIC

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

	
# SECTION: IDLE LOGIC

func idle_state(delta: float) -> void:
	if !touching_ground():
		set_state(States.HOP, delta)
		return

	if last_jump_charge != 0 && jump_charge == 0:
		print("jumping")
		jump()
		set_state(States.HOP, delta)
	elif buffered_jump_timer != -1 && buffered_jump_timer < jump_buffer_window_seconds:
		print("buffering jump")
		last_jump_charge = buffered_jump_charge
		jump()
		set_state(States.HOP, delta)
	elif direction != Direction.NONE:
		print("hopping")
		hop()
		set_state(States.HOP, delta)
	buffered_jump_charge = -1
	buffered_jump_timer = -1

# SECTION: HOP LOGIC

func hop_state(delta):
	if touching_ground() && last_jump == -1:
		set_state(States.IDLE, delta)
	else:
		apply_central_force(Vector2(air_control * mass * direction, 0))
		if jump_charge == 0 && last_jump_charge != 0:
			buffered_jump_charge = last_jump_charge
			buffered_jump_timer = 0
		if Input.is_action_just_pressed("grapple"):
			attempt_grapple(delta)

func jump():
	var impulse = lerpf(hop_impulse, max_jump_impulse * mass, last_jump_charge)
	apply_jump_impulse(impulse)
	
func hop():
	if touching_ground() && direction != Direction.NONE && last_jump == -1:
		var impulse = hop_impulse * mass
		apply_jump_impulse(impulse)			
			
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


# SECTION: GRAPPLE LOGIC

func grapple_state(delta):
	if grapple_pos == null:
		return
	if should_break_grapple():
		break_grapple(delta)
	else:
		var diff = Vector2(grapple_pos - self.position).normalized()
		var force_vector = grapple_force * diff
		apply_central_force(force_vector)

func attempt_grapple(delta):
	if grapple_attempt_timeout:
		return
	record_grapple_attempt() # placed at end b.c if grapple_attempt_timeout is true, we won't 
	var valid_grapple_pos = calculate_grapple_pos()
	if valid_grapple_pos:
		set_grapple_pos(valid_grapple_pos)
		set_state(States.GRAPPLE, delta)

func record_grapple_attempt():
	grapple_attempt_timeout = true
	print("foo start")
	await get_tree().create_timer(0.3).timeout
	print("foo bar")
	grapple_attempt_timeout = false
	


func should_break_grapple():
	var tongue_vector = (grapple_pos - self.position)
	if tongue_vector.length_squared() < 100 || !Input.is_action_pressed("grapple"):
		return true
	var player_direction = Vector2(facing_direction, 0)
	var angle_too_large = abs(player_direction.angle_to(tongue_vector)) > PI / 2
	if angle_too_large:
		print("Breaking grapple because angle is too large")
	return angle_too_large

func break_grapple(delta):
	set_grapple_pos(null)
	grapple_broke = true
	if touching_ground():
		set_state(States.IDLE, delta)
	else:
		set_state(States.HOP, delta)
	
func calculate_grapple_pos():
	# TODO: Keep track of separate direction that doesn't get set to null (current solution is hacky)
	if $AnimatedSprite2D.flip_h:
		print('grapple left')
		$TongueRay.target_position.x = -tongue_length
	else:
		print('grapple right')
		$TongueRay.target_position.x = tongue_length

	if $TongueRay.is_colliding():
		var p = $TongueRay.get_collision_point()
		# cancel grapple if point is too close
		#var diff = p - self.position
		#if diff.length_squared() <= tongue_length: 
			#set_grapple_pos(null)
		#else: 
		return p
	return null
	
func set_grapple_pos(pos):
	grapple_pos = pos
	$Tongue.grapple_pos = pos


func _on_body_entered(body: Node) -> void:
	last_jump = -1
	floors_in_contact += 1


func _on_body_exited(body: Node) -> void:
	floors_in_contact -= 1
