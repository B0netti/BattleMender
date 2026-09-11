"""Validate or upload the already-built BattleMender release to CurseForge."""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

API = 'https://wow.curseforge.com/api'
PROJECT_ID = 1546739


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def api(path, token, data=None, content_type='application/json'):
    request = urllib.request.Request(API + path, data=data, headers={
        'X-Api-Token': token, 'Content-Type': content_type,
        'User-Agent': 'BattleMender-GitHub-Actions',
    })
    try:
        with urllib.request.build_opener(NoRedirect).open(request, timeout=120) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        # Never print response bodies or request headers containing credentials.
        sys.exit(f'CurseForge returned HTTP {error.code}. Check the token and project access.')
    except (urllib.error.URLError, TimeoutError):
        sys.exit('CurseForge request failed. Check the project files before retrying an upload.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('preflight', 'upload'))
    parser.add_argument('--version', required=True)
    parser.add_argument('--directory', type=Path, default=Path('release-output'))
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', args.version):
        sys.exit('Invalid version')
    token = os.environ.get('CF_API_TOKEN', '').strip()
    if not token:
        sys.exit('CF_API_TOKEN is not configured.')
    directory = args.directory
    metadata_path = directory / 'curseforge-metadata.json'
    if args.mode == 'preflight':
        toc = Path('BattleMender.toc').read_text(encoding='utf-8-sig')
        interface = int(re.search(r'^## Interface: (\d+)', toc, re.M).group(1))
        game_version = f'{interface // 10000}.{interface // 100 % 100}.{interface % 100}'
        versions = api('/game/wow/versions', token)
        matches = [v['id'] for v in versions if v.get('name') == game_version and v.get('gameVersionTypeID') == 517]
        if len(matches) != 1:
            sys.exit(f'No unique Retail version match for {game_version}; upload stopped.')
        metadata = {
            'displayName': f'BattleMender {args.version}',
            'gameVersions': matches,
            'releaseType': 'release',
            'changelog': (directory / 'release-notes.md').read_text(encoding='utf-8'),
            'changelogType': 'markdown',
            'isMarkedForManualRelease': False,
        }
        metadata_path.write_text(json.dumps(metadata), encoding='utf-8')
        print(f'CurseForge token accepted; Retail {game_version} resolved to {matches[0]}.')
        return
    archive = directory / f'BattleMender-v{args.version}.zip'
    metadata = metadata_path.read_bytes()
    if json.loads(metadata)['displayName'] != f'BattleMender {args.version}':
        sys.exit('Release metadata mismatch')
    boundary = 'BattleMender' + uuid.uuid4().hex
    payload = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n'.encode()
        + metadata
        + f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\nContent-Type: application/zip\r\n\r\n'.encode()
        + archive.read_bytes()
        + f'\r\n--{boundary}--\r\n'.encode()
    )
    result = api(f'/projects/{PROJECT_ID}/upload-file', token, payload, f'multipart/form-data; boundary={boundary}')
    file_id = result.get('id')
    if not isinstance(file_id, int) or file_id <= 0:
        sys.exit('Upload response missing file ID. Check CurseForge before retrying.')
    public_result = {'id': file_id, 'url': f'https://www.curseforge.com/wow/addons/battle-mender/files/{file_id}'}
    (directory / 'curseforge-result.json').write_text(json.dumps(public_result), encoding='utf-8')
    print(f'CurseForge accepted file {file_id}: {public_result["url"]}')
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a', encoding='utf-8') as file:
            file.write(f'CurseForge upload accepted: [{file_id}]({public_result["url"]}). Publication is subject to CurseForge processing/review.\n')


if __name__ == '__main__':
    main()
