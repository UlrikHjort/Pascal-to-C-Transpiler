{ Conway's Game of Life - ASCII display with ANSI colors.
  Press Ctrl-C to quit.
  Uses: gotoxy, clrscr, delay, textcolor, hidecursor, showcursor. }

program GameOfLife;

const
  COLS  = 60;
  ROWS  = 30;
  DELAY_MS = 80;

var
  grid     : array[0..ROWS+1, 0..COLS+1] of integer;
  next     : array[0..ROWS+1, 0..COLS+1] of integer;
  r, c, n  : integer;
  gen      : integer;

function Neighbors(row, col : integer) : integer;
var
  dr, dc, cnt : integer;
begin
  cnt := 0;
  for dr := -1 to 1 do
    for dc := -1 to 1 do
      if not ((dr = 0) and (dc = 0)) then
        cnt := cnt + grid[row + dr, col + dc];
  Neighbors := cnt
end;

procedure Seed;
{ R-pentomino - a small pattern that evolves for many generations }
var mid_r, mid_c : integer;
begin
  mid_r := ROWS div 2;
  mid_c := COLS div 2;
  grid[mid_r,     mid_c + 1] := 1;
  grid[mid_r,     mid_c + 2] := 1;
  grid[mid_r + 1, mid_c]     := 1;
  grid[mid_r + 1, mid_c + 1] := 1;
  grid[mid_r + 2, mid_c + 1] := 1
end;

procedure DrawGrid;
var row, col : integer;
begin
  gotoxy(1, 1);
  for row := 1 to ROWS do
  begin
    for col := 1 to COLS do
    begin
      if grid[row, col] = 1 then
      begin
        textcolor(10);  { bright green }
        write('O')
      end
      else
      begin
        textcolor(0);   { black (background) }
        write(' ')
      end
    end;
    writeln('')
  end;
  textcolor(7);
  write('Generation: ');
  writeln(gen)
end;

procedure Step;
var row, col, nb : integer;
begin
  for row := 1 to ROWS do
    for col := 1 to COLS do
    begin
      nb := Neighbors(row, col);
      if grid[row, col] = 1 then
      begin
        if (nb = 2) or (nb = 3) then
          next[row, col] := 1
        else
          next[row, col] := 0
      end
      else
      begin
        if nb = 3 then
          next[row, col] := 1
        else
          next[row, col] := 0
      end
    end;
  for row := 1 to ROWS do
    for col := 1 to COLS do
      grid[row, col] := next[row, col]
end;

begin
  { zero the grids }
  for r := 0 to ROWS + 1 do
    for c := 0 to COLS + 1 do
    begin
      grid[r, c] := 0;
      next[r, c] := 0
    end;

  Seed;
  gen := 0;
  hidecursor;
  clrscr;

  while TRUE do
  begin
    DrawGrid;
    Step;
    gen := gen + 1;
    delay(DELAY_MS)
  end;

  showcursor
end.
