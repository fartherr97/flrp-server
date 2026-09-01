// ==========================================================================
// pCore :: configs/weaponPerms.ts — FLRP (PROPOSED)
// ==========================================================================
// Group -> weapons that group may spawn via vMenu. Inheritance enabled.
//
// FLRP WEAPON POLICY (authoritative):
//   Only Certified Civilian III (certciv3), Director, and Ownership may spawn
//   weapons directly through vMenu. Everyone else — regular civilians, Cert I/II,
//   BCSO, FHP, MPD, Moderator, Administrator — must BUY weapons at FLRP gun
//   stores (flrp_gunstores), which grant persistent, owned weapons.
//
// Implementation: grant weapons to `certciv3`; Director and Ownership inherit.
// No other group is granted weapons here, so vMenu will not let them spawn.
// (Department LEO loadouts, if you want them via vMenu instead of gun stores,
// can be added later as their own groups — intentionally omitted for now to
// keep the policy exactly as specified.)
//
// The weapon list below is a STARTER set and is subject to change — finalize
// with FLRP leadership. Names are canonical FiveM weapon identifiers.
// ==========================================================================

export const Groups = {
    // The ONLY vMenu-weapon-spawn tier. Director + Ownership inherit this.
    "certciv3": [
        "weapon_pistol",
        "weapon_combatpistol",
        "weapon_pistol_mk2",
        "weapon_smg",
        "weapon_carbinerifle",
        "weapon_pumpshotgun",
        // TODO: finalize the certciv3 weapon list with FLRP leadership.
    ],

    // Everyone else: NO vMenu weapon spawn (they buy at gun stores).
    "group.member": [],
    "certciv1": [],
    "certciv2": [],
    "bcso": [],
    "fhp": [],
    "mpd": [],
    "group.moderator": [],
    "group.administrator": [],

    // Ownership may spawn anything (full sandbox). Add explicit heavy weapons
    // here if you do NOT want them gated purely by inheritance.
    "group.ownership": [
        "weapon_railgun",
        "weapon_minigun",
    ],
};

// Director inherits certciv3's weapons; Ownership inherits Director's.
export const Inheritances = {
    "group.director": ["certciv3"],
    "group.ownership": ["group.director"],
};
