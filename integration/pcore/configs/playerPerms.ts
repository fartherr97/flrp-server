// ==========================================================================
// pCore :: configs/playerPerms.ts — FLRP (PROPOSED)
// ==========================================================================
// Maps FLRP Discord role IDs -> pCore permission groups. Each group becomes an
// ACE principal at runtime, which FLRP's bridge maps to flrp.role.<key>
// (see docs/PCORE_INTEGRATION.md). The GROUP KEYS here are load-bearing and
// must match config/permissions.cfg + flrp_permissions/server/pcore.lua.
//
// FILL every "REPLACE_ME" with the REAL FLRP guild role id. DO NOT invent IDs.
// The label on the left of each entry is just a human tag; the value is the
// Discord role id. A player is placed in the group if they hold ANY listed role.
// ==========================================================================

export const permsConfig = {
    // ---- Staff (FLRP inheritance is applied on the FLRP side, not here) ----
    "group.ownership": {
        founder: "REPLACE_ME",
        owner: "REPLACE_ME",
    },
    "group.director": {
        director: "REPLACE_ME",
    },
    "group.administrator": {
        administrator: "REPLACE_ME",
    },
    "group.moderator": {
        moderator: "REPLACE_ME",
    },

    // ---- Base membership (the required "Community Member" verification role) ----
    "group.member": {
        member: "REPLACE_ME",
    },

    // ---- Civilian certifications ----
    "certciv1": {
        certciv1: "REPLACE_ME",
    },
    "certciv2": {
        certciv2: "REPLACE_ME",
    },
    "certciv3": {
        certciv3: "REPLACE_ME",
    },

    // ---- Departments (authoritative: BCSO / FHP / MPD only) ----
    "bcso": {
        bcso: "REPLACE_ME",
    },
    "fhp": {
        fhp: "REPLACE_ME",
    },
    "mpd": {
        mpd: "REPLACE_ME",
    },
};
