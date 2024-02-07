a86 inject.a86 +P0
com2z80
as80 -x ide.z80
crctool ide.bin -p $ffff -s 0 -e $07fe -w $07fe
crctool ide.bin -p $ffff -s $0800 -e $0ffe -w $0ffe
adscpsys
del inject.sym
del inject.com
del inject.z80
del ide.lst
