{ examples/fibonacci.pas – print the first N Fibonacci numbers }
program Fibonacci;
var
  n, i, a, b, tmp : integer;
begin
  n := 10;
  writeln('First 10 Fibonacci numbers:');
  a := 0;
  b := 1;
  for i := 1 to n do
  begin
    writeln(a);
    tmp := a + b;
    a   := b;
    b   := tmp
  end
end.
