# Firmware-Versionen

---
[Einfach IDE:](ide/)

Firmware zum Ansteuern von IDE-Festplatten ohne Schnickschnack

Features:
+ Schalterstellungen: werden nicht ausgewertet
+ IDE-Adressmodus: CHS oder LBA28 (wenn die CHS-Initialisierung fehlschlägt)
+ Datentransfer mit Z80-DMA direkt in den Hostspeicher (~380KB/s)
+ Nicht bootfähig
