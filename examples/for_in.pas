program ForIn;
var
  i, sum: integer;
begin
  sum := 0;
  for i in 1..5 do
    sum := sum + i;
  writeln(sum);

  for i in 1..3 do
    writeln(i)
end.
