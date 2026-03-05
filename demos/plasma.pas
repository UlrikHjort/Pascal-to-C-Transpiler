{ Plasma – sine-wave colour plasma effect }
program plasma;

const
  W = 60;
  H = 22;

var
  i, j, t : integer;
  v, v2   : integer;
  ch      : char;

function isin(a : integer) : integer;
{ integer sine*100, period 360 }
var b : integer;
begin
  b := a mod 360;
  if b < 0 then b := b + 360;
  if b < 90  then isin := (b * (100 - b * b div 10000)) div 90
  else if b < 180 then isin :=  (180 - b) * (100 - (180-b) * (180-b) div 10000) div 90
  else if b < 270 then isin := -((b-180) * (100 - (b-180)*(b-180) div 10000)) div 90
  else isin := -((360-b) * (100 - (360-b)*(360-b) div 10000)) div 90;
end;

function plasmaColor(v3 : integer) : integer;
{ map -100..100 → 0..15 }
var idx : integer;
begin
  idx := (v3 + 100) * 15 div 200;
  if idx < 0  then idx := 0;
  if idx > 15 then idx := 15;
  plasmaColor := idx;
end;

function plasmaChar(v3 : integer) : char;
begin
  if v3 < -80 then plasmaChar := ' '
  else if v3 < -60 then plasmaChar := '.'
  else if v3 < -30 then plasmaChar := ':'
  else if v3 < 0   then plasmaChar := '+'
  else if v3 < 30  then plasmaChar := 'x'
  else if v3 < 60  then plasmaChar := 'X'
  else if v3 < 80  then plasmaChar := '#'
  else plasmaChar := '@';
end;

begin
  randomize;
  clrscr;
  hidecursor;
  rawmode;
  t := 0;

  while not keypressed do
  begin
    for i := 1 to H do
      for j := 1 to W do
      begin
        v := isin(j * 6 + t) + isin(i * 10 + t) +
             isin((i + j) * 5 + t * 2) + isin(i * 4 - j * 3 + t);
        v2 := v div 4;
        gotoxy(j + (80 - W) div 2, i + 1);
        textcolor(plasmaColor(v2));
        write(plasmaChar(v2));
      end;
    textcolor(7);
    t := t + 5;
    delay(30);
  end;

  ch := readkey;
  normalmode;
  showcursor;
  clrscr;
end.
