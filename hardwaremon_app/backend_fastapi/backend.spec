# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path

lhm_dir = Path('third_party/LibreHardwareMonitor')
app_icon = Path('../windows/runner/resources/app_icon.ico')
lhm_datas = [
    (str(path), str(lhm_dir / path.relative_to(lhm_dir).parent))
    for path in lhm_dir.rglob('*')
    if path.is_file()
]

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=lhm_datas,
    hiddenimports=[],
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
    [],
    exclude_binaries=True,
    name='backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    icon=str(app_icon),
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    name='backend',
)
