{ Dijkstra – shortest path visualiser on a 20x12 grid }
program dijkstra;

const
  GW = 20;
  GH = 12;
  INF = 99999;

var
  { grid: 0=open 1=wall }
  grid : array[1..GH, 1..GW] of integer;
  dist : array[1..GH, 1..GW] of integer;
  prev_r : array[1..GH, 1..GW] of integer;
  prev_c : array[1..GH, 1..GW] of integer;
  vis  : array[1..GH, 1..GW] of integer;
  path : array[1..GH, 1..GW] of integer;

  { priority queue – simple linear scan (small grid) }
  qr, qc, qd : array[1..500] of integer;
  qsize : integer;

  sr, sc, er, ec : integer;
  i, j, r, c, nd : integer;
  dr, dc : array[1..4] of integer;
  br, bc, bd, nr, nc : integer;
  found : boolean;
  ch : char;

procedure drawGrid(phase : integer);
var row, col, v : integer;
begin
  clrscr;
  textcolor(14);
  gotoxy(1, 1);
  if phase = 0 then writeln('  Grid – finding path...')
  else if phase = 1 then writeln('  Dijkstra – searching...')
  else writeln('  Dijkstra – path found!');
  for row := 1 to GH do
  begin
    write('  ');
    for col := 1 to GW do
    begin
      if (row = sr) and (col = sc) then
      begin textcolor(10); write('S '); end
      else if (row = er) and (col = ec) then
      begin textcolor(12); write('E '); end
      else if grid[row, col] = 1 then
      begin textcolor(8); write('# '); end
      else if path[row, col] = 1 then
      begin textcolor(13); write('* '); end
      else if vis[row, col] = 1 then
      begin textcolor(11); write('. '); end
      else
      begin textcolor(7); write('  '); end;
    end;
    writeln;
  end;
  textcolor(7);
  if phase = 2 then
  begin
    writeln;
    if found then
    begin
      textcolor(10);
      write('  Path length: ');
      write(dist[er, ec]);
      writeln(' steps');
    end
    else
    begin
      textcolor(12);
      writeln('  No path found!');
    end;
    textcolor(7);
  end;
end;

begin
  dr[1] := -1; dr[2] :=  1; dr[3] :=  0; dr[4] :=  0;
  dc[1] :=  0; dc[2] :=  0; dc[3] := -1; dc[4] :=  1;

  randomize;

  { init grid }
  for i := 1 to GH do
    for j := 1 to GW do
    begin
      grid[i, j] := 0;
      if random(4) = 0 then grid[i, j] := 1;
    end;

  sr := 1; sc := 1; er := GH; ec := GW;
  grid[sr, sc] := 0; grid[er, ec] := 0;

  { init dist }
  for i := 1 to GH do
    for j := 1 to GW do
    begin
      dist[i, j] := INF;
      vis[i, j]  := 0;
      path[i, j] := 0;
      prev_r[i, j] := 0;
      prev_c[i, j] := 0;
    end;
  dist[sr, sc] := 0;

  { init queue }
  qsize := 1; qr[1] := sr; qc[1] := sc; qd[1] := 0;

  found := false;
  drawGrid(0);
  delay(600);

  while qsize > 0 do
  begin
    { find minimum in queue }
    bd := INF; br := 0; bc := 0; nd := 0;
    for i := 1 to qsize do
      if qd[i] < bd then
      begin bd := qd[i]; br := qr[i]; bc := qc[i]; nd := i; end;

    { remove it }
    qr[nd] := qr[qsize];
    qc[nd] := qc[qsize];
    qd[nd] := qd[qsize];
    qsize := qsize - 1;

    r := br; c := bc;
    if vis[r, c] = 1 then
    begin
      { skip }
    end
    else
    begin
      vis[r, c] := 1;

      if (r = er) and (c = ec) then
      begin
        found := true;
        qsize := 0;
      end
      else
      begin
        for i := 1 to 4 do
        begin
          nr := r + dr[i];
          nc := c + dc[i];
          if (nr >= 1) and (nr <= GH) and (nc >= 1) and (nc <= GW) then
            if (grid[nr, nc] = 0) and (vis[nr, nc] = 0) then
            begin
              nd := dist[r, c] + 1;
              if nd < dist[nr, nc] then
              begin
                dist[nr, nc] := nd;
                prev_r[nr, nc] := r;
                prev_c[nr, nc] := c;
                qsize := qsize + 1;
                qr[qsize] := nr;
                qc[qsize] := nc;
                qd[qsize] := nd;
              end;
            end;
        end;
      end;
    end;

    if qsize mod 5 = 0 then
    begin
      drawGrid(1);
      delay(60);
    end;
  end;

  { trace path }
  if found then
  begin
    r := er; c := ec;
    while not ((r = sr) and (c = sc)) do
    begin
      path[r, c] := 1;
      nr := prev_r[r, c];
      nc := prev_c[r, c];
      r := nr; c := nc;
    end;
    path[sr, sc] := 1;
  end;

  drawGrid(2);
  writeln;
  write('  Press Enter...');
  readln;
end.
