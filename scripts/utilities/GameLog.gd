class_name GameLog
extends RefCounted

## Tiny tagged logger.
##
## Why: raw print() calls turn into unfilterable noise once a project grows.
## Every message here is prefixed with a tag, so a run can be grepped for one
## subsystem. These are static helpers on purpose — logging must never require
## an instance or a node in the tree.

static func info(tag: String, message: String) -> void:
	print("[%s] %s" % [tag, message])


static func warn(tag: String, message: String) -> void:
	push_warning("[%s] %s" % [tag, message])


static func err(tag: String, message: String) -> void:
	push_error("[%s] %s" % [tag, message])
