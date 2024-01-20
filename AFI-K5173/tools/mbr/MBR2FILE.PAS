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

program mbr2file;


{$I kes.pas}

var
  fname: string[16];
  ofile: file;
  buffer: array[0..511] of byte;

begin
  kes_init;
  if ParamCount<>1 then exit;
  fname:=ParamStr(1);
  with Kes_IOPB^ do
    begin
      devicecode:=0;
      device_nr:=0;
      functioncode:=4;
      modification:=1;
      cylinder:=0;
      head:=0;
      sector:=0;
      buffer_ptr:=addr(buffer);
      requested_bytes_l:=512;
      requested_bytes_h:=0;
    end;
  kes_ccb^.busy:=$ff;
  kes_wakeup;
  repeat until kes_ccb^.busy=0;
  assign(ofile,fname);
  rewrite(ofile);
  blockwrite(ofile, buffer, 4);
  close(ofile);
end.
