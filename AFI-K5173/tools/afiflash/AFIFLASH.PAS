program afiflash;   

const UnknownMfg =   0; { unbekannter Hersteller }
      UnknownDev =   0; { unbekannter Bausteintyp }
      AMD        = $01;
      AS         = $52; { Alliance Semiconductor }
      Atmel      = $1F;
      CSI        = $31; { Catalyst Semiconductor Inc. }
      Hyundai    = $AD;
      Intel      = $89;
      MV         = $40; { Mosel-Vitelic }
      MX         = $C2; { Macronix International Co. Ltd. }
      SST        = $BF; { Silicon Storage Technology }
      STM        = $20; { SGS-Thomson Microelectronics}
	  Winbond    = $DA;
	  Mitsubi    = $1C; { Mitsubishi Electronics }
      filler     = $FF; { Fuellbyte, wenn Datei kuerzer als Baustein }

type page = array[0..2047] of byte;
     PSTRG = ^string;
     PByteArr = ^page;

var filename : string;       { Dateiname zu schreibende Binaerdatei }
    lesen    : boolean;      { nur auslesen }
    mfg,dev  : byte;         { Hersteller- und Typcode }
    lockout  : boolean;      { Boot Block Lockout bei manchen Chips }
    memsize  : longint;      { Kapazitaet des Bausteins in Byte }
    typ      : string;       { Typenbezeichnung des Bausteins }
    infile   : file;         { Datei fuer's Einlesen... }
    outfile  : file;         { ...und fuer's Ausgeben }
    puffer   : page;         { und Puffer fuer BIOS-Inhalt }
	adr      : longint;      { fortlaufende Zieladresse im Flash }
	info     : integer;
    ok,                      { solange alles gutgeht... }
    protected,               { Boot Block ist geschuetzt }
    verify   : boolean;
    dummy    : byte;
    i        : integer;
    d        : char;
    stdout   : text;

    boot,para1,para2,main : longint; { bausteinspezifische Variablen }

    s: string;
    pst : PSTRG;

type
  PInteger = ^integer;
  TKes_IOPB = record
    res1: integer;
    res2: integer;
    done_bt_l: integer;
    done_bt_h: integer;
    dev_code: integer;
    dev_nr: byte;
    func_code: byte;
    modification: integer;
    cylinder: integer;
    head: byte;
    sector: byte;
    buffer_ptr: ^byte;
    req_bt_l: integer;
    req_bt_h: integer;
    general_ptr: ^integer;
  end;
  PKes_IOPB = ^TKes_IOPB;

  TKes_CIB = record
    res1: byte;
    op_status: byte;
    res2: byte;
    status_semaphore: byte;
    csa_ptr: ^integer;
    io_ptr: PKes_IOPB;
  end;
  PKes_CIB = ^TKes_CIB;

  TKes_CCB = record
    dummy01: byte;
    busy: byte;
    cib_ptr: PKes_CIB;
    reserved1: integer;
    cb_ptr: ^integer;
    cb: integer;
  end;
  PKes_CCB = ^TKes_CCB;

  TKes_WUB = record
    dummy01: byte;
    reserved: byte;
    ccb_ptr: PKes_CCB;
  end;
  PKes_WUB = ^TKes_WUB;

const
  Kes_Wku_port = $100;
  Kes_Maxbuffer = 4672;
{ Z80 Konstanten Start }
  LIdentZ80 = 822;
  LZ80RdBt = 19;
  LZ80WrtBt = 19;
  LZ80LT = 35;
  LFlashBl = 23;
  Lfl_sst1 = 147;
  Lfl_sst2 = 83;
  Lfl_sst3 = 103;
  Lfl_mv = 120;
  Lfl_amd1 = 88;
  Lfl_amd2 = 110;
  Lfl_28f1 = 108;
  Lfl_28f2 = 103;
  Lfl_at1 = 132;
  Lfl_at2 = 132;
  Ler_at1 = 60;
  Ler_28f1 = 90;
  Ler_28f2 = 46;
  Ler_win = 78;
  Ler_sst1 = 47;
  Ler_sst2 = 56;
  Ler_as = 46;
  Ler_amd1 = 84;
  Ler_amd2 = 22;
  Lstop_afi = 7;
{ Z80 Konstanten Ende }

var
  Kes_WUB: PKes_WUB;
  Kes_CCB: PKes_CCB;
  Kes_CIB: PKes_CIB;
  Kes_IOPB: PKes_IOPB;
  Kes_Data: array[0..Kes_Maxbuffer] of byte;

  iobp2: TKes_IOPB;

EXTERNAL FUNCTION @CMD : PSTRG;

procedure kes_init;
var a: ^longint;
begin
  a:=addr(kes_wub);
  a^:=#16777216; {0100:0000}
  kes_ccb:=kes_wub^.ccb_ptr;
  kes_cib:=kes_ccb^.cib_ptr;
  a:=addr(kes_cib);
  a^:=a^-#4;
  kes_iopb:=kes_cib^.io_ptr;
end;

procedure kes_wakeup;
begin
  kes_cib^.status_semaphore:=0;
  out[Kes_Wku_port]:=0;
  out[Kes_Wku_port]:=1;
end;

procedure kes_bu_txf(to_kes: boolean; size: integer);
begin;
  with kes_iopb^ do
    begin
      dev_code:=0;
      dev_nr:=0;
      func_code:=$0e;
      modification:=0;
      cylinder:=$2100;
      if to_kes then head:=$ff else head:=$00;
      buffer_ptr:=addr(Kes_Data);
      req_bt_l:=size;
    end;
  kes_ccb^.busy:=$ff;
  kes_wakeup;
  repeat until kes_ccb^.busy=0;
  kes_cib^.status_semaphore:=0;
end;

procedure kes_exec;
var a:^longint;
begin;
  with kes_iopb^ do
    begin
      dev_code:=0;
      dev_nr:=0;
      func_code:=$0c;
      modification:=0;
      a:=addr(general_ptr);
      a^:=#8448;{0000:2100}
    end;
  kes_ccb^.busy:=$ff;
  kes_wakeup;
  repeat until kes_ccb^.busy=0;
  kes_cib^.status_semaphore:=0;
end;

procedure kes_bu_clear;
var
  i:integer;
begin
  for i:=0 to Kes_Maxbuffer do Kes_Data[i]:=0;
end;


procedure kes_load_run_const(data: PInteger; len: integer);
var a: integer;
    b: PByteArr;
    c: ^integer;
begin
  with iobp2 do
    begin
      dev_code:=0;
      dev_nr:=0;
      func_code:=$0e;
      modification:=0;
      cylinder:=$2100;
      head:=$ff;
      buffer_ptr:=data;
      c:=addr(buffer_ptr);
      c^:=c^+8;
      req_bt_l:=len;
    end;
  kes_cib^.io_ptr:=addr(iobp2);
  kes_ccb^.busy:=$ff;
  kes_wakeup;
  repeat until kes_ccb^.busy=0;
  kes_cib^.status_semaphore:=0;
  kes_cib^.io_ptr:=Kes_IOPB;
  kes_exec;
end;


{ Z80 Programme Start }
procedure DIdentZ80;
begin
inline(
$CD/$27/$24/$06/$F0/$CD/$E7/$23/$CD/$1D/$24/$06/$90/$CD/$E7/$23/
$CD/$1D/$24/$3E/$00/$D3/$B2/$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/
$FD/$77/$05/$06/$F0/$CD/$E7/$23/$FD/$7E/$04/$FE/$01/$C8/$CD/$27/
$24/$3E/$00/$D3/$B2/$3E/$FF/$32/$00/$90/$CD/$1D/$24/$3E/$90/$32/
$00/$90/$CD/$1D/$24/$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/$FD/$77/
$05/$3E/$FF/$32/$00/$90/$FD/$7E/$04/$FE/$01/$C8/$CD/$27/$24/$06/
$00/$CD/$02/$24/$CD/$31/$24/$06/$02/$CD/$02/$24/$CD/$31/$24/$3E/
$40/$D3/$B2/$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/$FD/$77/$05/$06/
$00/$CD/$02/$24/$CD/$31/$24/$FD/$7E/$04/$FE/$52/$C8/$CD/$27/$24/
$06/$90/$CD/$02/$24/$CD/$27/$24/$3E/$00/$D3/$B2/$3A/$00/$90/$FD/
$77/$04/$3A/$01/$90/$FD/$77/$05/$3A/$02/$90/$FD/$77/$06/$3E/$1F/
$D3/$B2/$3A/$F2/$9F/$FD/$77/$07/$06/$F0/$CD/$02/$24/$CD/$27/$24/
$FD/$7E/$04/$FE/$1F/$C8/$CD/$27/$24/$3E/$00/$D3/$B2/$3E/$FF/$32/
$00/$90/$32/$00/$90/$3E/$90/$32/$00/$90/$3A/$00/$90/$FD/$77/$04/
$3A/$01/$90/$FD/$77/$05/$3E/$FF/$32/$00/$90/$32/$00/$90/$FD/$7E/
$04/$FE/$31/$C8/$FE/$89/$C8/$FE/$1C/$C8/$CD/$27/$24/$06/$F0/$CD/
$02/$24/$CD/$22/$24/$06/$90/$CD/$02/$24/$CD/$22/$24/$3E/$40/$D3/
$B2/$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/$FD/$77/$05/$06/$F0/$CD/
$02/$24/$CD/$22/$24/$FD/$7E/$04/$FE/$AD/$C8/$CD/$27/$24/$06/$90/
$CD/$E7/$23/$CD/$27/$24/$3E/$00/$D3/$B2/$3A/$00/$90/$FD/$77/$04/
$3A/$01/$90/$FD/$77/$05/$FD/$7E/$04/$06/$F0/$CD/$E7/$23/$CD/$27/
$24/$FD/$7E/$04/$FE/$40/$C8/$CD/$27/$24/$3E/$00/$D3/$B2/$3E/$FF/
$32/$00/$90/$32/$00/$90/$3E/$90/$32/$00/$90/$3A/$00/$90/$FD/$77/
$04/$3E/$FF/$32/$00/$90/$32/$00/$90/$3E/$90/$32/$00/$90/$3A/$01/
$90/$FD/$77/$05/$3E/$FF/$32/$00/$90/$32/$00/$90/$FD/$7E/$04/$FE/
$C2/$C8/$CD/$27/$24/$3E/$45/$D3/$B2/$3E/$F0/$32/$55/$95/$CD/$1D/
$24/$06/$90/$CD/$02/$24/$CD/$1D/$24/$3E/$00/$D3/$B2/$3A/$00/$90/
$FD/$77/$04/$3A/$01/$90/$FD/$77/$05/$3E/$F0/$32/$55/$95/$FD/$7E/
$04/$FE/$C2/$C8/$CD/$27/$24/$06/$F0/$CD/$E7/$23/$CD/$1D/$24/$06/
$80/$CD/$E7/$23/$06/$60/$CD/$E7/$23/$CD/$1D/$24/$3E/$00/$D3/$B2/
$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/$FD/$77/$05/$06/$F0/$CD/$E7/
$23/$CD/$1D/$24/$FD/$7E/$04/$FE/$BF/$C8/$CD/$27/$24/$3E/$00/$D3/
$B2/$3E/$FF/$32/$00/$90/$CD/$1D/$24/$3E/$90/$32/$01/$90/$3A/$00/
$90/$FD/$77/$04/$3A/$01/$90/$FD/$77/$05/$3E/$FF/$32/$00/$90/$CD/
$1D/$24/$FD/$7E/$04/$FE/$BF/$C8/$CD/$27/$24/$06/$90/$CD/$E7/$23/
$CD/$27/$24/$3E/$00/$D3/$B2/$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/
$FD/$77/$05/$06/$F0/$CD/$E7/$23/$CD/$27/$24/$FD/$7E/$04/$FE/$BF/
$C8/$CD/$27/$24/$3E/$00/$D3/$B2/$3E/$90/$32/$00/$90/$CD/$1D/$24/
$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/$FD/$77/$05/$3E/$FF/$32/$00/
$90/$CD/$1D/$24/$FD/$7E/$04/$FE/$20/$C8/$CD/$27/$24/$06/$F0/$CD/
$02/$24/$CD/$1D/$24/$06/$90/$CD/$02/$24/$CD/$1D/$24/$3E/$00/$D3/
$B2/$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/$FD/$77/$05/$06/$F0/$CD/
$02/$24/$FD/$7E/$04/$FE/$20/$C8/$CD/$27/$24/$06/$F0/$CD/$E7/$23/
$CD/$1D/$24/$06/$80/$CD/$E7/$23/$06/$60/$CD/$E7/$23/$CD/$1D/$24/
$3E/$00/$D3/$B2/$3A/$00/$90/$FD/$77/$04/$3A/$01/$90/$FD/$77/$05/
$06/$F0/$CD/$E7/$23/$CD/$1D/$24/$FD/$7E/$04/$FE/$DA/$C8/$3E/$00/
$FD/$77/$04/$FD/$77/$05/$C9/$3E/$05/$D3/$B2/$3E/$AA/$32/$55/$95/
$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/$3E/$05/$D3/$B2/$78/$32/$55/
$95/$C9/$3E/$45/$D3/$B2/$3E/$AA/$32/$55/$95/$3E/$42/$D3/$B2/$3E/
$55/$32/$AA/$9A/$3E/$45/$D3/$B2/$78/$32/$55/$95/$C9/$06/$04/$10/
$FE/$C9/$06/$03/$10/$FE/$C9/$21/$00/$0B/$2D/$20/$FD/$25/$20/$FA/
$C9/$06/$4C/$10/$FE/$C9);
end;

procedure DZ80RdBt;
begin
inline(
$FD/$7E/$10/$D3/$B2/$FD/$7E/$0E/$6F/$FD/$7E/$0F/$67/$7E/$FD/$77/
$04/$37/$C9);
end;

procedure DZ80WrtBt;
begin
inline(
$FD/$7E/$16/$D3/$B2/$FD/$7E/$0E/$6F/$FD/$7E/$0F/$67/$FD/$7E/$11/
$77/$37/$C9);
end;

procedure DZ80LT;
begin
inline(
$FD/$7E/$10/$D3/$B2/$21/$00/$90/$0E/$11/$06/$00/$3E/$FF/$BE/$20/
$08/$23/$10/$FA/$79/$3D/$4F/$20/$F3/$7D/$FD/$77/$04/$7C/$FD/$77/
$05/$37/$C9);
end;

procedure DFlashBl;
begin
inline(
$FD/$7E/$10/$D3/$B2/$FD/$7E/$0E/$6F/$FD/$7E/$0F/$67/$11/$00/$22/
$01/$00/$08/$ED/$B0/$37/$C9);
end;

procedure Dfl_sst1;
begin
inline(
$3E/$00/$D3/$B3/$3E/$FF/$D3/$B3/$FD/$21/$43/$3B/$CD/$44/$0C/$D3/
$1C/$D3/$B3/$7C/$D3/$B3/$7D/$D3/$B3/$3A/$44/$3B/$D3/$B3/$3A/$45/
$3B/$D3/$B3/$FD/$2A/$44/$3B/$11/$00/$08/$3E/$03/$D3/$B3/$3E/$05/
$D3/$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/
$3E/$05/$D3/$B2/$3E/$A0/$32/$55/$95/$3A/$46/$3B/$D3/$B2/$7E/$FD/
$77/$00/$06/$00/$FD/$BE/$00/$28/$1D/$10/$F9/$3E/$04/$D3/$B3/$3E/
$00/$32/$34/$3B/$21/$00/$08/$AF/$ED/$52/$22/$32/$3B/$3E/$00/$D3/
$1C/$3E/$05/$D3/$B3/$C9/$FD/$23/$23/$7C/$B5/$20/$08/$3A/$52/$3B/
$3C/$D3/$1C/$26/$C0/$1D/$20/$A2/$15/$20/$9F/$3E/$06/$D3/$B3/$3E/
$01/$18/$CE);
end;

procedure Dfl_sst2;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$11/$00/$08/
$3A/$46/$3B/$D3/$B2/$3E/$10/$FD/$77/$00/$7E/$FD/$77/$00/$06/$00/
$FD/$BE/$00/$28/$15/$10/$F9/$3E/$00/$32/$34/$3B/$21/$00/$08/$AF/
$ED/$52/$22/$32/$3B/$3E/$00/$D3/$1C/$C9/$FD/$23/$23/$7C/$B5/$20/
$08/$3A/$52/$3B/$3C/$D3/$1C/$26/$C0/$1D/$20/$C4/$15/$20/$C1/$3E/
$01/$18/$D6);
end;

procedure Dfl_sst3;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$3E/$05/$D3/
$B2/$3E/$AA/$32/$55/$B5/$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$BA/$3E/
$05/$D3/$B2/$3E/$A0/$32/$55/$B5/$3A/$46/$3B/$D3/$B2/$06/$80/$7E/
$FD/$77/$00/$10/$21/$21/$E8/$03/$FD/$BE/$00/$28/$0A/$2D/$20/$F8/
$25/$20/$F5/$3E/$00/$18/$02/$3E/$01/$32/$34/$3B/$3E/$80/$32/$32/
$3B/$3E/$00/$D3/$1C/$C9/$FD/$23/$23/$7C/$B5/$20/$D2/$3A/$52/$3B/
$3C/$D3/$1C/$26/$C0/$18/$C8);
end;

procedure Dfl_mv;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$11/$00/$08/
$06/$A0/$CD/$5D/$21/$3A/$46/$3B/$D3/$B2/$7E/$FD/$77/$00/$06/$00/
$FD/$BE/$00/$28/$1A/$10/$F9/$06/$F0/$CD/$5D/$21/$3E/$00/$32/$34/
$3B/$21/$00/$08/$AF/$ED/$52/$22/$32/$3B/$3E/$00/$D3/$1C/$C9/$06/
$F0/$CD/$5D/$21/$FD/$23/$23/$7C/$B5/$20/$08/$3A/$52/$3B/$3C/$D3/
$1C/$26/$C0/$1D/$20/$BA/$15/$20/$B7/$3E/$01/$18/$D1/$3E/$05/$D3/
$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/$3E/
$05/$D3/$B2/$78/$32/$55/$95/$C9);
end;

procedure Dfl_amd1;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$11/$00/$08/
$3A/$46/$3B/$D3/$B2/$3E/$50/$FD/$77/$00/$7E/$FD/$77/$00/$06/$00/
$0E/$00/$FD/$BE/$00/$28/$18/$10/$F9/$0D/$20/$F6/$3E/$00/$32/$34/
$3B/$21/$00/$08/$AF/$ED/$52/$22/$32/$3B/$3E/$00/$D3/$1C/$C9/$FD/
$23/$23/$7C/$B5/$20/$08/$3A/$52/$3B/$3C/$D3/$1C/$26/$C0/$1D/$20/
$BF/$15/$20/$BC/$3E/$01/$18/$D6);
end;

procedure Dfl_amd2;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$11/$00/$08/
$3E/$05/$D3/$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/
$AA/$9A/$3E/$05/$D3/$B2/$3E/$A0/$32/$55/$95/$3A/$46/$3B/$D3/$B2/
$7E/$FD/$77/$00/$06/$00/$0E/$64/$FD/$BE/$00/$28/$18/$10/$F9/$0D/
$20/$F6/$3E/$00/$32/$34/$3B/$21/$00/$08/$AF/$ED/$52/$22/$32/$3B/
$3E/$00/$D3/$1C/$C9/$FD/$23/$23/$7C/$B5/$20/$08/$3A/$52/$3B/$3C/
$D3/$1C/$26/$C0/$1D/$20/$A9/$15/$20/$A6/$3E/$01/$18/$D6);
end;

procedure Dfl_28f1;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$11/$00/$08/
$0E/$19/$3A/$46/$3B/$D3/$B2/$3E/$40/$FD/$77/$00/$7E/$FD/$77/$00/
$06/$1E/$10/$FE/$3E/$C0/$FD/$77/$00/$06/$14/$10/$FE/$FD/$7E/$00/
$BE/$28/$19/$0D/$20/$DC/$3E/$00/$D3/$B2/$32/$00/$90/$32/$34/$3B/
$21/$00/$08/$AF/$ED/$52/$22/$32/$3B/$D3/$1C/$C9/$3E/$00/$D3/$B2/
$32/$00/$90/$FD/$23/$23/$7C/$B5/$20/$08/$3A/$52/$3B/$3C/$D3/$1C/
$26/$C0/$1D/$20/$AB/$15/$20/$A8/$3E/$01/$18/$D1);
end;

procedure Dfl_28f2;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$11/$00/$08/
$3A/$46/$3B/$D3/$B2/$3E/$40/$FD/$77/$00/$7E/$FD/$77/$00/$01/$10/
$27/$FD/$CB/$00/$7E/$20/$19/$0D/$20/$F7/$15/$20/$F4/$3E/$00/$32/
$34/$3B/$21/$00/$08/$AF/$ED/$52/$22/$32/$3B/$3E/$00/$D3/$1C/$C9/
$FD/$7E/$00/$47/$3E/$FF/$FD/$77/$00/$78/$E6/$38/$28/$E1/$FD/$23/
$23/$7C/$B5/$20/$08/$3A/$52/$3B/$3C/$D3/$1C/$26/$C0/$1D/$20/$B0/
$15/$20/$AD/$3E/$01/$18/$C8);
end;

procedure Dfl_at1;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$3E/$05/$D3/
$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/$3E/
$05/$D3/$B2/$3E/$A0/$32/$55/$95/$06/$80/$3A/$46/$3B/$D3/$B2/$7E/
$FD/$77/$00/$10/$3E/$10/$FE/$11/$00/$00/$7E/$FD/$BE/$00/$3E/$01/
$28/$08/$1D/$20/$F5/$15/$20/$F2/$3E/$00/$32/$34/$3B/$3E/$05/$D3/
$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/$3E/
$05/$D3/$B2/$3E/$F0/$32/$55/$95/$21/$80/$00/$22/$32/$3B/$3E/$00/
$D3/$1C/$C9/$FD/$23/$23/$7C/$B5/$20/$B0/$3A/$52/$3B/$3C/$D3/$1C/
$26/$C0/$18/$A6);
end;

procedure Dfl_at2;
begin
inline(
$FD/$21/$43/$3B/$CD/$44/$0C/$D3/$1C/$FD/$2A/$44/$3B/$3E/$05/$D3/
$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/$3E/
$05/$D3/$B2/$3E/$A0/$32/$55/$95/$06/$00/$3A/$46/$3B/$D3/$B2/$7E/
$FD/$77/$00/$10/$3E/$10/$FE/$11/$00/$00/$7E/$FD/$BE/$00/$3E/$01/
$28/$08/$1D/$20/$F5/$15/$20/$F2/$3E/$00/$32/$34/$3B/$3E/$05/$D3/
$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/$3E/
$05/$D3/$B2/$3E/$F0/$32/$55/$95/$21/$00/$01/$22/$32/$3B/$3E/$00/
$D3/$1C/$C9/$FD/$23/$23/$7C/$B5/$20/$B0/$3A/$52/$3B/$3C/$D3/$1C/
$26/$C0/$18/$A6);
end;

procedure Der_at1;
begin
inline(
$3E/$05/$D3/$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/
$AA/$9A/$3E/$05/$D3/$B2/$3E/$80/$32/$55/$95/$3E/$AA/$32/$55/$95/
$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/$3E/$05/$D3/$B2/$3E/$10/$32/
$55/$95/$21/$14/$00/$25/$20/$FD/$2D/$20/$FA/$C9);
end;

procedure Der_28f1;
begin
inline(
$0E/$00/$3A/$47/$3B/$D3/$B2/$21/$00/$90/$3E/$20/$77/$77/$11/$00/
$10/$1D/$20/$FD/$15/$20/$FA/$3E/$A0/$77/$06/$05/$10/$FE/$7E/$FE/
$FF/$28/$1C/$0D/$20/$E4/$22/$32/$3B/$3A/$47/$3B/$32/$34/$3B/$3E/
$00/$D3/$B2/$32/$00/$90/$3E/$FF/$32/$00/$90/$32/$00/$90/$C9/$23/
$3E/$A0/$BC/$20/$D2/$21/$00/$90/$3A/$46/$3B/$47/$3A/$47/$3B/$3C/
$32/$47/$3B/$D3/$B2/$B8/$20/$BF/$18/$CC);
end;

procedure Der_28f2;
begin
inline(
$2A/$44/$3B/$3A/$46/$3B/$D3/$B2/$3E/$FF/$77/$3E/$50/$77/$3E/$20/
$77/$3E/$D0/$77/$06/$32/$11/$00/$00/$7E/$E6/$80/$20/$08/$1D/$20/
$F8/$15/$20/$F5/$10/$F3/$7E/$32/$32/$3B/$3E/$FF/$77/$C9);
end;

procedure Der_win;
begin
inline(
$3A/$44/$3B/$FE/$0B/$28/$13/$06/$80/$CD/$33/$21/$06/$20/$CD/$33/
$21/$21/$00/$0A/$2D/$20/$FD/$25/$20/$FA/$06/$80/$CD/$33/$21/$06/
$10/$CD/$33/$21/$3E/$04/$21/$00/$00/$2D/$20/$FD/$25/$20/$FA/$3D/
$20/$F7/$C9/$3E/$05/$D3/$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/
$3E/$55/$32/$AA/$9A/$3E/$05/$D3/$B2/$78/$32/$55/$95/$C9);
end;

procedure Der_sst1;
begin
inline(
$06/$80/$CD/$14/$21/$06/$10/$CD/$14/$21/$21/$00/$64/$2D/$20/$FD/
$25/$20/$FA/$C9/$3E/$05/$D3/$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/
$B2/$3E/$55/$32/$AA/$9A/$3E/$05/$D3/$B2/$78/$32/$55/$95/$C9);
end;

procedure Der_sst2;
begin
inline(
$3E/$00/$D3/$B2/$3E/$FF/$32/$00/$90/$3E/$01/$D3/$B2/$3A/$23/$98/
$3A/$20/$98/$3A/$22/$98/$3E/$00/$D3/$B2/$3A/$18/$94/$3A/$1B/$94/
$3A/$19/$94/$3A/$1A/$94/$3E/$30/$32/$00/$90/$32/$00/$90/$21/$14/
$00/$25/$20/$FD/$2D/$20/$FA/$C9);
end;

procedure Der_as;
begin
inline(
$3E/$05/$D3/$B2/$3E/$AA/$32/$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/
$AA/$9A/$3E/$05/$D3/$B2/$3E/$80/$32/$55/$95/$3E/$00/$D3/$B2/$3E/
$FF/$32/$00/$90/$21/$14/$00/$25/$20/$FD/$2D/$20/$FA/$C9);
end;

procedure Der_amd1;
begin
inline(
$21/$0A/$00/$25/$20/$FD/$2D/$20/$FA/$06/$F0/$CD/$39/$21/$06/$04/
$10/$FE/$06/$80/$CD/$39/$21/$06/$10/$CD/$39/$21/$3E/$00/$D3/$B2/
$06/$32/$21/$00/$00/$3A/$00/$90/$E6/$80/$20/$08/$2D/$20/$F6/$25/
$20/$F3/$10/$F1/$32/$34/$3B/$06/$F0/$3E/$05/$D3/$B2/$3E/$AA/$32/
$55/$95/$3E/$02/$D3/$B2/$3E/$55/$32/$AA/$9A/$3E/$05/$D3/$B2/$78/
$32/$55/$95/$C9);
end;

procedure Der_amd2;
begin
inline(
$3E/$00/$D3/$B2/$3E/$FF/$32/$00/$90/$06/$04/$10/$FE/$3E/$30/$32/
$00/$90/$32/$00/$90/$C9);
end;

procedure Dstop_afi;
begin
inline(
$3E/$FF/$32/$4F/$3B/$37/$C9);
end;

{ Z80 Programme Ende }

{ *** Chip-Identifizierung *********************************************** }
procedure EvalAMD(d:byte);
begin
  case d of $A7 : begin memsize:=#128; typ:='Am28F010';    end;
            $A2 : begin memsize:=#128; typ:='Am28F010A';   end;
            $2A : begin memsize:=#256; typ:='Am28F020';    end;
            $29 : begin memsize:=#256; typ:='Am28F020A';   end;
            $20 : begin memsize:=#128; typ:='Am29F010';    end;
            $B0 : begin memsize:=#256; typ:='Am29F002(N)T';end;
            $34 : begin memsize:=#256; typ:='Am29F002(N)B';end;
            $A4 : begin memsize:=#512; typ:='Am29F040B';   end;
  end;
end;

procedure EvalAS(d:byte);
begin
  case d of $03,
            $04,
            $06 : begin memsize:=#128; typ:='AS29F010';    end;
  end;
end;

procedure EvalAtmel(d:byte);
begin
  case d of $5D : begin memsize:= #64; typ:='AT29C512';    end;
            $D5 : begin memsize:=#128; typ:='AT29C010A';   end;
            $DA : begin memsize:=#256; typ:='AT29C020';    end;
            $A4 : begin memsize:=#512; typ:='AT29C040A';   end;
            $05 : begin memsize:=#128; typ:='AT49F001(N)'; end;
            $04 : begin memsize:=#128; typ:='AT49F001(N)T';end;
            $07 : begin memsize:=#256; typ:='AT49F002(N)'; end;
            $08 : begin memsize:=#256; typ:='AT49F002(N)T';end;
            $17 : begin memsize:=#128; typ:='AT49F010';    end;
            $0B : begin memsize:=#256; typ:='AT49F020';    end;
            $13 : begin memsize:=#512; typ:='AT49F040';    end;
            $12 : begin memsize:=#512; typ:='AT49F040T';   end;
  end;
end;

procedure EvalCSI(d:byte);
begin
  case d of $94 : begin memsize:=#128; typ:='CAT28F001Bx-T';end;
            $95 : begin memsize:=#128; typ:='CAT28F001Bx-B';end;
            $B4 : begin memsize:=#128; typ:='CAT28F010';    end;
            $BD : begin memsize:=#256; typ:='CAT28F020';    end;
  end;
end;

procedure EvalMX(d:byte);
begin
case d of $1A : begin memsize:=#128; typ:='MX28F1000(P)';   end;
          $2A : begin memsize:=#256; typ:='MX28F2000P';     end;
          $3C : begin memsize:=#256; typ:='MX28F2000T';     end;
          $18 : begin memsize:=#128; typ:='MX29F001T';      end;
          $19 : begin memsize:=#128; typ:='MX29F001B';      end;
          $B0 : begin memsize:=#256; typ:='MX29F002(N)T';   end;
          $34 : begin memsize:=#256; typ:='MX29F002(N)B';   end;
          $A4 : begin memsize:=#512; typ:='MX29F040';       end;
  end;
end;

procedure EvalSize(m,d:byte);
begin
  memsize:=#0; typ:='Unbekannt';
  case m of AMD      : EvalAMD(d);
            AS       : EvalAS(d);
            Atmel    : EvalAtmel(d);
            CSI      : EvalCSI(d);
            Hyundai  : case d of $B0 : begin memsize:=#256; typ:='HY29F002T';    end;
                                 $34 : begin memsize:=#256; typ:='HY29F002B';    end;
                       end;
            Intel    : case d of $94 : begin memsize:=#128; typ:='i28F001Bx-T';  end;
                                 $95 : begin memsize:=#128; typ:='i28F001Bx-B';  end;
                                 $B4 : begin memsize:=#128; typ:='i28F010';      end;
                                 $BD : begin memsize:=#256; typ:='i28F020';      end;
                       end;
            MX       : EvalMX(d);
            MV       : case d of $02 : begin memsize:=#256; typ:='F/V29C51002T'; end;
                                 $A2 : begin memsize:=#256; typ:='F/V29C51002B'; end;
                       end;
            SST      : case d of $07 : begin memsize:=#128; typ:='PH29EE010';    end;
                                 $10 : begin memsize:=#256; typ:='PH29EE020';    end;
                                 $04 : begin memsize:=#512; typ:='PH28SF040';    end;
                                 $B5 : begin memsize:=#128; typ:='PH39SF010';    end;
                                 $B6 : begin memsize:=#256; typ:='PH39SF020';    end;
                                 $B7 : begin memsize:=#512; typ:='PH39SF040';    end;
                       end;
            STM      : case d of $07 : begin memsize:=#128; typ:='M28F101';      end;
                                 $A8 : begin memsize:=#32;  typ:='M28F256';      end;
                                 $AA : begin memsize:=#32;  typ:='M28F256A';     end;
                                 $02 : begin memsize:=#64;  typ:='M28F512';      end;
                                 $B0 : begin memsize:=#256; typ:='M29F002T/NT';  end;
                                 $34 : begin memsize:=#256; typ:='M29F002B';     end;
                                 $E2 : begin memsize:=#512; typ:='M29F040B';     end;
                       end;
            Winbond  : case d of $C1 : begin memsize:=#128; typ:='W29EE011/W29C010/11'; end;
                                 $45 : begin memsize:=#256; typ:='W29C020';      end;
                                 $46 : begin memsize:=#512; typ:='W29C040';      end;
                                 $0B : begin memsize:=#256; typ:='W49F002';      end;
                       end;
            Mitsubi  : case d of $D0 : begin memsize:=#128; typ:='M5M28F101';    end;
                       end;
  end;
  memsize:=memsize * #1024;
end;

procedure MfgStr(m:byte);
begin
  case m of AMD     : s:='AMD';
            AS      : s:='Alliance';
            Atmel   : s:='Atmel';
            CSI     : s:='Catalyst';
            Hyundai : s:='Hyundai';
            Intel   : s:='Intel';
            MV      : s:='Mosel-Vitelic';
            MX      : s:='Macronix';
            SST     : s:='SST';
            STM     : s:='STM';
            Winbond : s:='Winbond';
            Mitsubi : s:='Mitsubishi';
                 else s:='unbekannt';
  end;
end;

procedure Identify;
begin
  kes_load_run_const(addr(DIdentZ80),LIdentZ80);
  mfg:=lo(Kes_IOPB^.done_bt_l);
  dev:=hi(Kes_IOPB^.done_bt_l);
  info:=Kes_IOPB^.done_bt_h;
  EvalSize(mfg,dev);
end;

{ *** globale Teilprozeduren fr alle Chiptypen ************************** }

procedure WMem(a:longint;d:byte);
begin
  Kes_IOPB^.cylinder:=(short(a) & $0fff) | $9000;
  Kes_IOPB^.head:=short(a div #4096);
  Kes_IOPB^.sector:=d;
  kes_load_run_const(addr(DZ80WrtBt), LZ80WrtBt);
end;

function RMem(a:longint):byte;
begin
  Kes_IOPB^.cylinder:=(short(a) & $0fff) | $9000;
  Kes_IOPB^.head:=short(a div #4096);
  kes_load_run_const(addr(DZ80RdBt), LZ80RdBt);
  RMem:=Kes_IOPB^.done_bt_l & 255;
end;

procedure Flash_Kes(prog: PInteger; len: integer);
begin
  Kes_IOPB^.buffer_ptr:=addr(puffer[i]);
  Kes_IOPB^.req_bt_l:=(short(adr) & $0fff) | $9000;
  Kes_IOPB^.req_bt_h:=short(adr div #4096);
  kes_load_run_const(prog, len);
  ok:=Kes_IOPB^.done_bt_h=1;
  i:=i+Kes_IOPB^.done_bt_l;
  adr:=adr+long(Kes_IOPB^.done_bt_l);
end;


procedure EraseFailure(grund:string);
begin
  write('Chip Erase fehlgeschlagen');
  if length(grund)>0 then write(' ',grund);
  writeln('.');
  write('Ignorieren (J/N)?');
  readln(d);
  ok:=(d in ['j','J','y','Y']);
  writeln;
end;

procedure EraAMD1; { Am29Fxxx und kompatible }
begin
  kes_load_run_const(addr(Der_amd1), Ler_amd1);
  ok:=Kes_IOPB^.done_bt_h=$80;
end;

procedure WriteFailure(grund:string);
begin
  write('Schreiben fehlgeschlagen');
  if length(grund)>0 then write(' ',grund);
  writeln('.');
  write('Ignorieren (J/N)?');
  readln(d);
  ok:=(d in ['j','J','y','Y']);
  writeln;
end;

procedure CEr28F0x0;
begin
  Kes_IOPB^.req_bt_h:=short(memsize div #4096);
  kes_load_run_const(addr(Der_28f1), Ler_28f1);
  ok:=(Kes_IOPB^.done_bt_h & $ff)=short((memsize div #4096));
  adr:=long(Kes_IOPB^.done_bt_l & $FFF)+(long(Kes_IOPB^.done_bt_h & $ff) * #4096);
  if not ok then EraseFailure('Cycle limit exceeded');
end;

procedure Er28F001;
  procedure EraseBlock(a:longint);
  var t   : longint;
      wsm : integer;
  begin
    Kes_IOPB^.req_bt_l:=(short(a) & $0fff) | $9000;
    Kes_IOPB^.req_bt_h:=short(a div #4096);
    kes_load_run_const(addr(Der_28f2), Ler_28f2);
    ok:=(Kes_IOPB^.done_bt_l & $80)=$80;
    WSM:=Kes_IOPB^.done_bt_l & $FF;
    if ((WSM & $38)<>$0) then ok:=false;
    if not ok then begin
      write(', Fehler:');
      if (WSM &  $08)=$08 then write(' Vpp Range (WSM=',WSM,')');
      if (WSM &  $30)=$30 then write(' Command Sequence (WSM=',WSM,')');
      if (WSM &  $20)=$20 then write(' Block Erase (WSM=',WSM,')');
      if (WSM &  $38)=$0  then write(' Time-Out.');
    end;
    writeln;
    if (WSM &  $08)=$08 then writeln('Jumper JP1 = +12V?');
  end;
begin
  EraseBlock(boot);
  EraseBlock(para1);
  EraseBlock(para2);
  EraseBlock(main);
end;

procedure Zap28F0x0; { Baustein mit $00 vollschreiben }
var j: integer;
begin
  adr:=#0;
  for j:=0 to sizeof(puffer)-1 do puffer[j]:=0;
  while ok and (adr<memsize) do begin
    lwritehex(stdout,adr,3);
    i:=0;
    Flash_Kes(addr(Dfl_28f1),Lfl_28f1);
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  WMem(#0,$FF); { Reset }
  WMem(#0,$FF); { Reset }
  lwritehex(stdout,adr,3); writeln;
  if not ok then
    begin
      writeln('$00-Schreiben fehlgeschlagen (Cycle limit exceeded).');
      write('Ignorieren (J/N)?');
      readln(d);
      ok:=(d in ['j','J','y','Y']);
      writeln;
    end;
end{Zap28F0x0};

procedure Er28F0x0;
begin
  write('$00-Schreiben: $');
  Zap28F0x0;
  if ok then begin
    writeln('Chip-Erase...');
    CEr28F0x0;
  end;
end;

procedure fread;
var x: integer;
begin
  for x:=0 to 2047 do puffer[x]:=255;
  blockread(infile,puffer,x,2048,-1);
end;

procedure WrtBtAMD; { Am28Fxxx; Am29Fxxx und kompatible }
begin
  while ok and not eof(infile) do begin
    if (adr<=(memsize-long(sizeof(puffer)))) then fread;
    lwritehex(stdout,adr,3);
    i:=0;
    if dev in [$20,$B0,$34,$A4,$0B,$E2] then Flash_Kes(addr(Dfl_amd2),Lfl_amd2);
    if dev in [$A2,$29] then Flash_Kes(addr(Dfl_amd1),Lfl_amd2);
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  lwritehex(stdout,adr,3); writeln;
  if not ok then WriteFailure('(Time-Out)');
end;

procedure  Wrt2801;
var WSM : byte;
begin
  WMem(adr,$FF); { Reset }
  WMem(adr,$50); { Clear Status Register }
  while ok and not eof(infile) do begin
    if (adr<=(memsize-long(sizeof(puffer)))) then fread;
    lwritehex(stdout,adr,3);
    i:=0;
    Flash_Kes(addr(Dfl_28f2),Lfl_28f2);
    if not ok then begin
      write(', Fehler:');
      WSM:=Kes_IOPB^.done_bt_h;
      if (WSM &  $08)=$08 then write(' Vpp Range (WSM=',WSM,')');
      if (WSM &  $30)=$30 then write(' Command Sequence (WSM=',WSM,')');
      if (WSM &  $20)=$20 then write(' Block Erase (WSM=',WSM,')');
      if (WSM &  $38)=$0  then write(' Time-Out.');
      writeln;
      if (WSM &  $08)=$08 then writeln('Jumper JP1 = +12V?');
    end;
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  lwritehex(stdout,adr,3); writeln;
  if not ok then WriteFailure('(Time-Out)');
end;

procedure  Wrt28x0;
begin
  while ok and not eof(infile) do begin
    if (adr<=(memsize-long(sizeof(puffer)))) then fread;
    lwritehex(stdout,adr,3);
    i:=0;
    Flash_Kes(addr(Dfl_28f1),Lfl_28f1);
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  lwritehex(stdout,adr,3); writeln;
  if not ok then WriteFailure('(Time-Out)');
  WMem(#0,$FF); { Reset }
  WMem(#0,$FF); { Reset }
end;

{ *** Ende globale Teilprozeduren **************************************** }

procedure EraAMD;
  procedure CErase; { Am28F010A/020A }
  var t : longint;
  begin
    kes_load_run_const(addr(Der_amd2), Ler_amd2);
    t:=#100000;
    repeat
      t:=t-#1;
    until ((RMem(#0) &  $80)=$80) or  (t<#0);
    if (t<#0) then ok:=false;
  end;
begin
  if not(dev in [$A7,$2A]) then writeln('Chip-Erase...');
  if dev in [$20,$B0,$34,$A4] then EraAMD1;
  if dev in [$A7,$2A] then Er28F0x0;
  if dev in [$A2,$29] then CErase;
end;

procedure EraseAS; { !!! }
begin
  writeln('Chip-Erase...');
  kes_load_run_const(addr(Der_as), Ler_as);
end;

procedure EraseAtmel;
var t : longint;
begin
  writeln('Chip-Erase...');
  kes_load_run_const(addr(Der_at1), Ler_at1);
  t:=#100000;
  repeat
    t:=t-#1;
  until ((RMem(#0) &  $80)=$80) or (t<#0);
  if (t<#0) then ok:=false;
  if not ok then EraseFailure('Time-Out');
end;

procedure EraseCatalyst;
begin { EraseCatalyst }
  { Block-Adressen setzen }
  case dev of $94 : begin boot:=#122880; para1:=#114688; para2:=#118784; main:=#0; end;
              $95 : begin main:=#16384; para1:=#8192; para2:=#4096; boot:=#0; end;
  end;
  case dev of $94,$95 : Er28F001;
              $B4,$BD : Er28F0x0;
  end;
end;

procedure EraseHyundai;
  procedure CErase; { HY29F002T/B }
  var t : longint;
  begin
    kes_load_run_const(addr(Der_sst1), Ler_sst1);
    t:=#10000;
    repeat
      t:=t-#1;
    until ((RMem(#262144) & $80)=$80) or (t<#0);
    if (t<#0) then ok:=false;
  end;
begin { EraseHyundai }
  case dev of $B0,$34 : begin { HY29F002T/B }
                          writeln('Chip-Erase...');
                          CErase;
                        end;
  end;
end;

procedure EraseIntel;
begin { EraseIntel }
  { Block-Adressen setzen }
  case dev of $94 : begin boot:=#122880; para1:=#114688; para2:=#118784; main:=#0; end;
              $95 : begin main:=#16384; para1:=#8192; para2:=#4096; boot:=#0; end;
  end;
  case dev of $94,$95 : Er28F001;
              $B4,$BD : Er28F0x0;
  end;
end;

procedure EraseMacronix;
begin { EraseMacronix }
  case dev of $1A,$2A,$3C : Er28F0x0; { MX28F1000/2000[P|T] }
              $18,$19,$B0,$34,$A4 : begin    { MX29F001/2(N)T/B, MX29F040 }
                                      writeln('Chip-Erase...');
                                      EraAMD1;
                                    end;
  end;
end;

procedure EraseMV;
var t : longint;
begin
  writeln('Chip-Erase...');
  kes_load_run_const(addr(Der_sst1), Ler_sst1);
  t:=#10000;
  repeat
    t:=t-#1;
  until (t<#0);
end;

procedure EraseSST;
begin
  writeln('Chip-Erase...');
  if dev in [$07,$10,$B5,$B6,$B7] then kes_load_run_const(addr(Der_sst1), Ler_sst1);
  if dev in [$04] then kes_load_run_const(addr(Der_sst2), Ler_sst2);
end;

procedure EraseSTM;
begin
  case dev of $A8,$AA,$02,$07 : begin
                                  write('$00-Schreiben: $');
                                  Zap28F0x0;
                                  if ok then begin
                                    writeln('Chip-Erase...');
                                    CEr28F0x0;
                                  end;
                                end;
              $B0,$34,$E2     : begin { M29F002/040 }
                                  writeln('Chip-Erase...');
                                  EraAMD1;
                                end;
  end;
end;

procedure EraseWinbond;
begin
  writeln('Chip-Erase...');
  Kes_IOPB^.req_bt_l:=dev;
  kes_load_run_const(addr(Der_win), Ler_win);
end;

procedure EraseMitsubi;
begin
  case dev of $D0 : Er28F0x0; { M5M28F101 }
  end;
end;

procedure Loeschen;
var l: integer;
begin
  for l:=0 to 10000 do;
  case mfg of AMD      : EraAMD;
              AS       : EraseAS;
              Atmel    : EraseAtmel;
              CSI      : EraseCatalyst;
              Intel    : EraseIntel;
              MX       : EraseMacronix;
              MV       : EraseMV;
              SST      : EraseSST;
              STM      : EraseSTM;
              Winbond  : EraseWinbond;
              Mitsubi  : EraseMitsubi;
  end;
end;

procedure Leertest;
begin
  write('Leer-Test:     $000000');
  adr:=#0;
  while (adr<memsize) and ok do begin
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
    lwritehex(stdout,adr,3);
    Kes_IOPB^.head:=short(adr div #4096);
    kes_load_run_const(addr(DZ80LT), LZ80LT);
    ok:=(Kes_IOPB^.done_bt_l=$A000);    { Bis zum Ende durchgelaufen? }
    if ok then adr:=adr+#4096
          else adr:=(adr & -#4096) | long(Kes_IOPB^.done_bt_l & $0fff);
  end;
  write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  lwritehex(stdout,adr,3);
  writeln;
  if not ok then 
    writeln('Baustein ist nicht komplett geloescht, bitte nochmal versuchen.');
end;


procedure WriteAMD;
begin { WriteAMD }
  case dev of $A2,$29,$20,$B0,$34,$A4 : WrtBtAMD;
              $A7,$2A                 :  Wrt28x0;
  end;
end;

procedure WriteAS; { !!! }
begin { WriteAS }
end;


procedure WriteAtmel;
var s: integer;
begin { WriteAtmel }
  i:=sizeof(puffer); s:=sizeof(puffer);
  while ok and not eof(infile) do begin
    if (i>=s) and (adr<=(memsize-long(s))) then begin
      fread;
      i:=0;
    end;
    lwritehex(stdout,adr,3);
    case dev of $5D,$D5 : Flash_Kes(addr(Dfl_at1),Lfl_at1);   { AT29C512/C010 }
                $DA,$A4 : Flash_Kes(addr(Dfl_at2),Lfl_at2);   { AT29C20/40A }
                $05,$04,$07,$08,
                $17,$0B,$13,$12 : Flash_Kes(addr(Dfl_sst1),Lfl_sst1); { AT49F001/2, AT49F010/20/40 }
    end{case};
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  lwritehex(stdout,adr,3); writeln;
  if not ok then WriteFailure('');
end;

procedure WriteCatalyst;
begin { WriteCatalyst, same as WriteIntel, Second Source }
  case dev of $94,$95 :  Wrt2801;
              $B4,$BD :  Wrt28x0;
  end;
end;

procedure WriteHyundai;
begin { WriteHyundai }
  case dev of $B0,$34 : WrtBtAMD;
  end;
end;

procedure WriteIntel;
begin { WriteIntel }
  case dev of $94,$95 :  Wrt2801;
              $B4,$BD :  Wrt28x0;
  end;
end;

procedure WriteMacronix;
begin { WriteMacronix }
  case dev of $1A,$2A,$3C         :  Wrt28x0;
              $18,$19,$B0,$34,$A4 : WrtBtAMD;
  end;
end;

procedure WriteMV;
var s : integer;
begin { WriteMV }
  s:=sizeof(puffer); i:=s;
  while ok and not eof(infile) do begin
    if (i>=s) and (adr<=(memsize-long(s))) then begin
      fread;
      i:=0;
    end;
    lwritehex(stdout,adr,3);
    Flash_Kes(addr(Dfl_mv),Lfl_mv);
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  lwritehex(stdout,adr,3); writeln;
  if not ok then WriteFailure('');
end;

procedure WriteSST;
begin { WriteSST }
  i:=sizeof(puffer);
  while ok and not eof(infile) do begin
    if (i>=sizeof(puffer)) and (adr<=(memsize-long(sizeof(puffer)))) then begin
      fread;
      i:=0;
    end;
    lwritehex(stdout,adr,3);
    case dev of $07,$10     : Flash_Kes(addr(Dfl_sst3),Lfl_sst3); { PH29EE010/020 }
                $04         : Flash_Kes(addr(Dfl_sst2),Lfl_sst2); { PH28SF040 }
                $B5,$B6,$B7 : Flash_Kes(addr(Dfl_sst1),Lfl_sst1); { PH39SF010/20 }
    end;
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  lwritehex(stdout,adr,3); writeln;
  if not ok then WriteFailure('');
  if ok and (dev in [$04]) then begin
    dummy:=RMem(long($1823));   { Software Data Protect }
    dummy:=RMem(long($1820));
    dummy:=RMem(long($1822));
    dummy:=RMem(long($0418));
    dummy:=RMem(long($041B));
    dummy:=RMem(long($0419));
    dummy:=RMem(long($040A));
  end;
end;

procedure WriteSTM;
begin { WriteSTM }
  case dev of $A8,$AA,$02,$07 :  Wrt28x0;  { M28F256(A)/512, M28F101 }
              $B0,$34,$E2     : WrtBtAMD; { M29F002T/NT/B, M29F040 }
  end;
end;

procedure WrWinPage;
begin
  i:=sizeof(puffer);
  while ok and not eof(infile) do begin
    if (i>=sizeof(puffer)) and (adr<=(memsize-long(sizeof(puffer)))) then begin
      fread;
      i:=0;
    end;
    lwritehex(stdout,adr,3);
    case dev of $C1,$45 : Flash_Kes(addr(Dfl_at1),Lfl_at1);
                $46     : Flash_Kes(addr(Dfl_at2),Lfl_at2);
    end{case};
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  lwritehex(stdout,adr,3); writeln;
  if not ok then WriteFailure('');
end;

procedure WrWinbond;
begin
  case dev of $C1,$45,$46 : WrWinPage;
              $0B         : WrtBtAMD; { W49F002 }
  end;
end;

procedure WriteMitsubi;
begin
  case dev of $D0 :  Wrt28x0; { M5M28F101 }
  end;
end;

procedure Schreiben;
begin
  assign(infile,filename);
  reset(infile);
  adr:=#0;
  write('Programmiere:  $');
  case mfg of AMD      : WriteAMD;
              Atmel    : WriteAtmel;
              AS       : WriteAS;
              CSI      : WriteCatalyst;
              Hyundai  : WriteHyundai;
              Intel    : WriteIntel;
              MX       : WriteMacronix;
              MV       : WriteMV;
              SST      : WriteSST;
              STM      : WriteSTM;
              Winbond  : WrWinbond;
              Mitsubi  : WriteMitsubi;
  end;
  close(infile,i);
end;

procedure Pruefen;
var x: integer;
begin
  assign(infile,filename);
  reset(infile);
  verify:=true;
  adr:=#0;
  write('Verifiziere:   $');
  while (not eof(infile)) and verify do begin
    fread;
    lwritehex(stdout,adr,3);
    i:=0;
    Kes_IOPB^.cylinder:=(short(adr) & $0fff) |  $9000;
    Kes_IOPB^.head:=short(adr div #4096);
    kes_load_run_const(addr(DFlashBl), LFlashBl);
    kes_bu_txf(false, $900);
    while (i<sizeof(puffer)) and verify do begin
      verify:=(Kes_Data[i+$100]=puffer[i]);
      adr:=adr+#1; i:=i+1;
      if not verify then adr:=adr-#1;;
    end;
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  end;
  lwritehex(stdout,adr,3); writeln;
  if not verify then writeln('Verify fehlgeschlagen, bitte nochmal probieren.');
  close(infile,i);
end;

procedure Auslesen;
var x: integer;
begin
  assign(outfile,filename);
  rewrite(outfile);
  adr:=#0;
  write('Auslesen:  $');
  lwritehex(stdout,adr,3);
  while (adr<memsize) do begin
    i:=0;
    write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
    lwritehex(stdout,adr,3);
    Kes_IOPB^.cylinder:=(short(adr) & $0fff) |  $9000;
    Kes_IOPB^.head:=short(adr div #4096);
    kes_load_run_const(addr(DFlashBl), LFlashBl);
    kes_bu_txf(false, $900);
    while (i<sizeof(puffer)) do begin
      puffer[i]:=Kes_Data[i+$100];
      i:=i+1; adr:=adr+#1;
    end;
    blockwrite(outfile,puffer,x,2048,-1);
  end;
  write(chr(8),chr(8),chr(8),chr(8),chr(8),chr(8));
  lwritehex(stdout,adr,3);
  close(outfile,x);
  writeln;
  writeln('Fertig.');
end;

begin
  pst:=@CMD;
  s:=pst^;

  assign(stdout,'CON:');
  rewrite(stdout);

  writeln('AFIFLASH -- Robotron A7100 IDE-Controller Firmware Tool');
  writeln('basierend auf CTFLASH -- c''t-Flash-Schreiber, Version 1.64a, ct-ea-20021023');
  writeln('A7100-Port 2023 von Stefan Berndt');

  if (length(s)<4) or ((s[2]<>'W') and (s[2]<>'w') and (s[2]<>'R') and (s[2]<>'r')) then
    begin
      writeln('AFIFLASH schreibt eine Binaerdatei in den Firmware-Chip des AFI-Modules.');
      writeln('Aufruf: afiflash R/W FILE');
      writeln('                 R/W      - ''R'': auslesen, ''W'': schreiben');
      writeln('                     FILE - kompletter Pfad zur Binaerdatei');
      writeln('Also beispielsweise: afiflash W A:VER0108.BIN');
      writeln('Diese Version beherrscht folgende EEPROM- bzw. Flash-Chips:');
      writeln('AMD            Am28F010(A)/20(A), Am29F010/02/40(=A29040)');
      writeln('Atmel          AT29C512/010A/20(=A290021)/40A, AT49F001/02/40');
      writeln('Catalyst (CSI) CAT28F001Bx-T/B, CAT28F010/20');
      writeln('Hyundai        HY29F002T/B');
      writeln('Intel          i28F001Bx-T/B, i28F010(Z28F010)/20');
      writeln('Macronix       MX28F1000P (=H.T.M21xxx), MX28F2000P/T, MX29F002(N)T/B/040');
      writeln('Mosel-Vitelic  F/V29C51002T/B (Boot Block unprotected!)');
      writeln('SST            PH29EE010/20, PH28SF040, PH39SF010/20');
      writeln('ST Microelec.  M28F256(A)/512, M28F101, M29F002T/NT/B/040');
      writeln('Winbond        W29EE011 (=AE29F1008), W29C010/11/20(=AE29F2008)/40, W49F002');
      writeln('Mitsubishi     M5M28F101');
      exit;
    end;

  ok:=true;

  Lesen:=(s[2]<>'W') and (s[2]<>'w');
  filename:=copy(s,4,length(s)-3);

  { Init Flash-Handler Program in KES-System }
  Kes_Init;
  Kes_Bu_Clear;

  mfg:=UnknownMfg; dev:=UnknownDev;
  Identify;

  if (mfg=UnknownMfg) or (dev=UnknownDev) or (memsize=#0) then
    begin
      write('Baustein wurde nicht erkannt: Hersteller=$');
      writehex(stdout,mfg,1);
      write(', Device=$');
      writehex(stdout,dev,1);
      writeln;
      writeln('Manche Bausteine benoetigen +12V, damit die automatische Erkennung');
      writeln('funktioniert.');
      exit;
    end;

  MfgStr(mfg);

  if (mfg<>UnknownMfg) and (dev<>UnknownDev) then
      writeln('Bausteintyp ',typ,' von ',s,', Kapazitaet: ',short(memsize div #1024),' KByte');

  if (mfg=Atmel) then
    begin
      if (info & $ff) = $fe then writeln('Low Bootblock programmable.');
      if (info & $ff) = $ff then writeln('Low Bootblock locked!');
      if (info & $ff00) = $fe00 then writeln('High Bootblock programmable.');
      if (info & $ff00) = $ff00 then writeln('High Bootblock locked!');
    end;

  if ok and not Lesen and (mfg<>UnknownMfg) and (memsize>#0) then
    begin
      kes_load_run_const(addr(Dstop_afi), Lstop_afi);
      if ok then Loeschen;
      if ok then Leertest;
      if ok then Schreiben;
      if ok then Pruefen;
      if ok then writeln('Fertig.');
    end;

  if ok and (memsize>#0) and Lesen then Auslesen;
end.

