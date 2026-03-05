{ examples/with_test.pas – with statement }
program WithTest;

type
  Point = record
    x, y : real
  end;

var
  p : Point;
  dist : real;

begin
  with p do
  begin
    x := 3.0;
    y := 4.0
  end;

  write('x = '); writeln(p.x);
  write('y = '); writeln(p.y);

  dist := sqrt(p.x * p.x + p.y * p.y);
  write('distance from origin = ');
  writeln(dist)
end.
