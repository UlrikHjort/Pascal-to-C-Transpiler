{ Bounce – single-player ASCII ball game against the right wall
  w/s or up/down arrows to move the paddle
  Ball bounces between the paddle and the right wall
  Miss the ball and you lose a life }
program bounce;

const
  W      = 60;   { play area width }
  H      = 22;   { play area height }
  PADLEN = 4;    { paddle half-length (total = 2*PADLEN+1) }
  LIVES  = 3;

var
  bx, by   : integer;   { ball position }
  bdx, bdy : integer;   { ball direction }
  py       : integer;   { paddle y centre (x is always 2) }
  score    : integer;
  lives    : integer;
  ch       : char;
  running  : boolean;
  paused   : boolean;
  i        : integer;
  col      : integer;

procedure drawBorder;
var j : integer;
begin
  textcolor(8);
  for j := 1 to W do
  begin
    gotoxy(j, 1);     write('-');
    gotoxy(j, H + 2); write('-');
  end;
  for j := 1 to H do
  begin
    gotoxy(W + 1, j + 1); write('|');
  end;
  { left side open – that is where the paddle lives }
  textcolor(7);
end;

procedure drawPaddle(col2 : integer);
var j : integer;
begin
  textcolor(col2);
  for j := py - PADLEN to py + PADLEN do
    if (j >= 1) and (j <= H) then
    begin
      gotoxy(2, j + 1);
      write('|');
    end;
  textcolor(7);
end;

procedure erasePaddle;
var j : integer;
begin
  for j := py - PADLEN - 1 to py + PADLEN + 1 do
    if (j >= 1) and (j <= H) then
    begin
      gotoxy(2, j + 1);
      write(' ');
    end;
end;

procedure drawBall(c : char);
begin
  gotoxy(bx + 1, by + 1);
  textcolor(14);
  write(c);
  textcolor(7);
end;

procedure drawStatus;
begin
  gotoxy(1, H + 3);
  textcolor(11);
  write('Score: ');
  write(score);
  write('   Lives: ');
  write(lives);
  write('   w/s=move  q=quit     ');
  textcolor(7);
end;

begin
  randomize;

  bx  := W div 2;
  by  := H div 2;
  bdx := 1;
  if random(2) = 0 then bdy := 1 else bdy := -1;
  py    := H div 2;
  score := 0;
  lives := LIVES;

  rawmode;
  hidecursor;
  clrscr;

  drawBorder;
  drawPaddle(10);
  drawBall('o');
  drawStatus;

  running := true;
  while running do
  begin
    delay(40);

    { Handle input (non-blocking) }
    if keypressed then
    begin
      ch := readkey;
      if (ch = 'q') or (ch = 'Q') then
        running := false
      else if (ch = 'w') or (ch = 'W') then
      begin
        if py - PADLEN > 1 then
        begin
          erasePaddle;
          py := py - 1;
          drawPaddle(10);
        end;
      end
      else if (ch = 's') or (ch = 'S') then
      begin
        if py + PADLEN < H then
        begin
          erasePaddle;
          py := py + 1;
          drawPaddle(10);
        end;
      end
      else if ch = chr(27) then
      begin
        { arrow key: ESC [ A=up B=down }
        if keypressed then
        begin
          ch := readkey;  { should be '[' }
          if keypressed then
          begin
            ch := readkey;
            if ch = 'A' then
            begin
              if py - PADLEN > 1 then
              begin
                erasePaddle;
                py := py - 1;
                drawPaddle(10);
              end;
            end
            else if ch = 'B' then
            begin
              if py + PADLEN < H then
              begin
                erasePaddle;
                py := py + 1;
                drawPaddle(10);
              end;
            end;
          end;
        end;
      end;
    end;

    { Move ball }
    drawBall(' ');
    bx := bx + bdx;
    by := by + bdy;

    { Bounce off top/bottom }
    if by < 1 then
    begin
      by  := 1;
      bdy := 1;
    end
    else if by > H then
    begin
      by  := H;
      bdy := -1;
    end;

    { Bounce off right wall }
    if bx >= W then
    begin
      bx  := W - 1;
      bdx := -1;
      score := score + 1;
      drawStatus;
    end;

    { Paddle collision: bx hits x=1 (paddle at x=2 drawn, ball at bx=1) }
    if bx <= 1 then
    begin
      if (by >= py - PADLEN) and (by <= py + PADLEN) then
      begin
        bx  := 2;
        bdx := 1;
        { slight angle based on where it hit paddle }
        i := by - py;
        if i < -1 then bdy := -1
        else if i > 1 then bdy := 1
        else bdy := bdy;
        score := score + 2;
        drawStatus;
      end
      else
      begin
        { missed – lose a life }
        lives := lives - 1;
        drawStatus;
        if lives = 0 then
          running := false
        else
        begin
          { flash effect }
          gotoxy(W div 2 - 4, H div 2 + 1);
          textcolor(12);
          write('  MISS!  ');
          textcolor(7);
          delay(800);
          gotoxy(W div 2 - 4, H div 2 + 1);
          write('         ');
          { reset ball }
          bx  := W div 2;
          by  := H div 2;
          bdx := 1;
          if random(2) = 0 then bdy := 1 else bdy := -1;
        end;
      end;
    end;

    drawBall('o');
  end;

  { Game over }
  normalmode;
  showcursor;
  clrscr;
  writeln;
  textcolor(14);
  writeln('  === GAME OVER ===');
  textcolor(7);
  writeln('  Final score: ', score);
  writeln;
end.
