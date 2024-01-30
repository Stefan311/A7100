as80 -x identz80.z80
as80 -x readbyte.z80
as80 -x writbyte.z80
as80 -x leertest.z80
as80 -x blckread.z80
as80 -x fl_sst1.z80
as80 -x fl_sst2.z80
as80 -x fl_sst3.z80
as80 -x fl_mv.z80
as80 -x fl_amd1.z80
as80 -x fl_amd2.z80
as80 -x fl_28f1.z80
as80 -x fl_28f2.z80
as80 -x fl_at1.z80
as80 -x fl_at2.z80
as80 -x er_at1.z80
as80 -x er_28f1.z80
as80 -x er_28f2.z80
as80 -x er_win.z80
as80 -x er_sst1.z80
as80 -x er_sst2.z80
as80 -x er_as.z80
as80 -x er_amd1.z80
as80 -x er_amd2.z80
as80 -x stop_afi.z80
tpc bin2pas
bin2pas
@del *.bin
@del *.lst
cd ..
@del afiflash.pas
@ren afifla2.pas afiflash.pas
cd z80
@del bin2pas.exe
@del tmp.txt
@del tmp2.txt
