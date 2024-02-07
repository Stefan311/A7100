# Firmware-Versionen

---
[IDE:](ide/)

Firmware zum Ansteuern von IDE-Festplatten

Features:
+ Schalterstellungen: werden nicht ausgewertet
+ IDE-Adressmodus: CHS oder LBA28 (wenn die CHS-Initialisierung fehlschlägt)
+ Datentransfer mit Z80-DMA direkt in den Hostspeicher (~380KB/s)
+ SCP bootbar von Festplatte oder Flashrom durch Stack-Manipulation und Code-Injection

Booten nach folgenden Regeln:
+ 1. Wenn eine Diskette eingelegt ist, dann wird von der gebootet.
+ 2. Wenn die Festplatte erkannt wird, und ein bootbares SCP System darauf ist, dann wird das geladen und gestartet.
+ 3. Wenn weder Diskette noch Festplatte bootbar sind, dann wird eine SCP.SYS aus dem AFI-Flashrom geladen und gestartet.
