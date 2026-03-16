unit MathUtils;

interface

const
  Pi = 3.14159265;

type
  Rect = record
    width : real;
    height : real;
  end;

function CircleArea(radius: real): real;
function RectArea(r: Rect): real;
procedure PrintBanner(msg: string);

implementation

function CircleArea(radius: real): real;
begin
  CircleArea := Pi * radius * radius;
end;

function RectArea(r: Rect): real;
begin
  RectArea := r.width * r.height;
end;

procedure PrintBanner(msg: string);
begin
  writeln('*** ', msg, ' ***');
end;

end.
