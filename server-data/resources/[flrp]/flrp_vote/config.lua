-- ==========================================================================
-- FLRP :: flrp_vote/config.lua — in-game votes (AOP votes, polls, anything)
-- ==========================================================================
-- Staff run `/startvote` to build a poll (question + options + timer). It drops
-- a full-screen ballot on EVERY player that blocks their screen until they vote
-- (or the timer runs out). When the timer ends, the result is shown to all.
-- ==========================================================================

FLRP_VOTE = {}

FLRP_VOTE.StartAce      = 'flrp.staff.moderate'  -- who may start/cancel a vote (mods and up)
FLRP_VOTE.Command       = 'startvote'
FLRP_VOTE.CancelCommand = 'cancelvote'
FLRP_VOTE.MaxOptions    = 8
FLRP_VOTE.MinSeconds    = 10
FLRP_VOTE.MaxSeconds    = 600
FLRP_VOTE.DefaultSeconds = 60
FLRP_VOTE.ResultSeconds = 10                     -- how long the result screen shows
