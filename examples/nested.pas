program nested;

function Square(x: integer): integer;
begin
  Square := x * x;
end;

function SumSquares(a, b: integer): integer;
  function Add(x, y: integer): integer;
  begin
    Add := x + y;
  end;
begin
  SumSquares := Add(Square(a), Square(b));
end;

procedure PrintResult(lbl: string; value: integer);
  procedure Indent;
  begin
    write('  ');
  end;
begin
  Indent;
  writeln(lbl);
  Indent;
  writeln(value);
end;

begin
  PrintResult('3^2 + 4^2 =', SumSquares(3, 4));
  PrintResult('1^2 + 2^2 =', SumSquares(1, 2));
end.
