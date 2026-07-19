# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

lhm_dir = Path('third_party/LibreHardwareMonitor')
lhm_datas = [
    (str(path), str(lhm_dir / path.relative_to(lhm_dir).parent))
    for path in lhm_dir.rglob('*')
    if path.is_file()
]
plugin_dir = Path('official_plugins')
plugin_datas = [
    (str(path), str(plugin_dir / path.relative_to(plugin_dir).parent))
    for path in plugin_dir.rglob('*')
    if path.is_file()
]

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=lhm_datas + plugin_datas,
    hiddenimports=['http.server', 'queue'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
)
