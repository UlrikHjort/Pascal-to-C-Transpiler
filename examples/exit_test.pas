program ExitTest;

function FindFirst(limit: integer): integer;
var i: integer;
begin
  FindFirst := -1;
  for i := 1 to limit do
    if i * i > 20 then begin
      FindFirst := i;
      exit
    end
end;

procedure PrintPositive(n: integer);
begin
  if n < 0 then exit;
  writeln(n)
end;

begin
  writeln(FindFirst(10));
  PrintPositive(5);
  PrintPositive(-3);
  writeln('done')
end.
