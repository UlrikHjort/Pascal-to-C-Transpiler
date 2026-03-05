program TArith;
var
  n: integer;
  r: real;
begin
  writeln(2 + 3 * 4);    { 14: precedence * before + }
  writeln(10 div 3);     { 3 }
  writeln(10 mod 3);     { 1 }
  r := 7.0 / 2.0;
  writeln(r)             { 3.5 }
end.
