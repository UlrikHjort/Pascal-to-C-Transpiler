{ 2048 - slide-and-merge tiles puzzle }
program tiles2048;

const
  N = 4;

var
  board : array[1..N, 1..N] of integer;
  score, best, i, j, r, c, moved : integer;
  ch : char;
  esc1, esc2 : char;
  done, won : boolean;

procedure drawBoard;
var v : integer;
begin
  clrscr;
  textcolor(14);
  writeln('  2048 - Arrow keys to move, q to quit');
  textcolor(11);
  write('  Score: '); write(score);
  write('   Best: '); write(best); writeln;
  textcolor(8);
  writeln('  +------+------+------+------+');
  for r := 1 to N do
  begin
    write('  |');
    for c := 1 to N do
    begin
      v := board[r, c];
      if v = 0 then
      begin textcolor(8); write('      '); end
      else
      begin
        case v of
           2:    textcolor(7);
           4:    textcolor(11);
           8:    textcolor(14);
          16:    textcolor(10);
          32:    textcolor(12);
          64:    textcolor(13);
         128:    textcolor(3);
         256:    textcolor(6);
         512:    textcolor(9);
        1024:    textcolor(5);
        2048:    textcolor(15);
        else     textcolor(15);
        end;
        if v < 10    then write('  '); if v < 100 then write(' ');
        write(v); write('  ');
      end;
      textcolor(8);
      write('|');
    end;
    writeln;
    textcolor(8);
    writeln('  +------+------+------+------+');
  end;
  textcolor(7);
end;

procedure addRandom;
var empties, pick, k : integer;
    er : array[1..16] of integer;
    ec2 : array[1..16] of integer;
begin
  empties := 0;
  for r := 1 to N do
    for c := 1 to N do
      if board[r, c] = 0 then
      begin
        empties := empties + 1;
        er[empties] := r;
        ec2[empties] := c;
      end;
  if empties > 0 then
  begin
    pick := random(empties) + 1;
    if random(10) < 9 then board[er[pick], ec2[pick]] := 2
    else board[er[pick], ec2[pick]] := 4;
  end;
end;

procedure slideLeft;
var tmp : array[1..N] of integer;
    ti, k, merged : integer;
begin
  for r := 1 to N do
  begin
    ti := 0;
    for c := 1 to N do
      if board[r, c] <> 0 then
      begin
        ti := ti + 1;
        tmp[ti] := board[r, c];
      end;
    { merge }
    k := 1;
    while k < ti do
    begin
      if tmp[k] = tmp[k+1] then
      begin
        tmp[k] := tmp[k] * 2;
        score := score + tmp[k];
        if tmp[k] = 2048 then won := true;
        { shift left }
        merged := k + 1;
        while merged < ti do
        begin
          tmp[merged] := tmp[merged+1];
          merged := merged + 1;
        end;
        ti := ti - 1;
      end;
      k := k + 1;
    end;
    for c := 1 to N do
    begin
      if c <= ti then
      begin
        if board[r, c] <> tmp[c] then moved := 1;
        board[r, c] := tmp[c];
      end
      else
      begin
        if board[r, c] <> 0 then moved := 1;
        board[r, c] := 0;
      end;
    end;
  end;
end;

procedure rotCW;
var nb : array[1..N, 1..N] of integer;
begin
  for r := 1 to N do
    for c := 1 to N do
      nb[c, N+1-r] := board[r, c];
  for r := 1 to N do
    for c := 1 to N do
      board[r, c] := nb[r, c];
end;

procedure rotCCW;
var nb : array[1..N, 1..N] of integer;
begin
  for r := 1 to N do
    for c := 1 to N do
      nb[N+1-c, r] := board[r, c];
  for r := 1 to N do
    for c := 1 to N do
      board[r, c] := nb[r, c];
end;

function hasMove : boolean;
var pr, pc2 : integer;
begin
  for pr := 1 to N do
    for pc2 := 1 to N do
    begin
      if board[pr, pc2] = 0 then begin hasMove := true; exit; end;
      if pc2 < N then
        if board[pr, pc2] = board[pr, pc2+1] then begin hasMove := true; exit; end;
      if pr < N then
        if board[pr, pc2] = board[pr+1, pc2] then begin hasMove := true; exit; end;
    end;
  hasMove := false;
end;

begin
  randomize;
  score := 0; best := 0; won := false;

  for i := 1 to N do for j := 1 to N do board[i, j] := 0;
  addRandom; addRandom;

  done := false;
  rawmode;
  hidecursor;

  while not done do
  begin
    if score > best then best := score;
    drawBoard;

    if won then
    begin
      textcolor(10); writeln('  YOU WIN! 2048 reached!'); textcolor(7);
      won := false;
    end;
    if not hasMove then
    begin
      textcolor(12); writeln('  GAME OVER - no moves left'); textcolor(7);
      done := true;
    end
    else
    begin
      ch := readkey;
      moved := 0;
      if ch = 'q' then
        done := true
      else if ord(ch) = 27 then
      begin
        esc1 := readkey;
        if ord(esc1) = 91 then
        begin
          esc2 := readkey;
          case ord(esc2) of
            65: begin { up - rotate CW, slide left, rotate CCW }
                  rotCW; slideLeft; rotCCW; end;
            66: begin { down }
                  rotCCW; slideLeft; rotCW; end;
            67: begin { right }
                  rotCW; rotCW; slideLeft; rotCW; rotCW; end;
            68: slideLeft;  { left }
          end;
        end;
      end;
      if moved = 1 then addRandom;
    end;
  end;

  normalmode;
  showcursor;
  writeln;
  textcolor(14);
  write('  Final score: '); write(score); writeln;
  textcolor(7);
end.
