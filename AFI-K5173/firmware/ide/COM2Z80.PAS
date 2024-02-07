{
Copyright (c) 2024, Stefan Berndt

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

program com2z80;

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
  fo: text;
  b: byte;
  c: word;

begin
  assign(fo,'inject.z80');
  rewrite(fo);
  assign(fi,'inject.com');
  reset(fi);

  writeln(fo,'INJECT86_ST:');

  for c:=0 to $EEFF do read(fi,b);

  c:=0;

  while not eof(fi) do
    begin
      if (c and 15)=0 then
        write(fo,'              db ');
      read(fi,b);
      write(fo,'$');
      write(fo,BTH(b));
      if ((c and 15)=15) or eof(fi) then
        write(fo,#13+#10)
      else
        write(fo,',');
      inc(c);
    end;

  writeln(fo,'INJECT86_EN:');
  close(fo);
  close(fi);
end.

  
