# AFIFlash
Mit AFIFlash lässt sich die Firmware des IDE-Kontrollers auf den Flash-Chip brennen.

# Benutzung
1. die AFIFLASH.CMD und die Firmware-Datei (z.B. IDE.BIN) auf eine Diskette kopieren.
2. auf dem A7100 `afiflash w ide.bin` ausführen.
Es kann notwendig sein, den Vorgang mehrmals zu wiederholen, wenn der nicht das erste mal fehlerfrei ausgeführt wird.

# Kompilierung
1. Wenn die Z80-Dateien geändert worden sind, dann muss die BUILD.BAT im Z80-Verzeichnis ausgeführt werden. Die benötigt AS80 und Turbo Pascal 7, am besten in der Dosbox. Die Build.bat Assembliert die Z80-Dateien, und fügt die Ergebnisse in die AFIFLASH.PAS ein.
2. Die AFIFLASH.PAS zusammen mit MT+86 Pascal auf eine Diskette kopieren.
3. Auf dem A7100 die Kommandos `mt+86 afiflash.pas`und `linkmt afiflash,paslib` ausführen.
