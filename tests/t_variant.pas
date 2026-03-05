program TVariantRecord;
type
  Shape = record
    x, y : integer;
    case kind : integer of
      0 : (radius : real);
      1 : (width, height : real)
  end;
var
  s : Shape;
begin
  s.x := 10;
  s.y := 20;
  s.kind := 0;
  s.radius := 3.14;
  writeln(s.x);
  writeln(s.y);
  writeln(s.kind);
  s.kind := 1;
  s.width  := 5.0;
  s.height := 8.0;
  writeln(s.width);
  writeln(s.height);
end.
