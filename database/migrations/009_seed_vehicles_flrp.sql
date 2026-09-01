-- ==========================================================================
-- FLRP :: 009_seed_vehicles_flrp.sql — real imported vehicles (first import)
-- ==========================================================================
-- Populates the `vehicles` registry from the flrp-vehicles content repo
-- (docs/ASSET_INVENTORY.md). These are the REAL spawn names extracted from the
-- packs' vehicles.meta, not guesses:
--   BCSO: hcso1a..hcso1h   (repurposed HCSO pack; models spawn as `hcso*`)
--   FHP : hp1a..hp1l, hp2a..hp2p
--   MPD : none imported yet
--
-- NOTE ON ENFORCEMENT: with FLRP built on top of pCore, vMenu vehicle spawning
-- is governed by pCore's configs/vehiclePerms.ts. This registry is the FLRP
-- DB/Manager catalog (source of truth for the website + optional flrp_vehicles
-- enforcement). Keep the two vehicle lists in sync when the fleet changes.
-- Idempotent (ON DUPLICATE KEY UPDATE on unique spawn_name).
-- ==========================================================================

INSERT INTO `vehicles`
  (`spawn_name`,`display_name`,`resource`,`department`,`category`,`required_permission`,`enabled`,`notes`)
VALUES
  ('hcso1a', 'BCSO Unit (hcso1a)', 'HCSO21-24PPVSUVs', 'BCSO', 'Patrol', 'vehicle.bcso.patrol', 1, 'Imported BCSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1b', 'BCSO Unit (hcso1b)', 'HCSO21-24PPVSUVs', 'BCSO', 'Patrol', 'vehicle.bcso.patrol', 1, 'Imported BCSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1c', 'BCSO Unit (hcso1c)', 'HCSO21-24PPVSUVs', 'BCSO', 'Patrol', 'vehicle.bcso.patrol', 1, 'Imported BCSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1d', 'BCSO Unit (hcso1d)', 'HCSO21-24PPVSUVs', 'BCSO', 'Patrol', 'vehicle.bcso.patrol', 1, 'Imported BCSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1e', 'BCSO Unit (hcso1e)', 'HCSO21-24PPVSUVs', 'BCSO', 'Patrol', 'vehicle.bcso.patrol', 1, 'Imported BCSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1f', 'BCSO Unit (hcso1f)', 'HCSO21-24PPVSUVs', 'BCSO', 'Patrol', 'vehicle.bcso.patrol', 1, 'Imported BCSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1g', 'BCSO Unit (hcso1g)', 'HCSO21-24PPVSUVs', 'BCSO', 'Patrol', 'vehicle.bcso.patrol', 1, 'Imported BCSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hcso1h', 'BCSO Unit (hcso1h)', 'HCSO21-24PPVSUVs', 'BCSO', 'Patrol', 'vehicle.bcso.patrol', 1, 'Imported BCSO PPV SUV livery; spawn name retains hcso prefix'),
  ('hp1a', 'FHP Charger (hp1a)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1b', 'FHP Charger (hp1b)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1c', 'FHP Charger (hp1c)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1d', 'FHP Charger (hp1d)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1e', 'FHP Charger (hp1e)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1f', 'FHP Charger (hp1f)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1g', 'FHP Charger (hp1g)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1h', 'FHP Charger (hp1h)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1i', 'FHP Charger (hp1i)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1j', 'FHP Charger (hp1j)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1k', 'FHP Charger (hp1k)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp1l', 'FHP Charger (hp1l)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Charger livery'),
  ('hp2a', 'FHP Pursuit SUV (hp2a)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2b', 'FHP Pursuit SUV (hp2b)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2c', 'FHP Pursuit SUV (hp2c)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2d', 'FHP Pursuit SUV (hp2d)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2e', 'FHP Pursuit SUV (hp2e)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2f', 'FHP Pursuit SUV (hp2f)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2g', 'FHP Pursuit SUV (hp2g)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2h', 'FHP Pursuit SUV (hp2h)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2i', 'FHP Pursuit SUV (hp2i)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2j', 'FHP Pursuit SUV (hp2j)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2k', 'FHP Pursuit SUV (hp2k)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2l', 'FHP Pursuit SUV (hp2l)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2m', 'FHP Pursuit SUV (hp2m)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2n', 'FHP Pursuit SUV (hp2n)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2o', 'FHP Pursuit SUV (hp2o)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery'),
  ('hp2p', 'FHP Pursuit SUV (hp2p)', NULL, 'FHP', 'Patrol', 'vehicle.fhp.patrol', 1, 'Imported FHP Badger Pursuit SUV livery')
ON DUPLICATE KEY UPDATE `display_name`=VALUES(`display_name`),
  `resource`=VALUES(`resource`), `department`=VALUES(`department`),
  `category`=VALUES(`category`), `required_permission`=VALUES(`required_permission`),
  `enabled`=VALUES(`enabled`), `notes`=VALUES(`notes`);

INSERT INTO `schema_migrations` (`version`, `description`)
VALUES ('009', 'seed real imported BCSO/FHP vehicles')
ON DUPLICATE KEY UPDATE `version` = `version`;
