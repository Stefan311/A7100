# File2MBR und MBR2File
Diese Programme lassen sich nutzen, um die Partitionstabelle der Festplatte auf dem A7100 zu bearbeiten.
File2MBR schreibt den Inhalt einer Datei in den Master-Boot-Sektor der ersten angeschlossenen Festplatte.
MBRsFile liest den Master-Boot-Sektor der ersten Festplatte und schreibt den Inhalt in eine Datei.

# ACHTUNG!
Das Programm File2MBR überschreibt ohne Vorwarnung die Partitionstabelle!

# Benutzung
Z.B. `mbr2file backup.mbr`
oder `file2mbr scp32m.mbr`

# Kompilierung
1. Turbo-Pascal 3, MBR2FILE.PAS, FILE2MBR.PAS, und KES.PAS auf eine Diskette kopieren.
2. Auf dem A7100 `turbo` ausführen
3. `y` (Fehlermelde-Datei laden)
4. `m` und `mbr2file.pas` (Dateiname Hauptdatei angeben)
5. `o` dann `c` dann `q` (Kompiler-Ziel auf CMD-Datei stellen)
6. `c` Kompilierung durchführen.
7. `m` und `file2mbr.pas` (Dateiname Hauptdatei angeben)
8. `c` Kompilierung durchführen.

# Vorgegebene MBR-Dateien
`SCP32M.MBR` Enthält die Partitionstabelle für eine 32MB SCP-Partition, und die Festplattenkonfiguration 1024 Zylinder, 16 Köpfe, 17 Sektoren/Spur. Die Partition wird in SCP1700 als Laufwerk F: erkannt.
`MUTOS32M.MBR` Enthält die Partitionstabelle für eine 32MB Mutos-Partition, und die Festplattenkonfiguration 1024 Zylinder, 16 Köpfe, 17 Sektoren/Spur. Mutos habe ich bisher auf dem A7100 noch nicht getestet.
