@tool
extends EditorInspectorPlugin

class ContainerParts:
	var root : PanelContainer
	var elements : Container
	func _init():
		root = PanelContainer.new()
		var margin = MarginContainer.new()
		var vbox = VBoxContainer.new()
		root.add_child(margin)
		margin.add_child(vbox)
		elements = vbox
	func add(c: Control) -> void:
		elements.add_child(c)

class ElementRow:
	var root : HBoxContainer
	var left : Control
	var right : Control
	var ratio : float = 0.5
	
	func _init(left : Control, right : Control, ratio : float = 0.5):
		self.left = left
		self.right = right
		self.ratio = ratio
		root = HBoxContainer.new()
		self.left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		self.right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		self.left.size_flags_stretch_ratio = self.ratio
		self.right.size_flags_stretch_ratio = 1.0 - self.ratio

func _can_handle(object: Object) -> bool:
	return object is ShellFur

func _parse_begin(object: Object) -> void:
	var fur = object as ShellFur
	if not fur:
		var lblErr = Label.new()
		lblErr.text = "Error: object type not recognized"
		add_custom_control(lblErr)
		return

	var cont := ContainerParts.new()

	# tool heading
	var header := Label.new()
	header.text = "Editor Tools"
	header.label_settings = LabelSettings.new()
	header.label_settings.font_color = Color.WHITE
	header.label_settings.font_size = 22
	header.label_settings.outline_size = 10
	header.label_settings.outline_color = Color.BLACK
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cont.add(header)

	# make instance real button
	var btnMakeReal = Button.new()
	btnMakeReal.text = "Make Shells Real"
	btnMakeReal.pressed.connect(Callable(_make_instance_real).bind(fur))
	cont.add(btnMakeReal)

	# purge fur
	var btnPurge = Button.new()
	btnPurge.text = "Purge Shells"
	btnPurge.pressed.connect(Callable(_purge_shells).bind(fur))
	cont.add(btnPurge)
	
	# realtime toggle
	var btnRealtime = CheckButton.new()
	btnRealtime.text = "Simulate Realtime?"
	btnRealtime.button_pressed = fur.simulate_in_editor
	btnRealtime.toggled \
		.connect(Callable(_handle_process_realtime).bind(object))
	cont.add(btnRealtime)

	# append to inspector
	add_custom_control(cont.root)

func _make_instance_real(fur : ShellFur) -> void:
	EditorInterface.mark_scene_as_unsaved()
	FurTools.update_all_shells_on(fur)
	if not fur.furry_context:
		fur.furry_context = FurTools.FurryModelContext.new(fur)
	fur.furry_context.load_all_shells(fur)


func _purge_shells(fur : ShellFur) -> void:
	EditorInterface.mark_scene_as_unsaved()
	var targets := FurTools.get_target_meshes(fur)
	for t in targets:
		var shells := FurTools.get_instanced_shells_for(t)
		for s in shells:
			s.call_deferred("queue_free")

func _handle_process_realtime(is_pressed : bool, fur : ShellFur) -> void:
	print("Processing realtime: " + str(is_pressed))
	fur.simulate_in_editor = is_pressed
	fur.set_physics_process(is_pressed)
	

