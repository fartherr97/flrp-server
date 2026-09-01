// ==========================================================================
// pCore :: configs/queue.ts — FLRP (PROPOSED)
// ==========================================================================
// Connection queue + priorities + the "please wait" adaptive card. Priority
// keys must match pCore group keys (playerPerms.ts). Lower number = higher
// priority (served first). Rebranded for FLRP; fill REPLACE_ME links.
// ==========================================================================

export const queueConfig = {
    enabled: false,                 // enable when you actually need a queue
    default_prio: 10,               // everyone else; must be higher than any set priority
    priority: {
        "group.ownership": 1,
        "group.director": 2,
        "group.administrator": 3,
        "group.moderator": 4,
        "bcso": 5,
        "fhp": 5,
        "mpd": 5,
        "certciv3": 6,
        "certciv2": 7,
        "certciv1": 8,
        "group.member": 9,
    },
    adaptiveCard: {
        "card_title_isVisible": true,
        "card_title": "Welcome to Florida Roleplay (FLRP)!",
        "card_header": "REPLACE_ME",   // banner image URL (optional)
        "card_description": "While you wait, join our Discord, read the rules, and check the site!",
        "button1_title": "Discord",
        "button1_url": "https://discord.gg/REPLACE_ME",
        "button1_iconUrl": "https://cdn.iconscout.com/icon/free/png-512/free-discord-3770900-3147482.png?f=webp&w=256",
        "button2_title": "Rules",
        "button2_url": "REPLACE_ME",
        "button2_iconUrl": "https://cdn.iconscout.com/icon/free/png-512/free-law-23-433279.png?f=webp&w=256",
        "button3_title": "Website",
        "button3_url": "REPLACE_ME",
        "button3_iconUrl": "https://cdn.iconscout.com/icon/free/png-512/free-website-3352014-2791479.png?f=webp&w=256",
    },
    "settings": {
        "debug": false,
        "noDiscordRejectMsg": "We could not find your Discord ID — make sure Discord is running and linked to FiveM, then reconnect.",
        "graceListTime": 5,
        "maxPlayers": 64,           // keep in sync with sv_maxclients (config/server.cfg)
    }
};
