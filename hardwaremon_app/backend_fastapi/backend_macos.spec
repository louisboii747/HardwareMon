# -*- mode: python ; coding: utf-8 -*-

"""PyInstaller definition for the self-contained macOS telemetry helper.

The Windows spec intentionally bundles LibreHardwareMonitor. Those PE binaries
are not runtime dependencies on macOS and must not be placed inside a signed
Mac application bundle.
"""

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[],
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
    upx=False,
    console=False,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    name='backend',
)

app = BUNDLE(
    coll,
    name='HardwareMonBackend.app',
    icon=None,
    bundle_identifier='com.hardwaremon.HardwareMon.backend',
    info_plist={
        'CFBundleDisplayName': 'HardwareMon Telemetry',
        'LSBackgroundOnly': True,
        'NSHighResolutionCapable': True,
    },
)
