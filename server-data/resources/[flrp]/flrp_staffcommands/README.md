# Staff commands

Existing handlers retained: /sc and /ac (private staff/admin channels),
/clearchat, /setaop and /peacetime (nex-hud area-based commands), and
/startvote (existing vote builder, supports AOP polls).

Added under flrp.staff.moderate (moderators and higher):
- /tp <ID>: teleport yourself to that player.
- /tp <player ID> <destination ID>: move the first player to the second.
- /return <ID>: restore their last staff teleport position and routing bucket.
- /freeze <ID>: toggle freeze; repeat to unfreeze.
- /announce <message>: server-wide chat and feed announcement.
- /clearveh <seconds>: clear unoccupied non-emergency vehicles after 0–600 seconds.
- /fullclearveh <seconds>: also clear unoccupied emergency vehicles.
- /staffjail <ID> <jobs>: 1–200 cleaning jobs at Bolingbroke; server validates
  location and job duration, persists remaining jobs by license in resource KVP.
- /unstaffjail <ID>: early release to the original location and bucket.

Vehicle clears protect occupied vehicles, including passengers, and refuse
overlapping countdowns. Emergency protection includes a snapshot of 495
installed add-on models and metadata from resources with literal metadata paths.
Refresh emergency-models.json when importing new fleets with wildcard manifests.
Resource startup preserves any command name already registered by another resource.
No entityviewer command is added.

/jail now expands the selected player's actions, displays staff-job counts,
supports job sentencing/release and reports server errors. Fixed the missing
unjail NUI callback. Timed jail and job sentences cannot be assigned concurrently.
The job jail uses the existing Bolingbroke yard coordinates; gameplay testing
of markers and teleport collision is still required.
