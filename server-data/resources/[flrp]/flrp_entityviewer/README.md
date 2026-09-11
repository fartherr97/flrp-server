# Staff entity viewer

`/entityviewer` toggles the viewer for `flrp.staff.moderate` (Trial Mod,
Moderator and all higher inherited staff tiers). Point the camera at a prop,
press E to select, then DELETE twice within three seconds to delete it.
E releases the selection; BACKSPACE closes the viewer.

Deletion is server-authoritative, limited to networked objects within 30 metres
and the same routing bucket. Players and vehicles cannot be deleted. Every
request rechecks staff ACE permission, object type and selected model. Requests
are rate limited and logged. Local/map objects can be inspected, but not removed;
permanent map changes belong in the map resource. Owning scripts may recreate props.

Raycast API: https://docs.fivem.net/natives/?_0x7EE9F5D83DD4F90E
Live pointing and client visuals require in-game validation.
