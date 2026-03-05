{ examples/factorial.pas – compute n! iteratively and recursively }
program Factorial;
var
  i, n, result : integer;
begin
  n      := 10;
  result := 1;
  for i := 1 to n do
    result := result * i;
  write('10! = ');
  writeln(result);

  { also show a while-loop version }
  n      := 7;
  result := 1;
  i      := 1;
  while i <= n do
  begin
    result := result * i;
    i      := i + 1
  end;
  write('7!  = ');
  writeln(result)
end.
