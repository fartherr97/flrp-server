// ==========================================================================
// pCore :: configs/vehiclePerms.ts — FLRP (PROPOSED)
// ==========================================================================
// Group -> allowed vehicle spawn names (for vMenu / spawn permissions).
// Inheritance is enabled (see Inheritances). Group keys must match
// playerPerms.ts.
//
// Spawn names below are the REAL names extracted from the flrp-vehicles repo:
//   BCSO: hcso1a..hcso1h   (repurposed HCSO pack — models still spawn as `hcso*`)
//   FHP : hp1a..hp1l, hp2a..hp2p
//   MPD : none imported yet
// Civilian groups have no imported vehicles yet (empty). Fill as packs arrive.
// ==========================================================================

export const Groups = {
    // ---- Departments ----
    "bcso": [
        "hcso1a", "hcso1b", "hcso1c", "hcso1d",
        "hcso1e", "hcso1f", "hcso1g", "hcso1h",
    ],
    "fhp": [
        "hp1a", "hp1b", "hp1c", "hp1d", "hp1e", "hp1f",
        "hp1g", "hp1h", "hp1i", "hp1j", "hp1k", "hp1l",
        "hp2a", "hp2b", "hp2c", "hp2d", "hp2e", "hp2f", "hp2g", "hp2h",
        "hp2i", "hp2j", "hp2k", "hp2l", "hp2m", "hp2n", "hp2o", "hp2p",
    ],
    "mpd": [
        // No MPD vehicles imported yet — add spawn names when the pack lands.
    ],

    // ---- Civilian certifications (no imported civ vehicles yet) ----
    "certciv1": [],
    "certciv2": [],
    "certciv3": [],

    // ---- Base membership ----
    "group.member": [],

    // ---- Staff (get everything via Inheritances below) ----
    "group.moderator": [],
    "group.administrator": [],
    "group.director": [],
    "group.ownership": [],
};

// Inheritance: a group also gets the vehicles of the groups it inherits.
// Define inherited groups BEFORE the group that pulls from them.
export const Inheritances = {
    "certciv2": ["certciv1"],
    "certciv3": ["certciv2"],
    // Management can spawn every department + top civilian tier.
    "group.director": ["bcso", "fhp", "mpd", "certciv3"],
    "group.ownership": ["group.director"],
};

// Emergency/department vehicles that should NEVER spawn in AI/background traffic.
export const VehiclesBlockedForAI = [
    // BCSO
    "hcso1a", "hcso1b", "hcso1c", "hcso1d", "hcso1e", "hcso1f", "hcso1g", "hcso1h",
    // FHP
    "hp1a", "hp1b", "hp1c", "hp1d", "hp1e", "hp1f", "hp1g", "hp1h", "hp1i", "hp1j", "hp1k", "hp1l",
    "hp2a", "hp2b", "hp2c", "hp2d", "hp2e", "hp2f", "hp2g", "hp2h",
    "hp2i", "hp2j", "hp2k", "hp2l", "hp2m", "hp2n", "hp2o", "hp2p",
];
