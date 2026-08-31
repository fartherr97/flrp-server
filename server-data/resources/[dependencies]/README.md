# `[dependencies]`

Third-party runtime **dependencies**, installed per-host (not committed here).

## Required

- **oxmysql** — MySQL/MariaDB adapter used by all FLRP resources.
  Install into this folder as `oxmysql/`, then ensure it first (already listed
  in `config/resources.cfg`). Set the connection string in `config/secrets.cfg`
  (`mysql_connection_string`). See [`docs/INSTALLATION.md`](../../../docs/INSTALLATION.md).

## Notes

- These resources are installed by the server operator and are typically kept
  out of version control (see `.gitignore`). Pin exact versions in
  [`docs/DEPLOYMENT.md`](../../../docs/DEPLOYMENT.md) for reproducible hosts.
- Do **not** put FLRP custom code here — that lives in `[flrp]`.
