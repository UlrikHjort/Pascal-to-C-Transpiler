{ Fire - ASCII fire effect using heat diffusion }
program fire;

const
  W = 60;
  H = 22;

var
  heat  : array[0..H+1, 0..W+1] of integer;
  nheat : array[0..H+1, 0..W+1] of integer;
  i, j  : integer;
  ch    : char;

function heatChar(v : integer) : char;
begin
  if v < 20 then heatChar := ' '
  else if v < 60 then heatChar := '.'
  else if v < 100 then heatChar := ':'
  else if v < 140 then heatChar := 'x'
  else if v < 180 then heatChar := 'X'
  else if v < 220 then heatChar := '#'
  else heatChar := '@';
end;

function heatColor(v : integer) : integer;
begin
  if v < 20  then heatColor := 0
  else if v < 80  then heatColor := 4
  else if v < 150 then heatColor := 12
  else if v < 200 then heatColor := 14
  else heatColor := 15;
end;

begin
  randomize;

  for i := 0 to H+1 do
    for j := 0 to W+1 do
      heat[i, j] := 0;

  clrscr;
  hidecursor;
  rawmode;

  while not keypressed do
  begin
    { stoke the fire at the bottom }
    for j := 1 to W do
      heat[H, j] := random(255);

    { diffuse upward }
    for i := 1 to H-1 do
      for j := 1 to W do
      begin
        nheat[i, j] := (heat[i+1, j-1] + heat[i+1, j] + heat[i+1, j] +
                        heat[i+1, j+1] + heat[i, j]) div 5;
        if nheat[i, j] > 4 then
          nheat[i, j] := nheat[i, j] - 4
        else
          nheat[i, j] := 0;
      end;

    for i := 1 to H-1 do
      for j := 1 to W do
        heat[i, j] := nheat[i, j];

    { render }
    for i := 1 to H-1 do
      for j := 1 to W do
      begin
        gotoxy(j + (80 - W) div 2, i + 1);
        textcolor(heatColor(heat[i, j]));
        write(heatChar(heat[i, j]));
      end;
    textcolor(7);

    delay(40);
  end;

  ch := readkey;
  normalmode;
  showcursor;
  clrscr;
end.
