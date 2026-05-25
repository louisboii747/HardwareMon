# -*- mode: python ; coding: utf-8 -*-

block_cipher = None


a = Analysis(
    ['api.py'],
    pathex=[],

    binaries=[],

    datas=[
        ('database.py', '.'),
        ('process_scanner.py', '.'),
        ('hash_utils.py', '.'),
        ('virustotal.py', '.'),
    ],

    hiddenimports=[
        'flask',
        'flask_cors',
        'sqlite3',
        'requests',
        'urllib3',
        'database',
        'process_scanner',
        'hash_utils',
        'virustotal',
    ],

    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],

    win_no_prefer_redirects=False,
    win_private_assemblies=False,

    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(
    a.pure,
    a.zipped_data,
    cipher=block_cipher,
)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,

    [],

    name='api',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
)
