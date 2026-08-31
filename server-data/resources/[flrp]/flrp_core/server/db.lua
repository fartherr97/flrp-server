-- ==========================================================================
-- FLRP :: flrp_core/server/db.lua — oxmysql wrapper
-- ==========================================================================
-- Thin, synchronous-style wrapper around oxmysql so FLRP resources use one
-- consistent, PARAMETERIZED query surface. Never build SQL by string
-- concatenation with user data — always pass params. See docs/SECURITY.md.
--
-- flrp_core owns DB readiness: it does a probe query at boot and only reports
-- IsReady()==true once the schema is reachable.
-- ==========================================================================

FLRP = FLRP or {}
FLRP.DB = {}

local dbReady = false

function FLRP.DB.IsReady()
  return dbReady
end

function FLRP.DB._setReady(v)
  dbReady = v and true or false
end

-- Blocking query (await). Returns rows (array of tables).
function FLRP.DB.Query(sql, params)
  return MySQL.query.await(sql, params or {})
end

-- Blocking single-row.
function FLRP.DB.Single(sql, params)
  return MySQL.single.await(sql, params or {})
end

-- Blocking scalar.
function FLRP.DB.Scalar(sql, params)
  return MySQL.scalar.await(sql, params or {})
end

-- Blocking insert; returns insertId.
function FLRP.DB.Insert(sql, params)
  return MySQL.insert.await(sql, params or {})
end

-- Blocking update/delete; returns affectedRows.
function FLRP.DB.Update(sql, params)
  return MySQL.update.await(sql, params or {})
end

-- Transaction helper. `queries` is an array of { sql, params } run atomically.
-- Returns true on commit, false on rollback. For read-modify-write with row
-- locking (money!), prefer FLRP.DB.Transaction with SELECT ... FOR UPDATE
-- inside a single prepared transaction (see flrp_economy).
function FLRP.DB.TransactionBatch(queries)
  return MySQL.transaction.await(queries)
end

-- Run `fn(txnRunner)` inside an explicit transaction using a dedicated
-- connection so SELECT ... FOR UPDATE row locks hold for the whole unit.
-- oxmysql exposes this via MySQL.prepare within a transaction; to keep the
-- interface simple and portable we use MySQL.transaction with an ordered
-- batch for the common case and expose rawExecute for advanced use.
function FLRP.DB.Raw(sql, params)
  return MySQL.rawExecute.await(sql, params or {})
end
