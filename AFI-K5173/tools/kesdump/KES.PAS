


type
  TFilename = string[16];
  TKes_IOPB = record
    res1:integer;
    res2:integer;

    done_bytes_l: integer;
    done_bytes_h: integer;
    devicecode: integer;
    device_nr: byte;
    functioncode: byte;
    modification: integer;
    cylinder: integer;
    head: byte;
    sector: byte;
    buffer_ptr: ^byte;
    requested_bytes_l: integer;
    requested_bytes_h: integer;
    general_ptr: ^integer;
  end;
  PKes_IOPB = ^TKes_IOPB;

  TKes_CIB = record
    reserved1: byte;
    op_status: byte;
    reserved2: byte;
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
  Kes_Wakeup_port = $100;
  Kes_Maxbuffer = 4672;

var
  Kes_WUB: PKes_WUB;
  Kes_CCB: PKes_CCB;
  Kes_CIB: PKes_CIB;
  Kes_IOPB: PKes_IOPB;
  Kes_Data: array[0..Kes_Maxbuffer] of byte;

  iobp2: PKes_IOPB;

procedure kes_init;
begin
  kes_wub:=Ptr(Kes_Wakeup_port,$00);
  kes_ccb:=kes_wub^.ccb_ptr;
  kes_cib:=kes_ccb^.cib_ptr;
  kes_cib:=Ptr(seg(kes_cib^),ofs(kes_cib^)-4);
  kes_iopb:=kes_cib^.io_ptr;
end;

procedure kes_wakeup;
begin
  kes_cib^.status_semaphore:=0;
  port[Kes_Wakeup_Port]:=0;
  port[Kes_Wakeup_Port]:=1;
end;

procedure kes_load_exec_const(var data; len: integer);
type TByteArray = array[0..MaxInt] of byte;
var a: integer;
    b: TByteArray absolute data;
begin;
  for a:=0 to len-1 do
    Kes_Data[a]:=b[a];
end;

function kes_load_exec_file(filename: TFileName):integer;
var
  f: file;
  l: integer;
begin
  if filename='' then
    begin
      kes_load_exec_file:=1001;
      exit;
    end;
  {$I-}
  assign(f,filename);
  reset(f);
  if ioresult<>0 then
    begin
      kes_load_exec_file:=1002;
      exit;
    end;
  l:=filesize(f);
  if ioresult<>0 then
    begin
      kes_load_exec_file:=1002;
      close(f);
      exit;
    end;
  if l>Kes_Maxbuffer then
    begin
      kes_load_exec_file:=1003;
      close(f);
      exit;
    end;
  blockread(f,Kes_Data,(l+127) div 128);
  if ioresult<>0 then
    begin
      kes_load_exec_file:=1002;
      close(f);
      exit;
    end;
  close(f);
  {$I+}
  kes_load_exec_file:=0;
end;

procedure kes_buffer_transfer(to_kes: boolean; size: integer);
begin;
  with kes_iopb^ do
    begin
      devicecode:=0;
      device_nr:=0;
      functioncode:=$0e;
      modification:=0;
      cylinder:=$2100;
      if to_kes then head:=$ff else head:=$00;
      buffer_ptr:=addr(Kes_Data);
      requested_bytes_l:=size;
    end;
  kes_ccb^.busy:=$ff;
  kes_wakeup;
  repeat until kes_ccb^.busy=0;
  kes_cib^.status_semaphore:=0;
end;

procedure kes_exec;
begin;
  with kes_iopb^ do
    begin
      devicecode:=0;
      device_nr:=0;
      functioncode:=$0c;
      modification:=0;
      general_ptr:=Ptr(0,$2100);
    end;
  kes_ccb^.busy:=$ff;
  kes_wakeup;
  repeat until kes_ccb^.busy=0;
  kes_cib^.status_semaphore:=0;
end;

procedure kes_buffer_clear;
var
  i:integer;
begin
  for i:=0 to Kes_Maxbuffer do Kes_Data[i]:=0;
end;

procedure kes_load_run_const(var data; len: integer);
begin
  with iobp2^ do
    begin
      devicecode:=0;
      device_nr:=0;
      functioncode:=$0e;
      modification:=0;
      cylinder:=$2100;
      head:=$ff;
      buffer_ptr:=addr(data);
      requested_bytes_l:=len;
    end;
  kes_cib^.io_ptr:=iobp2;
  kes_ccb^.busy:=$ff;
  kes_wakeup;
  repeat until kes_ccb^.busy=0;
  kes_cib^.status_semaphore:=0;
  kes_cib^.io_ptr:=Kes_IOPB;
  kes_exec;
end;

