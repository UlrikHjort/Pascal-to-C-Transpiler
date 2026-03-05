program RepeatBreak;
var
  i: integer;
begin
  { break inside repeat }
  i := 0;
  repeat
    i := i + 1;
    if i = 3 then break
  until i >= 10;
  writeln(i);     { 3 }

  { continue inside repeat }
  i := 0;
  repeat
    i := i + 1;
    if i mod 2 = 0 then continue;
    write(i, ' ')
  until i >= 6;
  writeln         { 1 3 5 }
end.
