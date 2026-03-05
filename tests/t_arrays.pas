program TArrays;
var
  a: array[1..3] of integer;
  m: array[1..2, 1..2] of integer;
begin
  a[1] := 10;
  a[2] := 20;
  a[3] := 30;
  writeln(a[1]);
  writeln(a[2]);
  writeln(a[3]);
  m[1, 1] := 1;
  m[1, 2] := 2;
  m[2, 1] := 3;
  m[2, 2] := 4;
  writeln(m[1, 1]);
  writeln(m[2, 2])
end.
