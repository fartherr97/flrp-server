#!/usr/bin/env python3
"""Add managed vehicle models to host vMenu configs without replacing other entries."""
import argparse
import datetime
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('vmenu', type=Path, help='Installed vMenu resource directory')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
source = repo / 'server-data/resources/[flrp]/flrp_vehicles'
catalog = json.loads((source / 'catalog.json').read_text())
blocked = json.loads((source / 'blocked-models.json').read_text())
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')

for filename, key, models in [
    ('model-whitelists.json', 'whitelistedvehicle', [v['model'] for v in catalog + blocked]),
    ('addons.json', 'vehicles', [v['model'] for v in catalog if v.get('available', True)]),
]:
    path = args.vmenu.resolve() / 'config' / filename
    original = path.read_text(encoding='utf-8-sig')
    # vMenu's shipped JSON permits whole-line comments.
    data = json.loads(re.sub(r'^\s*//.*$', '', original, flags=re.M))
    entries = data.setdefault(key, [])
    seen = {str(v).lower() for v in entries}
    added = 0
    for model in models:
        if model.lower() not in seen:
            entries.append(model)
            seen.add(model.lower())
            added += 1
    if added:
        path.with_name(path.name + '.' + stamp + '.bak').write_text(original, encoding='utf-8')
        path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    print(f'{filename}: added {added}, total {len(entries)}')
