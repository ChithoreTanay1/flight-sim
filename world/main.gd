extends Node3D
## Wires the pilot input, cameras and HUD to the aircraft.

@onready var _aircraft: Aircraft = $Aircraft
@onready var _input: PilotInput = $PilotInput


func _ready() -> void:
	_input.aircraft = _aircraft
	$Camera.setup(_aircraft, _input)
	$HUD/Display.setup(_aircraft, _input)
