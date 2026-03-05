program TRandom;
var
  n: integer;
  r: real;
begin
  { Test integer range: random(1) always 0 }
  n := random(1);
  writeln(n);
  { Test real is in [0,1) by checking truncation }
  r := random;
  writeln(r >= 0.0);
  writeln(r < 1.0);
end.
