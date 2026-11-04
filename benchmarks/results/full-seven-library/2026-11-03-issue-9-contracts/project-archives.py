#!/usr/bin/env python3
"""Preserve private downloads; publish identical member payloads and non-owner attributes."""
import argparse
import copy
import gzip
import hashlib
import json
from pathlib import Path
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('--raw-dir', required=True, type=Path)
parser.add_argument('--public-dir', required=True, type=Path)
parser.add_argument('--receipt-output', required=True, type=Path)
args = parser.parse_args()
assert args.raw_dir.resolve() != args.public_dir.resolve()
args.public_dir.mkdir()
inventory = json.loads((args.raw_dir / 'server-packet-inventory.json').read_text())
assert inventory['status'] in ('PASS', 'FAIL')
OWNER = {'uid', 'gid', 'uname', 'gname'}
PAX_OWNER = OWNER | {'SCHILY.uid', 'SCHILY.gid', 'SCHILY.uname', 'SCHILY.gname'}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def non_owner(member):
    return {**{name: getattr(member, name) for name in ['name', 'type', 'linkname', 'mode', 'size', 'mtime', 'devmajor', 'devminor']}, 'pax_headers': {key: value for key, value in member.pax_headers.items() if key not in PAX_OWNER}}

records = []
for entry in inventory['archives']:
    source = args.raw_dir / entry['archive']
    assert digest(source) == entry['sha256']
    destination = args.public_dir / source.name
    with tarfile.open(source, 'r:gz') as original:
        assert not original.pax_headers
        members = original.getmembers()
        assert len(members) == entry['regularFiles']
        names = set()
        with destination.open('xb') as output:
            with gzip.GzipFile(fileobj=output, mode='wb', filename='', mtime=0) as compressed:
                with tarfile.open(fileobj=compressed, mode='w', format=tarfile.PAX_FORMAT) as published:
                    for member in members:
                        assert member.name not in names
                        names.add(member.name)
                        assert member.isfile() and not member.name.startswith('/')
                        assert '..' not in Path(member.name).parts
                        assert member.name.startswith(entry['root'] + '/')
                        relative = member.name[len(entry['root']) + 1:]
                        data = original.extractfile(member).read()
                        assert hashlib.sha256(data).hexdigest() == entry['memberPayloads'][relative]['sha256']
                        assert len(data) == entry['memberPayloads'][relative]['sizeBytes']
                        projected = copy.copy(member)
                        projected.uid = projected.gid = 0
                        projected.uname = projected.gname = ''
                        projected.pax_headers = {key: value for key, value in member.pax_headers.items() if key not in PAX_OWNER}
                        with original.extractfile(member) as stream:
                            published.addfile(projected, stream)
        with tarfile.open(destination, 'r:gz') as published:
            public_members = published.getmembers()
            assert len(public_members) == len(members)
            for before, after in zip(members, public_members):
                assert non_owner(before) == non_owner(after), before.name
                assert (after.uid, after.gid, after.uname, after.gname) == (0, 0, '', '')
                assert not (set(after.pax_headers) & PAX_OWNER)
                assert original.extractfile(before).read() == published.extractfile(after).read(), before.name
    header = destination.read_bytes()[:10]
    assert header[:3] == b'\x1f\x8b\x08' and not (header[3] & (4 | 8 | 16))
    assert header[4:8] == b'\0\0\0\0'
    assert digest(source) == entry['sha256']
    records.append({'archive': source.name, 'root': entry['root'], 'privateOriginalSha256': entry['sha256'], 'publicSha256': digest(destination), 'regularFiles': entry['regularFiles'], 'publicBytes': destination.stat().st_size, 'allPayloadsByteIdentical': True, 'allNonOwnerMemberAttributesIdentical': True, 'publicOwnerFieldsAnonymous': True, 'publicCompressionHeaderAnonymous': True})
receipt = {'status': 'PASS', 'productionMain': inventory['productionMain'], 'productionMacro': inventory['productionMacro'], 'allowedChanges': ['uid/gid set to zero; uname/gname and corresponding PAX owner fields removed', 'gzip header made anonymous; recompression changes archive bytes'], 'orderingPreserved': True, 'archivedProgramsExecuted': False, 'contentAudit': 'Separate full-payload and metadata content audit required before commit.', 'archives': records}
receipt['measurementStatus'] = inventory.get('measurementStatus', inventory['status'])
args.receipt_output.write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
