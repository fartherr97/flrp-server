-- Resource ownership changes only. Spawn codes, permissions and enabled flags
-- are deliberately preserved. Apply with the coordinated vehicle deployment.
UPDATE vehicles SET resource = CASE resource
  WHEN 'CivAviationPack' THEN 'CivilianFleet'
  WHEN 'CivBusinessPack' THEN 'CivilianFleet'
  WHEN 'CivCartelPack' THEN 'CivilianFleet'
  WHEN 'CivCertPack' THEN 'CivilianFleet'
  WHEN 'CivCertPlusPack' THEN 'CivilianFleet'
  WHEN 'CivCommandPack' THEN 'CivilianFleet'
  WHEN 'CivConstructionPack' THEN 'CivilianFleet'
  WHEN 'CivRegPack' THEN 'CivilianFleet'
  WHEN 'CivTrailerPack' THEN 'CivilianFleet'
  WHEN '20legacyfpiu1' THEN 'MPDLegacyFleet'
  WHEN '20legacyfpiu2' THEN 'MPDLegacyFleet'
  WHEN '20legacyfpiu3' THEN 'MPDLegacyFleet'
  WHEN '20slickfpiu1' THEN 'MPDLegacyFleet'
  WHEN '20slickfpiu2' THEN 'MPDLegacyFleet'
  WHEN '20slickfpiu3' THEN 'MPDLegacyFleet'
  WHEN '21slickppv1' THEN 'MPDLegacyFleet'
  WHEN '21slickppv2' THEN 'MPDLegacyFleet'
  WHEN 'slicktoptahoe' THEN 'MPDLegacyFleet'
  WHEN 'civilianbundle' THEN 'DonatorFleet'
  WHEN 'civilianbundle2' THEN 'DonatorFleet'
  WHEN 'civpersonaldono' THEN 'DonatorFleet'
  WHEN 'devpersonals' THEN 'DonatorFleet'
  WHEN 'diamondpersonaldono' THEN 'DonatorFleet'
  WHEN 'leodonopack' THEN 'DonatorFleet'
  WHEN 'leopersonaldono' THEN 'DonatorFleet'
  WHEN 'boats' THEN 'EmergencySupportFleet'
  WHEN 'dhsfleet' THEN 'EmergencySupportFleet'
  WHEN 'dojpack' THEN 'EmergencySupportFleet'
  WHEN 'leosupport' THEN 'EmergencySupportFleet'
  WHEN 'um-vehicles' THEN 'EmergencySupportFleet'
  WHEN 'jordanzenvo' THEN 'StaffFleet'
  WHEN 'Grizzly' THEN 'StaffFleet'
  WHEN 'NM426' THEN 'StaffFleet'
  WHEN 'Owens' THEN 'StaffFleet'
  WHEN 'stevesierra' THEN 'StaffFleet'
  WHEN 'staffaudi' THEN 'StaffFleet'
  WHEN 'StaffPack' THEN 'StaffFleet'
  WHEN 'staffRam' THEN 'StaffFleet'
  WHEN 'staffsuburban' THEN 'StaffFleet'
  ELSE resource END
WHERE resource IN ('CivAviationPack', 'CivBusinessPack', 'CivCartelPack', 'CivCertPack', 'CivCertPlusPack', 'CivCommandPack', 'CivConstructionPack', 'CivRegPack', 'CivTrailerPack', '20legacyfpiu1', '20legacyfpiu2', '20legacyfpiu3', '20slickfpiu1', '20slickfpiu2', '20slickfpiu3', '21slickppv1', '21slickppv2', 'slicktoptahoe', 'civilianbundle', 'civilianbundle2', 'civpersonaldono', 'devpersonals', 'diamondpersonaldono', 'leodonopack', 'leopersonaldono', 'boats', 'dhsfleet', 'dojpack', 'leosupport', 'um-vehicles', 'jordanzenvo', 'Grizzly', 'NM426', 'Owens', 'stevesierra', 'staffaudi', 'StaffPack', 'staffRam', 'staffsuburban');

INSERT INTO schema_migrations (version, description)
VALUES ('011', 'Consolidated vehicle resource ownership')
ON DUPLICATE KEY UPDATE version = version;
