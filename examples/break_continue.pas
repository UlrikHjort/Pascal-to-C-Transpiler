program BreakContinue;

var
  i, sum: integer;

begin
  { sum even numbers 2..10 using continue }
  sum := 0;
  for i := 1 to 10 do begin
    if (i mod 2) <> 0 then continue;
    sum := sum + i;
  end;
  writeln(sum);

  { find first i*i > 50 using break }
  i := 1;
  while i <= 100 do begin
    if i * i > 50 then break;
    i := i + 1;
  end;
  writeln(i);
end.
