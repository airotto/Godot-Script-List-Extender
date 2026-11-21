@tool
extends EditorPlugin

const DropdownAction = preload("uid://dnutmt8fmxxlg")
var dropdown_action:DropdownAction

var autoload_list:Array[String]

var script_editor:ScriptEditor: get = get_script_editor
var scripts_container:BoxContainer: get = get_scripts_container
var script_list:ItemList: get = get_script_list

var my_plugin_action_container:Container: get = get_my_plugin_action_container

var class_icon_mode_button := CheckButton.new()
var autoload_only_button := CheckButton.new()

var filter_button_global_class := Button.new()
var filter_button_scene := Button.new()
var filter_button_script := Button.new()
var filter_button_text := Button.new()
var filter_button_help := Button.new()

var script_list_menu:PopupMenu: get = get_script_list_menu
const SEPATOR_ID:int = -100
const SCRIPT_LIST_MENU_ADD_ITEM_MAP:Dictionary[String, int] = {
	"Scene" : SEPATOR_ID,
	"Copy Scene File Path" : 924948375,
	"Copy Scene File UID" : 924948376,
	"Open Scene" : 924948377,
	"Scene Show in FileSystem" : 924948378,
}

const PLUGIN_UPDATED_ITEM_META:StringName = &""


func _enter_tree() -> void:
	ProjectSettings.settings_changed.connect(update_autoload)
	update_autoload()
	
	
	scripts_container.add_child(my_plugin_action_container)
	scripts_container.move_child(my_plugin_action_container, 1)
	
	
	var menu_buttons_parent:Container = scripts_container.get_parent().get_parent().get_parent().find_child("*HBoxContainer*", false, false)
	var menu_button_list:Array[MenuButton]
	menu_button_list.assign(menu_buttons_parent.find_children("*MenuButton*", "MenuButton", true, false) )
	dropdown_action = DropdownAction.new(menu_button_list)
	dropdown_action._enter()
	
	
	script_list_menu.visibility_changed.connect(_on_script_list_menu_visibility_changed)
	script_list_menu.id_pressed.connect(_on_script_list_menu_id_pressed)


func _exit_tree() -> void:
	if dropdown_action:
		dropdown_action._exit()
	my_plugin_action_container.queue_free()



func _process(delta: float) -> void:
	var has_meta:bool = false
	if script_list.item_count > 0:
		if script_list.get_item_tooltip(script_list.item_count - 1) == PLUGIN_UPDATED_ITEM_META:
			has_meta = true
	
	if not has_meta:
		update()




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


func bind_filter_toggle_button(button:Button, icon_name:StringName, tooltip_text:String, container:Container) -> void:
	const BUTTONL_CONTROL_DESCRIPTION:String = "Ctrlを押しながらクリックすると単独でフィルタリング切り替えが出来ます\nShiftを押しながらクリックすると全て有効に出来ます"
	bind_toggle_button(button, icon_name, tooltip_text + "\n\n" + BUTTONL_CONTROL_DESCRIPTION, _on_filter_button_toggled.bind(button), container)
	button.set_pressed_no_signal(true)


func bind_toggle_button(button:Button, icon_name:StringName, tooltip_text:String, toggled_connect:Callable, container:Container) -> void:
	button.toggle_mode = true
	super_flat_button_theming(button)
	button.icon = get_editor_icon(icon_name)
	button.tooltip_text = tooltip_text
	button.toggled.connect(toggled_connect)
	container.add_child(button)


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
		
		if path == tr("Unsaved file."):
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
		
		if script.is_built_in() or get_scene_path_from_script_path(path):
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


func _on_script_list_menu_visibility_changed():
	if not script_list_menu.visible:
		return
	
	var selected:int = script_list.get_selected_items()[0]
	if script_list.get_item_icon(selected) != get_editor_icon(&"PackedScene"):
		return
	
	
	var insert_idx:int
	for i in script_list_menu.item_count:
		if script_list_menu.get_item_text(i) == "Show in FileSystem":
			insert_idx = i + 1
			break
	
	for i in SCRIPT_LIST_MENU_ADD_ITEM_MAP.size():
		if SCRIPT_LIST_MENU_ADD_ITEM_MAP.values()[i] == SEPATOR_ID:
			script_list_menu.add_separator(SCRIPT_LIST_MENU_ADD_ITEM_MAP.keys()[i], SCRIPT_LIST_MENU_ADD_ITEM_MAP.values()[i])
		else:
			script_list_menu.add_item(SCRIPT_LIST_MENU_ADD_ITEM_MAP.keys()[i], SCRIPT_LIST_MENU_ADD_ITEM_MAP.values()[i])
		script_list_menu.set_item_index(script_list_menu.item_count - 1 , insert_idx + i)


func _on_script_list_menu_id_pressed(id:int) -> void:
	if not SCRIPT_LIST_MENU_ADD_ITEM_MAP.values().has(id):
		return
	
	
	var selected:int = script_list.get_selected_items()[0]
	var script_path:String = script_list.get_item_tooltip(selected)
	var scene_path:String = get_scene_path_from_script_path(script_path)
	if scene_path.is_empty():
		return
	
	if id == SCRIPT_LIST_MENU_ADD_ITEM_MAP["Copy Scene File Path"]:
		DisplayServer.clipboard_set(scene_path)
	if id == SCRIPT_LIST_MENU_ADD_ITEM_MAP["Copy Scene File UID"]:
		DisplayServer.clipboard_set(ResourceUID.path_to_uid(scene_path))
	if id == SCRIPT_LIST_MENU_ADD_ITEM_MAP["Open Scene"]:
		EditorInterface.open_scene_from_path(scene_path)
	if id == SCRIPT_LIST_MENU_ADD_ITEM_MAP["Scene Show in FileSystem"]:
		EditorInterface.select_file(scene_path)
		EditorInterface.get_file_system_dock().show()

func get_script_editor() -> ScriptEditor:
	if not script_editor:
		script_editor = EditorInterface.get_script_editor()
	return script_editor

func get_scripts_container() -> BoxContainer:
	if not scripts_container:
		var filter_scripts:LineEdit
		for i:LineEdit in script_editor.find_children("*LineEdit*", "LineEdit", true, false):
			if i.placeholder_text == "Filter Scripts":
				filter_scripts = i
				break
		scripts_container = filter_scripts.get_parent()
	return scripts_container

func get_script_list() -> ItemList:
	if not script_list:
		script_list = script_editor.find_child("*ItemList*", true, false)
	return script_list

func get_my_plugin_action_container() -> HBoxContainer:
	if not my_plugin_action_container:
		my_plugin_action_container = HBoxContainer.new()
		my_plugin_action_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		bind_toggle_button(class_icon_mode_button, &"Object", "クラスアイコンモード", update_with_reload_by_engine.unbind(1), my_plugin_action_container)
		
		var scroll_container := ScrollContainer.new()
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll_container.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_ALL
		my_plugin_action_container.add_child(scroll_container)
		
		var h_box_container := HBoxContainer.new()
		h_box_container.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
		scroll_container.add_child(h_box_container)
		
		bind_toggle_button(autoload_only_button, &"Environment", "Autoloadのみ表示", update_with_reload_by_engine.unbind(1), h_box_container)
		
		var separetor := VSeparator.new()
		h_box_container.add_child(separetor)
		
		bind_filter_toggle_button(filter_button_global_class, &"CollisionShape3D", "class_nameが宣言されているスクリプト", h_box_container)
		bind_filter_toggle_button(filter_button_scene, &"PackedScene", "同じ階層に同じ名前のシーンがあるスクリプト", h_box_container)
		bind_filter_toggle_button(filter_button_script, &"GDScript", "他の項目に当てはまらないただのスクリプト", h_box_container)
		bind_filter_toggle_button(filter_button_text, &"TextFile", "スクリプトではないただのテキストファイル", h_box_container)
		bind_filter_toggle_button(filter_button_help, &"Help", "ドキュメント", h_box_container)
	
	return my_plugin_action_container

func get_script_list_menu() -> PopupMenu:
	if not script_list_menu:
		script_list_menu = EditorInterface.get_script_editor().find_children("*PopupMenu*", "PopupMenu", false, false)[0]
	return script_list_menu


func get_scene_path_from_script_path(script_path:String) -> String:
	if ResourceLoader.exists(script_path.get_basename() + ".tscn", "PackedScene"):
		return script_path.get_basename() + ".tscn"
	elif ResourceLoader.exists(script_path.get_basename() + ".scn", "PackedScene"):
		return script_path.get_basename() + ".scn"
	return ""


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
	
	var resource_class_name:StringName = script.get_instance_base_type()
	
	if script_list.has_theme_icon(resource_class_name, &"EditorIcons"):
		return get_editor_icon(resource_class_name)
	else:
		return get_editor_icon(&"Object")


var _editor_icon_cache:Dictionary[StringName, Texture2D]
func get_editor_icon(_name:StringName) -> Texture2D:
	if not _editor_icon_cache.has(_name):
		_editor_icon_cache[_name] = script_list.get_theme_icon(_name, &"EditorIcons")
	return _editor_icon_cache[_name]
