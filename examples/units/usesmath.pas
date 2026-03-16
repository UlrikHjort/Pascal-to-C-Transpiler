program UsesMath;

uses MathUtils;

var
  r : Rect;
  area : real;

begin
  PrintBanner('MathUtils test');
  writeln(CircleArea(1.0):8:4);

  r.width  := 5.0;
  r.height := 3.0;
  area := RectArea(r);
  writeln(area:6:1);
end.
