-- ==========================================================================
-- FLRP :: .luacheckrc — static analysis config for FiveM Lua
-- ==========================================================================
-- Run:  luacheck server-data/resources/[flrp]
-- This declares the FiveM/CitizenFX runtime globals and the FLRP shared
-- namespaces so luacheck only reports REAL issues. See docs/BUILD_STATUS.md
-- (Validation) for how this fits the "statically validated" claim.
-- ==========================================================================

std = 'lua54'

-- Don't fail the whole run on unused-arg style noise in event handlers.
unused_args = false
max_line_length = false

-- FiveM resources use cross-file module globals + exported global functions.
-- allow_defined lets a file define a global (e.g. an export function) without
-- a "non-standard global" warning.
allow_defined = true

-- fxmanifest.lua is a manifest DSL, not a Lua module — don't lint it.
exclude_files = { '**/fxmanifest.lua', '**/node_modules/**' }

-- FLRP shared namespaces are intentionally global (loaded across files in a
-- resource). Allow read/write.
globals = {
  'FLRP', 'FLRPP', 'FLRPA', 'FLRPE', 'FLRPD', 'FLRPW', 'FLRPG', 'FLRPV', 'FLRPI',
}

-- CitizenFX / FiveM natives + server runtime globals (read-only).
read_globals = {
  -- core runtime
  'Citizen', 'CreateThread', 'Wait', 'SetTimeout', 'promise', 'json', 'msgpack',
  'exports', 'source', 'GetCurrentResourceName', 'GetInvokingResource',
  -- events
  'AddEventHandler', 'RegisterNetEvent', 'RemoveEventHandler', 'TriggerEvent',
  'TriggerClientEvent', 'TriggerServerEvent', 'RegisterServerEvent',
  'TriggerLatentClientEvent',
  -- commands / principals / convars
  'RegisterCommand', 'ExecuteCommand', 'GetConvar', 'GetConvarInt', 'SetConvar',
  'IsPrincipalAceAllowed', 'GetPlayerName', 'GetPlayers', 'DropPlayer',
  -- identifiers
  'GetNumPlayerIdentifiers', 'GetPlayerIdentifier', 'GetPlayerIdentifierByType',
  'GetPlayerEndpoint', 'GetPlayerPing',
  -- timing / misc
  'GetGameTimer', 'GetHashKey', 'os', 'PerformHttpRequest',
  'GetPlayerLastMsg', 'GetEntityCoords', 'GetPlayerPed',
  -- NUI / http
  'SetHttpHandler', 'PerformHttpRequestAwait',
  -- oxmysql
  'MySQL',
}

-- Export entry-point files define top-level global functions consumed by
-- FiveM's `exports` mechanism, so luacheck sees them as "unused" (131) and
-- as setting globals. Suppress those two for exports files only.
files['**/exports.lua'] = { ignore = { '131', '111' } }

-- Client scripts (if any) get the client natives; server is the default here.
files['**/client/**'] = {
  read_globals = {
    'RegisterNuiCallback', 'SendNUIMessage', 'SetNuiFocus', 'RegisterNUICallback',
    'PlayerPedId', 'GetEntityCoords', 'Vdist', 'DrawMarker', 'IsControlJustReleased',
    'RequestModel', 'HasModelLoaded', 'GiveWeaponToPed', 'RemoveAllPedWeapons',
    'PlayerId', 'GetPlayerServerId',
  },
}
