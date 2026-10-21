extends CharacterBody3D
## Pengendali pemain first-person: gerak, lompat/terbang, bongkar & pasang balok.

signal pilihan_berubah(jenis: int)

const KECEPATAN := 5.6
const KECEPATAN_LARI := 9.0
const LOMPAT := 8.6
const GRAVITASI := 23.0
const JANGKAUAN := 7.0

const PILIHAN := [Blok.RUMPUT, Blok.TANAH, Blok.BATU, Blok.PAPAN, Blok.KAYU, Blok.KACA, Blok.BATA]

var dunia: Dunia
var kamera: Camera3D
var sorotan: MeshInstance3D
var pitch := 0.0
var terbang := false
var idx_pilihan := 0

func _ready() -> void:
	var bentuk := CollisionShape3D.new()
	var kapsul := CapsuleShape3D.new()
	kapsul.radius = 0.35
	kapsul.height = 1.8
	bentuk.shape = kapsul
	add_child(bentuk)
	kamera = Camera3D.new()
	kamera.position = Vector3(0, 0.62, 0)
	kamera.fov = 75.0
	add_child(kamera)
	# Kotak sorotan balok yang dituju
	sorotan = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.002, 1.002, 1.002)
	sorotan.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	sorotan.material_override = mat
	sorotan.visible = false
	sorotan.top_level = true
	add_sibling.call_deferred(sorotan)

func pilihan() -> int:
	return PILIHAN[idx_pilihan]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0024)
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.5, 1.5)
		kamera.rotation.x = pitch
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var arah := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			idx_pilihan = (idx_pilihan + arah + PILIHAN.size()) % PILIHAN.size()
			pilihan_berubah.emit(pilihan())
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_hancurkan()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_pasang()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			idx_pilihan = event.keycode - KEY_1
			pilihan_berubah.emit(pilihan())
		elif event.keycode == KEY_F:
			terbang = not terbang
			velocity.y = 0.0

func _target() -> Dictionary:
	if dunia == null or kamera == null:
		return {}
	var asal := kamera.global_position
	var arah := -kamera.global_transform.basis.z.normalized()
	return dunia.raycast_voxel(asal, arah, JANGKAUAN)

func _hancurkan() -> void:
	var t := _target()
	if t.has("sel"):
		dunia.ubah_balok(t["sel"], Blok.UDARA)

func _pasang() -> void:
	var t := _target()
	if not t.has("sel"):
		return
	var sel: Vector3i = t["sel"] + t["normal"]
	if dunia.ambil(sel.x, sel.y, sel.z) != Blok.UDARA:
		return
	# Jangan pasang menimpa tubuh pemain
	var kotak_sel := AABB(Vector3(sel), Vector3.ONE)
	var kotak_pemain := AABB(global_position - Vector3(0.36, 0.9, 0.36), Vector3(0.72, 1.8, 0.72))
	if kotak_sel.intersects(kotak_pemain):
		return
	dunia.ubah_balok(sel, pilihan())

func _process(_delta: float) -> void:
	if sorotan == null:
		return
	var t := _target()
	if t.has("sel"):
		sorotan.visible = true
		sorotan.global_position = Vector3(t["sel"]) + Vector3(0.5, 0.5, 0.5)
	else:
		sorotan.visible = false

func _physics_process(delta: float) -> void:
	var masukan := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var arah := (transform.basis * Vector3(masukan.x, 0, masukan.y))
	arah.y = 0
	arah = arah.normalized() if masukan != Vector2.ZERO else Vector3.ZERO
	var cepat := KECEPATAN_LARI if Input.is_physical_key_pressed(KEY_SHIFT) and not terbang else KECEPATAN
	velocity.x = arah.x * cepat
	velocity.z = arah.z * cepat
	if terbang:
		var naik := float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
		velocity.y = naik * cepat
	else:
		if not is_on_floor():
			velocity.y -= GRAVITASI * delta
		elif Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = LOMPAT
	move_and_slide()
