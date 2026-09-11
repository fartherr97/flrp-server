#!/usr/bin/env python3
"""Append the FHP fleet to a host vMenu addons.json without replacing entries."""
import argparse, json, pathlib, shutil, datetime
parser=argparse.ArgumentParser()
parser.add_argument('addons',type=pathlib.Path)
args=parser.parse_args()
models=['b1','b2','b3','b4','b5','b6','b7','b8','b9','b10','b11','b12','b14','b15','b16','b17','b18','b19','b20','b99','brct','eodf450','eodf450bb','fhp8','fhp9','fhpk91','fhpk92']
models += ['hp1'+c for c in 'abcdefghijkl']+['hp2'+c for c in 'abcdefghijklmnop']
data=json.loads(args.addons.read_text(encoding='utf-8-sig'))
vehicles=data.setdefault('vehicles',[])
assert isinstance(vehicles,list) and all(isinstance(x,str) for x in vehicles)
known={x.lower() for x in vehicles};added=[x for x in models if x.lower() not in known]
if added:
    backup=args.addons.with_name(args.addons.name+'.fhp-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S')+'.bak')
    shutil.copy2(args.addons,backup)
    vehicles.extend(added)
    temporary=args.addons.with_name(args.addons.name+'.fhp.tmp')
    temporary.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    temporary.replace(args.addons)
print('Added',len(added),'FHP entries; existing entries preserved.')
