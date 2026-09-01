-- ==========================================================================
-- FLRP :: flrp_economy — persistent money, pay, transactions
-- ==========================================================================
-- Lightweight persistent economy: bank balance, append-only ledger, role-based
-- hourly pay distributed in active-time intervals, and anti-AFK compensated
-- playtime. Money mutations are race-safe (guarded atomic UPDATE + idempotency
-- keys). This is NOT an ESX/QB economy — it only does money. See docs/ECONOMY.md.
-- ==========================================================================

fx_version 'cerulean'
game 'gta5'

name 'flrp_economy'
author 'Florida Roleplay (FLRP)'
description 'FLRP persistent economy: balances, transactions, role-based pay'
version '0.1.0'

dependency 'flrp_core'
-- Soft (runtime export) deps: flrp_permissions (pay role), flrp_duty (duty pay).

shared_scripts { 'shared/config.lua' }

client_scripts { 'client/activity.lua' }

server_scripts {
  -- Shared flrp_core server libs (FiveM resources have separate Lua states,
  -- so each resource loads its own copy of the DB/logging/util helpers). The
  -- oxmysql lib provides the MySQL global these wrappers call.
  '@oxmysql/lib/MySQL.lua',
  '@flrp_core/server/util.lua',
  '@flrp_core/server/db.lua',
  '@flrp_core/server/logging.lua',
  'server/payrates.lua',
  'server/wallet.lua',
  'server/activity.lua',
  'server/pay.lua',
  'server/exports.lua',
  'server/main.lua',
}

server_exports {
  'GetBalance',
  'Credit',
  'Debit',
  'AdminAdjust',
  'GetTransactions',
  'CanAfford',
  'IsActive',
  'GetActiveSeconds',
  'ReloadPayRates',
}
