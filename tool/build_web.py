#!/usr/bin/env python3
"""Builds the web app for startupnames.loudvector.com.

Runs `flutter build web --wasm`, then fills in build/web/sw.js with the build's
id and the files the service worker keeps on the device. Deploy afterwards with
`npx wrangler deploy` from the repo root.

Flutter: $FLUTTER, else `flutter` on the PATH, else ~/development/flutter.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / 'build' / 'web'

# Not kept up front: the JavaScript version (only browsers without WebAssembly
# GC fetch it, and the worker keeps it for them then), CanvasKit's local copy
# (37 MB; the app loads its renderer from Google), the licence text (1.3 MB, only
# for the licence page), debug files, the workers themselves, and index.html,
# which is kept as "./", the address the app is opened at.
SKIP = re.compile(
    r'^(canvaskit/|main\.dart\.js$|assets/NOTICES$|flutter\.js(\.map)?$|.*\.(map|symbols)$'
    r'|flutter_service_worker\.js$|sw\.js$|version\.json$|\.last_build_id$|index\.html$)'
)


def flutter() -> str:
    return (
        os.environ.get('FLUTTER')
        or shutil.which('flutter')
        or str(Path.home() / 'development' / 'flutter' / 'bin' / 'flutter')
    )


def main() -> None:
    subprocess.run([flutter(), 'build', 'web', '--wasm', '--release', '--base-href', '/'], cwd=ROOT, check=True)

    files = sorted(
        p.relative_to(WEB).as_posix()
        for p in WEB.rglob('*')
        if p.is_file() and not SKIP.match(p.relative_to(WEB).as_posix())
    )
    revision = re.search(r'"engineRevision":"([0-9a-f]+)"', (WEB / 'flutter_bootstrap.js').read_text()).group(1)
    # Chromium browsers' renderer; others fetch skwasm_heavy, kept on first use.
    renderer = [f'https://www.gstatic.com/flutter-canvaskit/{revision}/{name}' for name in ('skwasm.js', 'skwasm.wasm')]

    # The build's id changes whenever any kept file does.
    digest = hashlib.sha256(revision.encode())
    for name in ['index.html', *files]:
        digest.update(name.encode())
        digest.update((WEB / name).read_bytes())
    build = digest.hexdigest()[:12]

    sw = WEB / 'sw.js'
    text = sw.read_text()
    text = text.replace("const BUILD = 'unstamped';", f"const BUILD = '{build}';", 1)
    text = re.sub(r'/\*FILES\*/.*?/\*END\*/', lambda _: '/*FILES*/' + json.dumps(['./', *files, *renderer]) + '/*END*/', text, count=1, flags=re.S)
    if f"'{build}'" not in text or 'skwasm.wasm' not in text:
        raise SystemExit('Could not stamp build/web/sw.js: has web/sw.js changed shape?')
    sw.write_text(text)
    size = sum((WEB / name).stat().st_size for name in files)
    print(f'sw.js: build {build}, {len(files) + 3} files kept on the device ({size / 1e6:.1f} MB from this site)')


if __name__ == '__main__':
    main()
