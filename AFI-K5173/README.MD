# AFI-K5173 - IDE Controller für A7100
AFI ist einen Platine, mit dem IDE-Festplatten an das Datenträger-Subsystem des A7100 angeschlossen werden können.
### Welche Features unterstützt AFI-K5173?
* 1 IDE Kanal für 2 Geräte
* DMA-Fähig
* nicht Boot-fähig (der A7100 hat keinen Boot-Code für Festplatten)
* Firmware Flashrom im System beschreibbar
* Festplatte nutzbar in SCP1700

### Teile des Projekts:

[Schaltung und PCB Layout in KiCad und PDF] Der Hardware-Aufbau ist identisch mit dem IDE-Kontroller vom A7150/CM1910.

[Firmware](firmware/)

[Tools](tools/)
