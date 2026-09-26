@tool
extends EditorPlugin

var autoload_list:Array[String]

var script_editor:ScriptEditor
var scripts_container:BoxContainer
var script_list:ItemList


var my_plugin_action_container:Container


var autoload_only_button := CheckButton.new()

var filter_button_global_class := Button.new()
var filter_button_scene := Button.new()
var filter_button_script := Button.new()
var filter_button_text := Button.new()
var filter_button_help := Button.new()


var class_icon_mode_button := CheckButton.new()

const PLUGIN_UPDATED_ITEM_META:StringName = &""

const BUTTONL_CONTROL_DESCRIPTION:String = "Ctrlを押しながらクリックすると単独でフィルタリング切り替えが出来ます
Shiftを押しながらクリックすると全て有効に出来ます"

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass
	
	ProjectSettings.settings_changed.connect(update_autoload)
	update_autoload()
	
	script_editor = EditorInterface.get_script_editor()
	script_list = script_editor.find_child("*ItemList*", true, false)
	
	
	var filter_scripts:LineEdit
	for i:LineEdit in script_editor.find_children("*LineEdit*", "LineEdit", true, false):
		if i.placeholder_text == "Filter Scripts":
			filter_scripts = i
			break
	
	
	scripts_container = filter_scripts.get_parent()
	
	
	my_plugin_action_container = HBoxContainer.new()
	my_plugin_action_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	
	
	
	class_icon_mode_button.theme_type_variation = &"FlatButton"
	class_icon_mode_button.icon = get_editor_icon(&"Object")
	class_icon_mode_button.tooltip_text = "クラスアイコンモード"
	class_icon_mode_button.toggle_mode = true
	class_icon_mode_button.toggled.connect(update_with_reload_by_engine.unbind(1))
	my_plugin_action_container.add_child(class_icon_mode_button)
	
	
	
	var scroll_container := ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll_container.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_ALL
	my_plugin_action_container.add_child(scroll_container)
	
	var h_box_container := HBoxContainer.new()
	h_box_container.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	scroll_container.add_child(h_box_container)
	
	autoload_only_button.toggle_mode = true
	autoload_only_button.set_pressed_no_signal(false)
	super_flat_button_theming(autoload_only_button)
	autoload_only_button.icon = get_editor_icon(&"Environment")
	autoload_only_button.tooltip_text = "Autoloadのみ表示"
	autoload_only_button.toggled.connect(update_with_reload_by_engine.unbind(1))
	h_box_container.add_child(autoload_only_button)
	
	var separetor := VSeparator.new()
	h_box_container.add_child(separetor)
	
	filter_button_global_class.toggle_mode = true
	filter_button_global_class.set_pressed_no_signal(true)
	super_flat_button_theming(filter_button_global_class)
	filter_button_global_class.icon = get_editor_icon(&"CollisionShape3D")
	filter_button_global_class.tooltip_text = "class_nameが宣言されているスクリプト" + "\n\n" + BUTTONL_CONTROL_DESCRIPTION
	filter_button_global_class.toggled.connect(_on_filter_button_toggled.bind(filter_button_global_class))
	h_box_container.add_child(filter_button_global_class)
	
	filter_button_scene.toggle_mode = true
	filter_button_scene.set_pressed_no_signal(true)
	super_flat_button_theming(filter_button_scene)
	filter_button_scene.icon = get_editor_icon(&"PackedScene")
	filter_button_scene.tooltip_text = "同じ階層に同じ名前のシーンがあるスクリプト" + "\n\n" + BUTTONL_CONTROL_DESCRIPTION
	filter_button_scene.toggled.connect(_on_filter_button_toggled.bind(filter_button_scene))
	h_box_container.add_child(filter_button_scene)
	
	filter_button_script.toggle_mode = true
	filter_button_script.set_pressed_no_signal(true)
	super_flat_button_theming(filter_button_script)
	filter_button_script.icon = get_editor_icon(&"GDScript")
	filter_button_script.tooltip_text = "他の項目に当てはまらないただのスクリプト" + "\n\n" + BUTTONL_CONTROL_DESCRIPTION
	filter_button_script.toggled.connect(_on_filter_button_toggled.bind(filter_button_script))
	h_box_container.add_child(filter_button_script)
	
	filter_button_text.toggle_mode = true
	filter_button_text.set_pressed_no_signal(true)
	super_flat_button_theming(filter_button_text)
	filter_button_text.icon = get_editor_icon(&"TextFile")
	filter_button_text.tooltip_text = "スクリプトではないただのテキストファイル" + "\n\n" + BUTTONL_CONTROL_DESCRIPTION
	filter_button_text.toggled.connect(_on_filter_button_toggled.bind(filter_button_text))
	h_box_container.add_child(filter_button_text)
	
	filter_button_help.toggle_mode = true
	filter_button_help.set_pressed_no_signal(true)
	super_flat_button_theming(filter_button_help)
	filter_button_help.icon = get_editor_icon(&"Help")
	filter_button_help.tooltip_text = "ドキュメント" + "\n\n" + BUTTONL_CONTROL_DESCRIPTION
	filter_button_help.toggled.connect(_on_filter_button_toggled.bind(filter_button_help))
	h_box_container.add_child(filter_button_help)
	
	
	
	
	
	scripts_container.add_child(my_plugin_action_container)
	scripts_container.move_child(my_plugin_action_container, 1)
	


func update_autoload() -> void:
	var project_dot_godot := ConfigFile.new()
	if project_dot_godot.load("res://project.godot") != OK:
		return
	if not project_dot_godot.has_section("autoload"):
		return
	
	for key in project_dot_godot.get_section_keys("autoload"):
		
		if not ProjectSettings.has_setting("autoload/" + key):
			continue
		
		var p:String = ProjectSettings.get_setting("autoload/" + key)
		p = p.trim_prefix("*")
		autoload_list.append(ResourceUID.ensure_path(p))



func _on_filter_button_toggled(toggled_on: bool, button:Button) -> void:
	var buttons:Array[Button] = [
		filter_button_global_class,
		filter_button_scene,
		filter_button_script,
		filter_button_text,
		filter_button_help,
	]
	
	if Input.is_key_pressed(KEY_CTRL):
		
		var buttons_but_excluded_this:Array[Button] = buttons.duplicate_deep(Resource.DeepDuplicateMode.DEEP_DUPLICATE_NONE)
		buttons_but_excluded_this.erase(button)
		
		var all_same:bool = true
		for i in buttons_but_excluded_this:
			if i.button_pressed == toggled_on:
				all_same = false
				break
		
		##ctrlクリックの動作が通常のクリックと同じになってしまう場合、ctrlクリックの動作を反転させる
		if all_same:
			toggled_on = not toggled_on
		
		for i in buttons:
			i.set_pressed_no_signal(not toggled_on)
		
		button.set_pressed_no_signal(toggled_on)
		
	elif Input.is_key_pressed(KEY_SHIFT):
		for i in buttons:
			i.set_pressed_no_signal(true)
	
	
	update_with_reload_by_engine()



func update_with_reload_by_engine() -> void:
	var size := scripts_container.size## 必須がついていないのは hide時にちかちかしないように仮の見た目を複製そて置く。のやつ
	var tmp := scripts_container.duplicate(0)
	scripts_container.hide()# 必須
	
	
	tmp.custom_minimum_size = size
	tmp.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	tmp.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	scripts_container.get_parent().add_child(tmp)
	scripts_container.get_parent().move_child(tmp, 0)
	
	##なぜ2frameなのかは分からない
	await get_tree().process_frame## 必須
	await get_tree().process_frame## 必須
	
	scripts_container.get_parent().remove_child(tmp)
	tmp.queue_free()
	
	scripts_container.show()## 必須
	update()## 必須


func super_flat_button_theming(button:Button) -> void:
	button.theme_type_variation = &"FlatButton"
	button.add_theme_stylebox_override(&"pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override(&"hover_pressed", button.get_theme_stylebox(&"hover"))
	button.add_theme_color_override(&"icon_pressed_color", Color.WHITE)
	button.add_theme_color_override(&"icon_hover_pressed_color", Color.WHITE)
	button.add_theme_color_override(&"icon_normal_color", Color.WEB_GRAY)
	button.add_theme_color_override(&"icon_hover_color", Color.WEB_GRAY)



func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
	
	my_plugin_action_container.queue_free()


func _process(delta: float) -> void:
	var has_meta:bool = false
	if script_list.item_count > 0:
		if script_list.get_item_tooltip(script_list.item_count - 1) == PLUGIN_UPDATED_ITEM_META:
			has_meta = true
	
	if not has_meta:
		update()



func update() -> void:
	
	if script_list.item_count > 0:
		if script_list.get_item_tooltip(script_list.item_count - 1) == PLUGIN_UPDATED_ITEM_META:
			script_list.remove_item(script_list.item_count - 1)
	
	var remove_idx_list:Array[int]
	
	for i in script_list.item_count:
		if script_list.get_item_metadata(i) is StringName:
			if script_list.get_item_metadata(i) == PLUGIN_UPDATED_ITEM_META:
				continue
		
		var path = script_list.get_item_tooltip(i)
		
		if script_list.get_item_icon(i) == get_editor_icon(&"Help"):
			if not filter_button_help.button_pressed or autoload_only_button.button_pressed:
				if not remove_idx_list.has(i):
					remove_idx_list.append(i)
			continue
		if script_list.get_item_icon(i) == get_editor_icon(&"TextFile"):
			if not filter_button_text.button_pressed or autoload_only_button.button_pressed:
				if not remove_idx_list.has(i):
					remove_idx_list.append(i)
			continue
		
		
		var script:Script = load(path)
		if not script:
			continue
		
		
		
		
		
		
		##ツールスクリプトの色を設定（エンジンのが気に入らないので変える）
		if script.is_tool():
			## @toolの色のイメージでアノテーションの色にする
			var tool_color:Color = EditorInterface.get_editor_settings().get_setting("text_editor/theme/highlighting/gdscript/annotation_color")
			script_list.set_item_icon_modulate(i, tool_color)
			if class_icon_mode_button.button_pressed:
				script_list.set_item_icon_modulate(i, Color.WHITE)
			##背景のいろを変える　（こっちのが好き & グローバルクラスのアイコンが色付きなのでアイコンの色だけだと分かりづらい）
			script_list.set_item_custom_bg_color(i, Color(tool_color, 0.06))
		
		##Autoloadは文字の色変える(文字の色を変えるという決定は仮)
		var is_autoload:bool = autoload_list.has(path) or autoload_list.has(path.get_basename() + ".tscn") or autoload_list.has(path.get_basename() + ".scn")
		if is_autoload:
			script_list.set_item_custom_fg_color(i, Color.PALE_GREEN)
		if autoload_only_button.button_pressed:
			if not is_autoload:
				if not remove_idx_list.has(i):
					remove_idx_list.append(i)
		
		
		
		if class_icon_mode_button.button_pressed:
			script_list.set_item_icon(i, get_class_icon(script))
		
		
		if script.get_global_name():
			if not class_icon_mode_button.button_pressed:
				script_list.set_item_icon(i, get_editor_icon(&"CollisionShape3D"))
			
			if not filter_button_global_class.button_pressed:
				if not remove_idx_list.has(i):
					remove_idx_list.append(i)
			continue
		
		if script.is_built_in() or ResourceLoader.exists(path.get_basename() + ".tscn", "PackedScene") or ResourceLoader.exists(path.get_basename() + ".scn", "PackedScene"):
			if not class_icon_mode_button.button_pressed:
				script_list.set_item_icon(i, get_editor_icon(&"PackedScene"))
			
			if not filter_button_scene.button_pressed:
				if not remove_idx_list.has(i):
					remove_idx_list.append(i)
			continue
		
		
		if not filter_button_script.button_pressed:
			
			if not remove_idx_list.has(i):
				remove_idx_list.append(i)
		
		
		
		
	
	remove_idx_list.reverse()
	for i:int in remove_idx_list:
		script_list.remove_item(i)
	
	##ツールチップが出るとItemListがリロードされてツールチップが消えてまた出て、でチラチラする且つツールチップの内容が認識できないのでツールチップをオフにする
	if not remove_idx_list.is_empty():
		for i in script_list.item_count:
			script_list.set_item_tooltip_enabled(i, false)
	
	script_list.add_icon_item(null, false)
	script_list.set_item_tooltip(script_list.item_count - 1, PLUGIN_UPDATED_ITEM_META)

#@export_tool_button("", "Environment")


func get_class_icon(script:Script) -> Texture2D:
	var icon:Texture2D
	
	while true:
		
		for dic:Dictionary in ProjectSettings.get_global_class_list():
			if dic.path == script.resource_path:
				if (dic.icon as String):
					icon = load(dic.icon as String)
					break
		
		if icon:
			break
		
		if not script.get_base_script():
			break
		script = script.get_base_script()
		
	if icon:
		return icon
	
	var resource_class_name:StringName = get_extended_class(script)
	
	if script_list.has_theme_icon(resource_class_name, &"EditorIcons"):
		return get_editor_icon(resource_class_name)
	else:
		return get_editor_icon(&"Object")



func get_extended_class(script:Script) -> String:
	if not script.has_source_code():
		return ""
	
	for line:int in script.source_code.count("\n"):
		var line_text := script.source_code.get_slice("\n",line)
		
		if line_text.remove_chars(" \t").is_empty():
			continue
		
		const CAN_BEFORE_EXTENDS:Array[String] = [
			"class_name",
			"extends",
			"@icon",
			"@static_unload",
			"@tool",
			"@abstract",
		]
		var found:bool = false
		for i in CAN_BEFORE_EXTENDS:
			if line_text.begins_with(i):
				found = true
				break
		
		if not found:
			return &"Object"
		
		
		if line_text.contains("extends"):
			return line_text.get_slice("extends ", 1)
	
	return ""


var _editor_icon_cache:Dictionary[StringName, Texture2D]
func get_editor_icon(_name:StringName) -> Texture2D:
	if not _editor_icon_cache.has(_name):
		_editor_icon_cache[_name] = script_list.get_theme_icon(_name, &"EditorIcons")
	return _editor_icon_cache[_name]
