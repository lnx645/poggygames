extends CharacterBody3D
## Pemain PoggyClimb: avatar kotak ala Roblox, kamera orang ketiga,
## gerak relatif kamera, panjat tangga, respawn di checkpoint.

signal jatuh

const CEPAT := 6.4
const LOMPAT := 9.8
const GRAVITASI := 24.0

var lintasan: Lintasan
var titik_respawn := Vector3.ZERO
var sentuh_gerak := Vector2.ZERO
var sentuh_lompat := false

var _putar: Node3D
var _kamera: Camera3D
var _yaw := 0.0
var _pitch := 0.38
var _model: Node3D
var _kaki_kiri: Node3D
var _kaki_kanan: Node3D
var _lengan_kiri: Node3D
var _lengan_kanan: Node3D
var _fase_jalan := 0.0
var _di_tangga := false

func _bahan(warna: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = warna
	m.roughness = 0.85
	return m

func _kotak_model(induk: Node3D, posisi: Vector3, ukuran: Vector3, warna: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = ukuran
	mesh.material = _bahan(warna)
	mi.mesh = mesh
	mi.position = posisi
	induk.add_child(mi)
	return mi

func _ready() -> void:
	collision_layer = 2 # pemain di layer 2 — area pemicu hanya memantau layer ini
	collision_mask = 1 # bertabrakan dengan lintasan (layer 1)
	var bentuk := CollisionShape3D.new()
	var kapsul := CapsuleShape3D.new()
	kapsul.radius = 0.42
	kapsul.height = 1.9
	bentuk.shape = kapsul
	add_child(bentuk)
	_bangun_model()
	# Poros kamera
	_putar = Node3D.new()
	_putar.position = Vector3(0, 0.4, 0)
	add_child(_putar)
	var lengan_spring := SpringArm3D.new()
	lengan_spring.spring_length = 9.0
	lengan_spring.margin = 0.4
	_putar.add_child(lengan_spring)
	_kamera = Camera3D.new()
	_kamera.fov = 68.0
	lengan_spring.add_child(_kamera)

func _bangun_model() -> void:
	_model = Node3D.new()
	_model.position = Vector3(0, -0.95, 0) # kaki di dasar kapsul
	add_child(_model)
	var kulit := Color(0.98, 0.79, 0.28) # kuning Roblox
	var baju := Color(0.15, 0.38, 0.92) # biru
	var celana := Color(0.62, 0.78, 0.2) # hijau kekuningan
	# Kaki (poros di pinggul y=0.85)
	_kaki_kiri = Node3D.new()
	_kaki_kiri.position = Vector3(-0.24, 0.85, 0)
	_model.add_child(_kaki_kiri)
	_kotak_model(_kaki_kiri, Vector3(0, -0.42, 0), Vector3(0.42, 0.85, 0.46), celana)
	_kaki_kanan = Node3D.new()
	_kaki_kanan.position = Vector3(0.24, 0.85, 0)
	_model.add_child(_kaki_kanan)
	_kotak_model(_kaki_kanan, Vector3(0, -0.42, 0), Vector3(0.42, 0.85, 0.46), celana)
	# Badan
	_kotak_model(_model, Vector3(0, 1.22, 0), Vector3(0.98, 0.78, 0.48), baju)
	# Lengan (poros di bahu y=1.58)
	_lengan_kiri = Node3D.new()
	_lengan_kiri.position = Vector3(-0.66, 1.58, 0)
	_model.add_child(_lengan_kiri)
	_kotak_model(_lengan_kiri, Vector3(0, -0.4, 0), Vector3(0.34, 0.82, 0.44), kulit)
	_lengan_kanan = Node3D.new()
	_lengan_kanan.position = Vector3(0.66, 1.58, 0)
	_model.add_child(_lengan_kanan)
	_kotak_model(_lengan_kanan, Vector3(0, -0.4, 0), Vector3(0.34, 0.82, 0.44), kulit)
	# Kepala + wajah (menghadap -Z)
	_kotak_model(_model, Vector3(0, 1.92, 0), Vector3(0.66, 0.62, 0.62), kulit)
	_kotak_model(_model, Vector3(-0.15, 1.98, -0.32), Vector3(0.09, 0.14, 0.02), Color(0.1, 0.1, 0.1))
	_kotak_model(_model, Vector3(0.15, 1.98, -0.32), Vector3(0.09, 0.14, 0.02), Color(0.1, 0.1, 0.1))
	_kotak_model(_model, Vector3(0, 1.8, -0.32), Vector3(0.3, 0.05, 0.02), Color(0.1, 0.1, 0.1))

func lihat(dx: float, dy: float) -> void:
	_yaw -= dx * 0.0042
	_pitch = clampf(_pitch + dy * 0.0035, -0.25, 1.15)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		lihat(event.relative.x, event.relative.y)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func respawn() -> void:
	global_position = titik_respawn
	velocity = Vector3.ZERO
	_yaw = 0.0

func _physics_process(delta: float) -> void:
	_putar.rotation = Vector3(_pitch, _yaw, 0)
	# Tangga?
	_di_tangga = false
	if lintasan:
		for z in lintasan.zona_tangga:
			if (z as Area3D).overlaps_body(self):
				_di_tangga = true
				break
	var maju := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var samping := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var masukan := Vector2(samping, -maju) + sentuh_gerak
	if masukan.length() > 1.0:
		masukan = masukan.normalized()
	# Arah gerak relatif kamera (di tanah)
	var basis_kamera := Basis(Vector3.UP, _yaw)
	var arah := (basis_kamera * Vector3(masukan.x, 0, masukan.y))
	if arah.length() > 0.05:
		arah = arah.normalized()
		# Model menghadap arah jalan
		var target_yaw := atan2(-arah.x, -arah.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 14.0 * delta)
	else:
		arah = Vector3.ZERO
	if _di_tangga:
		velocity.x = arah.x * CEPAT * 0.5
		velocity.z = arah.z * CEPAT * 0.5
		var naik := (1.0 if masukan.y < -0.3 or Input.is_physical_key_pressed(KEY_W) else 0.0) - (1.0 if masukan.y > 0.3 or Input.is_physical_key_pressed(KEY_S) else 0.0)
		velocity.y = naik * 3.4
		if Input.is_physical_key_pressed(KEY_SPACE) or sentuh_lompat:
			velocity.y = LOMPAT * 0.8
	else:
		velocity.x = arah.x * CEPAT
		velocity.z = arah.z * CEPAT
		if not is_on_floor():
			velocity.y -= GRAVITASI * delta
		elif Input.is_physical_key_pressed(KEY_SPACE) or sentuh_lompat:
			velocity.y = LOMPAT
	move_and_slide()
	# Animasi ayunan kaki/lengan
	var laju_horizontal := Vector2(velocity.x, velocity.z).length()
	if laju_horizontal > 0.4 and (is_on_floor() or _di_tangga):
		_fase_jalan += delta * laju_horizontal * 1.7
		var ayun := sin(_fase_jalan) * 0.65
		_kaki_kiri.rotation.x = ayun
		_kaki_kanan.rotation.x = -ayun
		_lengan_kiri.rotation.x = -ayun * 0.8
		_lengan_kanan.rotation.x = ayun * 0.8
	else:
		_kaki_kiri.rotation.x = lerpf(_kaki_kiri.rotation.x, 0.0, 12 * delta)
		_kaki_kanan.rotation.x = lerpf(_kaki_kanan.rotation.x, 0.0, 12 * delta)
		_lengan_kiri.rotation.x = lerpf(_lengan_kiri.rotation.x, 0.0, 12 * delta)
		_lengan_kanan.rotation.x = lerpf(_lengan_kanan.rotation.x, 0.0, 12 * delta)
	# Jatuh dari jalur → respawn
	if global_position.y < titik_respawn.y - 26.0:
		respawn()
		jatuh.emit()
