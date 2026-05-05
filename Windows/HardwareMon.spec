# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_all
import os

BASE_DIR = os.path.dirname(__file__)

datas = []
binaries = []
hiddenimports = ['customtkinter', 'psutil', 'GPUtil', 'PIL']

tmp_ret = collect_all('customtkinter')
datas += tmp_ret[0]
binaries += tmp_ret[1]
hiddenimports += tmp_ret[2]

a = Analysis(
    [os.path.join(BASE_DIR, 'hardwaremon_win.py')],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
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
    name='HardwareMon',
    icon=os.path.join(BASE_DIR, 'board.ico'),
    console=False,
)