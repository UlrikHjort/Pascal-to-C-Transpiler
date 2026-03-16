{ Starfield - 3D scrolling starfield through hyperspace }
program starfield;

const
  NSTARS = 150;
  W      = 80;
  H      = 24;
  MAXZ   = 64;

var
  sx, sy : array[1..NSTARS] of integer;   { 3D position (-320..320) }
  sz     : array[1..NSTARS] of integer;   { depth 1..MAXZ }
  px, py : array[1..NSTARS] of integer;   { last screen pos }
  i, s   : integer;
  screenx, screeny : integer;
  ch : char;
  spd : integer;

procedure initStar(s2 : integer);
begin
  sx[s2] := random(640) - 320;
  sy[s2] := random(480) - 240;
  sz[s2] := random(MAXZ) + 1;
  px[s2] := -1;
  py[s2] := -1;
end;

procedure eraseStar(s2 : integer);
begin
  if (px[s2] >= 1) and (px[s2] <= W) and (py[s2] >= 1) and (py[s2] <= H) then
  begin
    gotoxy(px[s2], py[s2]);
    write(' ');
  end;
end;

procedure drawStar(s2 : integer);
var bright : integer;
begin
  if (screenx >= 1) and (screenx <= W) and (screeny >= 1) and (screeny <= H) then
  begin
    bright := 15 - (sz[s2] * 14) div MAXZ;
    if bright < 8 then bright := 8;
    textcolor(bright);
    gotoxy(screenx, screeny);
    if sz[s2] < MAXZ div 4 then write('*')
    else if sz[s2] < MAXZ div 2 then write('+')
    else write('.');
    textcolor(7);
  end;
end;

begin
  randomize;

  for i := 1 to NSTARS do
    initStar(i);

  clrscr;
  hidecursor;
  rawmode;

  spd := 1;

  while not keypressed do
  begin
    delay(30);

    for s := 1 to NSTARS do
    begin
      eraseStar(s);

      sz[s] := sz[s] - spd;
      if sz[s] <= 0 then
        initStar(s)
      else
      begin
        screenx := W div 2 + (sx[s] * (MAXZ - sz[s])) div (MAXZ * 4);
        screeny := H div 2 + (sy[s] * (MAXZ - sz[s])) div (MAXZ * 6);
        px[s] := screenx;
        py[s] := screeny;
        drawStar(s);
      end;
    end;
  end;

  ch := readkey;
  normalmode;
  showcursor;
  clrscr;
end.
