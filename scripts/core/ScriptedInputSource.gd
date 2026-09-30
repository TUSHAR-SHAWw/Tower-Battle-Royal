class_name ScriptedInputSource
extends InputSource

## An InputSource that replays a scripted InputIntent instead of reading devices.
##
## Why this exists: the player's components never read `Input` directly — they read
## whatever the attached InputSource produces (ARCHITECTURE.md §6). A test that
## calls `MovementComponent.accelerate_toward()` by hand is therefore not testing
## the player at all: the state machine runs its own `apply_motion()` on the same
## frame and overwrites it. Feeding an intent through a real InputSource drives the
## state machine, the movement component and the camera exactly as play does, which
## is what makes the assertions mean something.
##
## It is also the reference implementation for the bots (M7) and the network driver
## (M20): both are "produce an InputIntent from somewhere other than a keyboard".

## The intent returned by the next poll. Write to this from the test, then wait a
## physics frame; `poll()` copies it out, so the test can clear it immediately.
var scripted: InputIntent = InputIntent.new()

## Number of times `poll()` has been called, so a test can prove input was read.
var poll_count: int = 0


func _read_input(intent: InputIntent, _host: Node2D) -> void:
	poll_count += 1
	intent.copy_from(scripted)
