{ examples/functions.pas – functions, procedures, recursion }
program Functions;

var
  result : integer;

function Max(a, b: integer): integer;
begin
  if a > b then Max := a
  else Max := b
end;

function Factorial(n: integer): integer;
begin
  if n <= 1 then Factorial := 1
  else Factorial := n * Factorial(n - 1)
end;

procedure PrintSeparator;
begin
  writeln('----------')
end;

procedure Greet(name: string);
begin
  write('Hello, ');
  writeln(name)
end;

begin
  Greet('World');
  PrintSeparator;
  result := Max(42, 17);
  write('Max(42,17) = ');
  writeln(result);
  result := Factorial(6);
  write('6! = ');
  writeln(result);
  PrintSeparator
end.
