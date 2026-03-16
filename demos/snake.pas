program Snake;

{ Classic Snake game using ANSI terminal }
{ Controls: w/a/s/d to move, q to quit   }

const
  WIDTH  = 40;
  HEIGHT = 20;
  MAX_LEN = 800;   { WIDTH * HEIGHT }

var
  { Snake body: parallel x/y arrays, head at index 0 }
  sx : array[0..MAX_LEN] of integer;
  sy : array[0..MAX_LEN] of integer;
  slen : integer;

  { Direction: 0=right 1=down 2=left 3=up }
  dir  : integer;
  ndx  : integer;
  ndy  : integer;

  { Food position }
  fx, fy : integer;

  { Score }
  score : integer;
  gameover : boolean;

  { Temporaries }
  i, k   : integer;
  nx, ny : integer;
  ch     : char;
  ate    : boolean;

procedure draw_border;
var j : integer;
begin
  { Top row }
  gotoxy(1, 1);
  textcolor(14);
  write('+');
  for j := 1 to WIDTH do write('-');
  write('+');
  { Bottom row }
  gotoxy(1, HEIGHT + 2);
  write('+');
  for j := 1 to WIDTH do write('-');
  write('+');
  { Side bars }
  for j := 1 to HEIGHT do begin
    gotoxy(1, j + 1);
    write('|');
    gotoxy(WIDTH + 2, j + 1);
    write('|');
  end;
  textcolor(7);
end;

procedure draw_food;
begin
  gotoxy(fx + 1, fy + 1);
  textcolor(12);
  write('*');
  textcolor(7);
end;

procedure draw_snake;
begin
  { Head }
  gotoxy(sx[0] + 1, sy[0] + 1);
  textcolor(10);
  write('O');
  { Body }
  textcolor(2);
  for i := 1 to slen - 1 do begin
    gotoxy(sx[i] + 1, sy[i] + 1);
    write('o');
  end;
  textcolor(7);
end;

procedure erase_tail;
begin
  gotoxy(sx[slen] + 1, sy[slen] + 1);
  write(' ');
end;

procedure place_food;
var ok : boolean;
    tries : integer;
    tx, ty : integer;
begin
  ok := false;
  tries := 0;
  while (not ok) and (tries < 200) do begin
    tx := random(WIDTH)  + 1;
    ty := random(HEIGHT) + 1;
    ok := true;
    for k := 0 to slen - 1 do begin
      if (sx[k] = tx) and (sy[k] = ty) then ok := false;
    end;
    tries := tries + 1;
  end;
  if ok then begin
    fx := tx;
    fy := ty;
  end;
end;

begin
  randomize;
  rawmode;
  hidecursor;
  clrscr;

  { Initial snake: length 3, center, moving right }
  slen := 3;
  sx[0] := WIDTH  div 2 + 2;  sy[0] := HEIGHT div 2;
  sx[1] := WIDTH  div 2 + 1;  sy[1] := HEIGHT div 2;
  sx[2] := WIDTH  div 2;      sy[2] := HEIGHT div 2;
  dir  := 0;
  ndx  := 1;
  ndy  := 0;
  score := 0;
  gameover := false;

  place_food;
  draw_border;
  draw_food;
  draw_snake;

  { Status line }
  gotoxy(1, HEIGHT + 3);
  textcolor(11);
  write('Score: ');
  write(score);
  write('   wasd=move  q=quit');
  textcolor(7);

  while not gameover do begin
    delay(120);

    { Read key if available }
    if keypressed then begin
      ch := readkey;
      if (ch = 'q') or (ch = 'Q') then gameover := true;
      { Only allow 90-degree turns }
      if (ch = 'w') or (ch = 'W') then begin
        if dir <> 1 then begin dir := 3; ndx := 0; ndy := -1; end;
      end;
      if (ch = 's') or (ch = 'S') then begin
        if dir <> 3 then begin dir := 1; ndx := 0; ndy := 1; end;
      end;
      if (ch = 'a') or (ch = 'A') then begin
        if dir <> 0 then begin dir := 2; ndx := -1; ndy := 0; end;
      end;
      if (ch = 'd') or (ch = 'D') then begin
        if dir <> 2 then begin dir := 0; ndx := 1; ndy := 0; end;
      end;
    end;

    if not gameover then begin
      nx := sx[0] + ndx;
      ny := sy[0] + ndy;

      { Wall collision }
      if (nx < 1) or (nx > WIDTH) or (ny < 1) or (ny > HEIGHT) then
        gameover := true;

      { Self collision }
      if not gameover then begin
        for k := 0 to slen - 2 do begin
          if (sx[k] = nx) and (sy[k] = ny) then gameover := true;
        end;
      end;

      if not gameover then begin
        ate := (nx = fx) and (ny = fy);

        if not ate then
          erase_tail;

        { Shift body }
        for k := slen downto 1 do begin
          sx[k] := sx[k-1];
          sy[k] := sy[k-1];
        end;
        sx[0] := nx;
        sy[0] := ny;

        if ate then begin
          slen  := slen + 1;
          score := score + 10;
          place_food;
          draw_food;
          gotoxy(8, HEIGHT + 3);
          textcolor(11);
          write(score);
          write('   ');
          textcolor(7);
        end;

        draw_snake;
      end;
    end;
  end;

  { Game over screen }
  gotoxy(1, HEIGHT + 4);
  textcolor(12);
  write('GAME OVER!  Final score: ');
  write(score);
  writeln;
  textcolor(7);

  normalmode;
  showcursor;
end.
