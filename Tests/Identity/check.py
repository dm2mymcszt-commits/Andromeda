"""Validate shipped identity, including the extension inside the actual package."""
from pathlib import Path
import json
import plistlib
import re
import sys
import zipfile

root = Path(__file__).resolve().parents[2]
app = plistlib.loads((root / 'TrollRoute/Info.plist').read_bytes())
assert app['CFBundleIdentifier'] == 'com.dm2mymcszt.trollroute'
assert app['CFBundleDisplayName'] == app['CFBundleExecutable'] == 'TrollRoute'
assert app['CFBundleShortVersionString'] == '3.0.0'
assert int(app['CFBundleVersion']) > 4
project_versions = set(re.findall(r'CURRENT_PROJECT_VERSION = (\d+);',
    (root / 'TrollRoute.xcodeproj/project.pbxproj').read_text(encoding='utf-8')))
assert project_versions == {app['CFBundleVersion']}, (project_versions, app['CFBundleVersion'])
assert app['MinimumOSVersion'] == '15.0'
assert app['CFBundleURLTypes'][0]['CFBundleURLSchemes'] == ['trollroute']
project = (root / 'TrollRoute.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
assert 'com.dm2mymcszt.trollroute.share' in project
assert 'Bookmark Location in Geranium' not in project
assert 'Geranium/' not in project
for path in ['entitlements.plist', 'TrollRoute/TrollRoute.entitlements']:
    entitlements = plistlib.loads((root / path).read_bytes())
    assert entitlements['com.apple.security.application-groups'] == [
        'group.com.dm2mymcszt.trollroute', 'group.live.cclerc.geraniumBookmarks']
for path in ['TrollRouteShare/entitlements.plist', 'TrollRouteShare/TrollRouteShare.entitlements']:
    assert plistlib.loads((root / path).read_bytes())['com.apple.security.application-groups'] == [
        'group.com.dm2mymcszt.trollroute']
for path in (root / 'TrollRoute/Translations').glob('*.xcstrings'):
    json.loads(path.read_text(encoding='utf-8'))

if len(sys.argv) > 1:
    with zipfile.ZipFile(sys.argv[1]) as package:
        def info(path):
            return plistlib.loads(package.read(path))
        prefix = 'Payload/TrollRoute.app/'
        built = info(prefix + 'Info.plist')
        for key in ['CFBundleIdentifier', 'CFBundleDisplayName', 'CFBundleExecutable',
                    'CFBundleShortVersionString', 'CFBundleVersion']:
            assert built[key] == app[key], (key, built[key], app[key])
        extensions = [n for n in package.namelist() if n.endswith('.appex/Info.plist')]
        assert extensions == [prefix + 'PlugIns/TrollRouteShare.appex/Info.plist'], extensions
        share = info(extensions[0])
        assert share['CFBundleIdentifier'] == 'com.dm2mymcszt.trollroute.share'
        assert share['CFBundleDisplayName'] == 'TrollRoute'
        assert share['CFBundleExecutable'] == 'TrollRouteShare'
        assert share['CFBundleVersion'] == app['CFBundleVersion']
print('PASS: TrollRoute identity, shared groups and package components')

# Exact Phase5 four-key extension proposal approved by the owner at997ebc9.
share_privileges = plistlib.loads((root / 'TrollRouteShare/entitlements.plist').read_bytes())
assert share_privileges == {
    'com.apple.security.application-groups': ['group.com.dm2mymcszt.trollroute'],
    'com.apple.locationd.simulation': True,
    'platform-application': True,
    'com.apple.private.security.no-sandbox': True,
    'com.apple.private.coreservices.canmaplsdatabase': True,
}
