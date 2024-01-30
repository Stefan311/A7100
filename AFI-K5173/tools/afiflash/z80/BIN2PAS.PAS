{
Copyright (c) 2022, Stefan Berndt

All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice, 
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, 
   this list of conditions and the following disclaimer in the documentation 
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF 
THE POSSIBILITY OF SUCH DAMAGE.
}

program bin2pas;

function NTH(data:Byte):char;
var h:char;
begin
  case data of
    0..9:h:=chr(48+data);
    else h:=chr(55+data);
  end;
  NTH:=h;
end;

function BTH(data:Byte):string;
var h:string;
begin
  h:=NTH(data shr 4)+NTH(data and $F);
  BTH:=h;
end;

var
  fi: file of byte;
  fo,fo2,fi2,fi3,fi4: text;
  b: byte;
  c: word;
  d: string;

procedure bin2inc(fn, vn: string);
begin
  assign(fi,fn);
  reset(fi);
  c:=filesize(fi);
  str(c,d);
  writeln(fo2,'  L'+vn+' = '+d+';');
  writeln(fo,'procedure D'+vn+';'+#13+#10+'begin'+#13+#10+'inline(');
  c:=0;
  while not eof(fi) do
    begin
      read(fi,b);
      write(fo,'$');
      write(fo,BTH(b));
      if not eof(fi) then
        write(fo,'/');
      inc(c);
      if (c and 15)=0 then
        writeln(fo);
    end;
  writeln(fo,');'+#13+#10+'end;'+#13+#10);
  close(fi);
end;

begin
  assign(fo,'tmp.txt');
  rewrite(fo);
  assign(fo2,'tmp2.txt');
  rewrite(fo2);
  bin2inc('identz80.bin', 'IdentZ80');
  bin2inc('readbyte.bin', 'Z80RdBt');
  bin2inc('writbyte.bin', 'Z80WrtBt');
  bin2inc('leertest.bin', 'Z80LT');
  bin2inc('blckread.bin', 'FlashBl');
  bin2inc('fl_sst1.bin', 'fl_sst1');
  bin2inc('fl_sst2.bin', 'fl_sst2');
  bin2inc('fl_sst3.bin', 'fl_sst3');
  bin2inc('fl_mv.bin', 'fl_mv');
  bin2inc('fl_amd1.bin', 'fl_amd1');
  bin2inc('fl_amd2.bin', 'fl_amd2');
  bin2inc('fl_28f1.bin', 'fl_28f1');
  bin2inc('fl_28f2.bin', 'fl_28f2');
  bin2inc('fl_at1.bin', 'fl_at1');
  bin2inc('fl_at2.bin', 'fl_at2');
  bin2inc('er_at1.bin', 'er_at1');
  bin2inc('er_28f1.bin', 'er_28f1');
  bin2inc('er_28f2.bin', 'er_28f2');
  bin2inc('er_win.bin', 'er_win');
  bin2inc('er_sst1.bin', 'er_sst1');
  bin2inc('er_sst2.bin', 'er_sst2');
  bin2inc('er_as.bin', 'er_as');
  bin2inc('er_amd1.bin', 'er_amd1');
  bin2inc('er_amd2.bin', 'er_amd2');
  bin2inc('stop_afi.bin', 'stop_afi');
  close(fo);
  close(fo2);

  assign(fi2,'..\AFIFLASH.PAS');
  reset(fi2);

  assign(fo,'..\AFIFLA2.PAS');
  rewrite(fo);

  assign(fi3,'tmp.txt');
  reset(fi3);

  assign(fi4,'tmp2.txt');
  reset(fi4);

  while (not eof(fi2)) do
    begin
      readln(fi2,d);
      if d='{ Z80 Programme Start }' then
        begin
          writeln(fo,d);
          while (not eof(fi3)) do
            begin
              readln(fi3,d);
              writeln(fo,d);
            end;
          while (d<>'{ Z80 Programme Ende }') do readln(fi2,d);
        end;
      if d='{ Z80 Konstanten Start }' then
        begin
          writeln(fo,d);
          while (not eof(fi4)) do
            begin
              readln(fi4,d);
              writeln(fo,d);
            end;
          while (d<>'{ Z80 Konstanten Ende }') do readln(fi2,d);
        end;
      writeln(fo,d);
    end;
  close(fo);
  close(fi2);
  close(fi3);
end.

  
