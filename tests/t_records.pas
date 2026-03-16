program TRecords;
type
  Point = record
    x, y: integer
  end;
var
  p: Point;
begin
  p.x := 10;
  p.y := 20;
  writeln(p.x);
  writeln(p.y);
  with p do begin
    x := 30;
    y := 40
  end;
  writeln(p.x);
  writeln(p.y)
end.
