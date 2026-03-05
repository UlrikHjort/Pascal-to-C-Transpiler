program MultiDim;

var
  m: array[1..3, 1..3] of integer;
  v: array[1..3] of integer;
  i, j, s: integer;

begin
  { Fill matrix with i*j }
  for i := 1 to 3 do
    for j := 1 to 3 do
      m[i, j] := i * j;

  { Print diagonal }
  for i := 1 to 3 do
    writeln(m[i, i]);

  { Sum of second row }
  s := 0;
  for j := 1 to 3 do
    s := s + m[2, j];
  writeln(s);
end.
