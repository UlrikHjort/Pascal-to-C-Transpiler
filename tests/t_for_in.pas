program TForIn;
var
  i, s: integer;
begin
  s := 0;
  for i in 1..5 do
    s := s + i;
  writeln(s);
  for i in 1..10 do begin
    if i = 4 then break;
    writeln(i)
  end
end.
