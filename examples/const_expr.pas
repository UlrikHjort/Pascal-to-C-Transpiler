{ Demonstrates: const expressions and for..in range-for }
program ConstExprTest;
const
  Lo  = 1;
  Hi  = 5;
  Sum = Lo + Hi;
  Sq  = Hi * Hi;
var
  i, acc: integer;
begin
  acc := 0;
  for i in Lo..Hi do
    acc := acc + i;
  writeln(acc);       { 1+2+3+4+5 = 15 }
  writeln(Sum);       { 6 }
  writeln(Sq)         { 25 }
end.
