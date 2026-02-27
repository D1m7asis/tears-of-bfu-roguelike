extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var bar: ProgressBar = $PanelContainer/VBoxContainer/ProgressBar

func set_visible_active(active: bool) -> void:
	panel.visible = active

func set_progress(p: float) -> void:
	bar.value = clamp(p, 0.0, 1.0)
