program TBitOps;
var
  a, b, r : integer;
begin
  a := 12;  { 0b1100 }
  b := 10;  { 0b1010 }
  r := a xor b;
  writeln(r);       { 6 = 0b0110 }
  r := a shl 2;
  writeln(r);       { 48 }
  r := b shr 1;
  writeln(r);       { 5 }
  r := (a xor b) shl 1;
  writeln(r);       { 12 }
end.
