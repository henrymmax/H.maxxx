# -*- coding: utf-8 -*-
"""
Hmax V3.1.0 - Launcher em Python.

NAO altera o codigo original: o script F1_LS_3_1_0.ahk e executado exatamente
como esta (copia identica, conferida por hash), usando o interpretador
AutoHotkey v2 que acompanha o projeto. O Python so prepara a pasta de trabalho
e inicia o script, para que tudo rode como antes dentro de um unico .exe.
"""
import ctypes
import hashlib
import os
import shutil
import struct
import subprocess
import sys

SCRIPT = "F1_LS_3_1_0.ahk"
ICONES = ("Hmaxlogo.ico", "Hmaxlogo.png")
INTERP64 = "Pass64_original.exe"
INTERP32 = "Pass32.exe"

if getattr(sys, "frozen", False):
    RECURSOS = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
else:
    RECURSOS = os.path.dirname(os.path.abspath(__file__))

# Pasta persistente: o script grava banco_local.json / etag.txt em A_ScriptDir
DESTINO = os.path.join(os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Hmax")


def sha(p):
    with open(p, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def copiar_se_preciso(nome):
    origem = os.path.join(RECURSOS, nome)
    destino = os.path.join(DESTINO, nome)
    if not os.path.exists(origem):
        return None
    if not os.path.exists(destino) or sha(origem) != sha(destino):
        shutil.copy2(origem, destino)   # copia byte a byte, sem alterar
    return destino


def copiar_pasta(nome):
    """Copia uma pasta de recursos (ex.: UX) sem alterar os arquivos."""
    origem = os.path.join(RECURSOS, nome)
    if not os.path.isdir(origem):
        return
    for raiz, _, arquivos in os.walk(origem):
        rel = os.path.relpath(raiz, RECURSOS)
        os.makedirs(os.path.join(DESTINO, rel), exist_ok=True)
        for a in arquivos:
            copiar_se_preciso(os.path.join(rel, a))


def erro(msg):
    ctypes.windll.user32.MessageBoxW(0, msg, "Hmax", 0x10)
    sys.exit(1)


def main():
    os.makedirs(DESTINO, exist_ok=True)
    ahk = copiar_se_preciso(SCRIPT)
    if not ahk:
        erro("Script original (%s) nao encontrado." % SCRIPT)
    for ic in ICONES:
        copiar_se_preciso(ic)
    copiar_pasta("UX")   # arquivos do instalador/painel AutoHotkey (copiados sem alteracao)

    eh_64 = struct.calcsize("P") * 8 == 64 or os.environ.get("PROCESSOR_ARCHITEW6432")
    interp = copiar_se_preciso(INTERP64 if eh_64 else INTERP32)
    if not interp:
        erro("Interpretador AutoHotkey nao encontrado.")

    # #SingleInstance Force ja esta no script original: reabrir substitui a instancia anterior.
    proc = subprocess.Popen([interp, ahk], cwd=DESTINO)
    sys.exit(proc.wait())


if __name__ == "__main__":
    main()
