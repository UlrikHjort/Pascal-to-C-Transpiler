{ Maze generator + solver using recursive backtracking (iterative DFS)
  Displays generation and solution animations with ANSI colours }
program maze;

const
  CW = 25;          { cells wide }
  CH = 14;          { cells tall }
  GW = 51;          { 2*CW+1 }
  GH = 29;          { 2*CH+1 }
  STKSZ = 360;      { CW*CH+1, enough for DFS stack }

var
  grid    : array[1..GH, 1..GW] of integer;
  stkX    : array[1..STKSZ] of integer;
  stkY    : array[1..STKSZ] of integer;
  stkTop  : integer;
  visited : array[1..CH, 1..CW] of boolean;

  { direction tables: dr/dc are cell steps, wr/wc are wall steps }
  dr : array[1..4] of integer;
  dc : array[1..4] of integer;
  wr : array[1..4] of integer;
  wc : array[1..4] of integer;

  { shuffle order }
  ord4 : array[1..4] of integer;

  cx, cy, nx, ny, wx, wy : integer;
  i, j, d, tmp, r : integer;
  allDone : boolean;
  foundDir : boolean;

  { BFS for solution }
  qX   : array[1..STKSZ] of integer;
  qY   : array[1..STKSZ] of integer;
  fromX: array[1..GH, 1..GW] of integer;
  fromY: array[1..GH, 1..GW] of integer;
  qHead, qTail : integer;
  bx, by, px, py : integer;
  solved : boolean;

procedure drawCell(gx, gy, col : integer);
begin
  gotoxy(gx, gy + 1);
  textcolor(col);
  if grid[gy, gx] = 0 then
    write('#')
  else
    write(' ');
end;

procedure drawMaze;
var ii, jj : integer;
begin
  for ii := 1 to GH do
    for jj := 1 to GW do
      drawCell(jj, ii, 8);
  textcolor(7);
end;

procedure shuffle4;
var s, k, t : integer;
begin
  for s := 4 downto 2 do
  begin
    k := random(s) + 1;
    t := ord4[s];
    ord4[s] := ord4[k];
    ord4[k] := t;
  end;
end;

begin
  randomize;
  clrscr;
  hidecursor;

  { Direction vectors (row-delta, col-delta for cells and walls) }
  dr[1] := -1; dc[1] :=  0; wr[1] := -1; wc[1] :=  0;  { up }
  dr[2] :=  1; dc[2] :=  0; wr[2] :=  1; wc[2] :=  0;  { down }
  dr[3] :=  0; dc[3] := -1; wr[3] :=  0; wc[3] := -1;  { left }
  dr[4] :=  0; dc[4] :=  1; wr[4] :=  0; wc[4] :=  1;  { right }

  { Init: all walls }
  for i := 1 to GH do
    for j := 1 to GW do
      grid[i, j] := 0;

  { Mark cell positions as open }
  for i := 1 to CH do
    for j := 1 to CW do
      grid[2*i-1, 2*j-1] := 1;

  { Init visited }
  for i := 1 to CH do
    for j := 1 to CW do
      visited[i, j] := false;

  drawMaze;

  { Show title }
  gotoxy(1, GH + 2);
  textcolor(14);
  writeln('  Generating maze...');
  textcolor(7);

  { DFS iterative maze carving from cell (1,1) }
  stkTop := 1;
  stkX[1] := 1;
  stkY[1] := 1;
  visited[1, 1] := true;

  { Open entry and exit }
  grid[1, 1] := 1;
  grid[GH, GW] := 1;

  ord4[1] := 1; ord4[2] := 2; ord4[3] := 3; ord4[4] := 4;

  while stkTop > 0 do
  begin
    cx := stkX[stkTop];
    cy := stkY[stkTop];

    shuffle4;
    foundDir := false;
    i := 1;
    while (i <= 4) and not foundDir do
    begin
      d := ord4[i];
      nx := cx + dc[d];
      ny := cy + dr[d];
      if (nx >= 1) and (nx <= CW) and (ny >= 1) and (ny <= CH) then
        if not visited[ny, nx] then
        begin
          { carve wall between (cx,cy) and (nx,ny) in grid coords }
          wx := (2*cx - 1) + wc[d];
          wy := (2*cy - 1) + wr[d];
          grid[wy, wx] := 1;

          { show the newly opened wall }
          gotoxy(wx, wy + 1);
          textcolor(15);
          write(' ');
          textcolor(7);

          visited[ny, nx] := true;
          stkTop := stkTop + 1;
          stkX[stkTop] := nx;
          stkY[stkTop] := ny;
          foundDir := true;
          delay(8);
        end;
      i := i + 1;
    end;

    if not foundDir then
      stkTop := stkTop - 1;
  end;

  { Draw final maze cleanly }
  drawMaze;

  { Mark start/end }
  gotoxy(1, 2);
  textcolor(10);
  write('S');
  gotoxy(GW, GH + 1);
  textcolor(12);
  write('E');
  textcolor(7);

  gotoxy(1, GH + 2);
  textcolor(11);
  write('  Solving...           ');
  textcolor(7);

  delay(400);

  { BFS from grid pos (1,1) to (GW, GH) }
  for i := 1 to GH do
    for j := 1 to GW do
    begin
      fromX[i, j] := -1;
      fromY[i, j] := -1;
    end;

  qHead := 1; qTail := 1;
  qX[1] := 1; qY[1] := 1;
  fromX[1, 1] := 0; fromY[1, 1] := 0;
  solved := false;

  while (qHead <= qTail) and not solved do
  begin
    bx := qX[qHead]; by := qY[qHead];
    qHead := qHead + 1;

    if (bx = GW) and (by = GH) then
      solved := true
    else
    begin
      { try 4 neighbours in grid }
      if (bx > 1) and (grid[by, bx-1] = 1) and (fromX[by, bx-1] = -1) then
      begin
        qTail := qTail + 1;
        qX[qTail] := bx-1; qY[qTail] := by;
        fromX[by, bx-1] := bx; fromY[by, bx-1] := by;
      end;
      if (bx < GW) and (grid[by, bx+1] = 1) and (fromX[by, bx+1] = -1) then
      begin
        qTail := qTail + 1;
        qX[qTail] := bx+1; qY[qTail] := by;
        fromX[by, bx+1] := bx; fromY[by, bx+1] := by;
      end;
      if (by > 1) and (grid[by-1, bx] = 1) and (fromX[by-1, bx] = -1) then
      begin
        qTail := qTail + 1;
        qX[qTail] := bx; qY[qTail] := by-1;
        fromX[by-1, bx] := bx; fromY[by-1, bx] := by;
      end;
      if (by < GH) and (grid[by+1, bx] = 1) and (fromX[by+1, bx] = -1) then
      begin
        qTail := qTail + 1;
        qX[qTail] := bx; qY[qTail] := by+1;
        fromX[by+1, bx] := bx; fromY[by+1, bx] := by;
      end;
    end;
  end;

  { Trace solution path back and draw it }
  if solved then
  begin
    bx := GW; by := GH;
    while not ((bx = 1) and (by = 1)) do
    begin
      gotoxy(bx, by + 1);
      textcolor(11);
      write('.');
      delay(12);
      px := fromX[by, bx];
      py := fromY[by, bx];
      bx := px; by := py;
    end;
    gotoxy(1, 2);
    textcolor(10);
    write('S');
    gotoxy(GW, GH + 1);
    textcolor(12);
    write('E');
    textcolor(7);
    gotoxy(1, GH + 2);
    textcolor(10);
    writeln('  Solved!  Press Enter to exit.');
    textcolor(7);
  end
  else
  begin
    gotoxy(1, GH + 2);
    textcolor(12);
    writeln('  No solution found.');
    textcolor(7);
  end;

  showcursor;
  { wait for Enter }
  readln;
  clrscr;
end.
