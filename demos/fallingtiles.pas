{ FallingTiles - ASCII falling-blocks game.
  Controls: a/d - move left/right, w - rotate,
            s - soft drop, space - hard drop, q - quit.
  Uses raw terminal mode via keypressed/readkey builtins.
  Blocks are drawn with ANSI colors.
  The board is BOARD_W x BOARD_H, with a 2-cell border. }

program FallingTiles;

const
  BOARD_W = 12;
  BOARD_H = 20;
  ORIGIN_X = 2;   { screen column where board left edge is drawn }
  ORIGIN_Y = 2;   { screen row    where board top  edge is drawn }
  TICK_MS  = 50;  { ms per game loop iteration }
  DROP_TICKS = 8; { iterations between automatic drops }

{ ---- piece shapes -----------------------------------------------
  7 classic tetrominoes; each encoded as 4 (col, row) offsets       }

{ Number of piece types }
const NPIECES = 7;

var
  { board: 0 = empty, 1..7 = filled with piece-color id }
  board : array[0..BOARD_H+1, 0..BOARD_W+1] of integer;

  { current piece }
  px, py    : integer;   { top-left position on board }
  ptype     : integer;   { piece type 0-6 }
  prot      : integer;   { rotation 0-3 }

  { piece block offsets (dr, dc) for each type and rotation }
  { We store 4 blocks per piece per rotation as arrays of 8 integers
    (r0,c0, r1,c1, r2,c2, r3,c3) }

  score     : integer;
  lines     : integer;
  gameover  : integer;
  tick      : integer;
  ch        : char;
  i, j, r, c : integer;

{ ---- piece data ------------------------------------------------- }
{ Each piece: 4 rotations x 4 blocks x 2 coords = 32 integers.
  We use a flat 3D array: shape[piece,rotation,block*2+coord].
  For simplicity we define all 7 pieces with all 4 rotations.      }

type TShape = array[0..1] of integer;

{ We define the 7 pieces via the 4 block (dr,dc) for rotation 0.
  We store them flattened: [piece][rot][8 values] }

var shapes : array[0..6, 0..3, 0..7] of integer;

procedure InitShapes;
begin
  { 0: I }
  shapes[0,0,0]:=0; shapes[0,0,1]:=0; shapes[0,0,2]:=0; shapes[0,0,3]:=1;
  shapes[0,0,4]:=0; shapes[0,0,5]:=2; shapes[0,0,6]:=0; shapes[0,0,7]:=3;

  shapes[0,1,0]:=0; shapes[0,1,1]:=0; shapes[0,1,2]:=1; shapes[0,1,3]:=0;
  shapes[0,1,4]:=2; shapes[0,1,5]:=0; shapes[0,1,6]:=3; shapes[0,1,7]:=0;

  shapes[0,2,0]:=0; shapes[0,2,1]:=0; shapes[0,2,2]:=0; shapes[0,2,3]:=1;
  shapes[0,2,4]:=0; shapes[0,2,5]:=2; shapes[0,2,6]:=0; shapes[0,2,7]:=3;

  shapes[0,3,0]:=0; shapes[0,3,1]:=0; shapes[0,3,2]:=1; shapes[0,3,3]:=0;
  shapes[0,3,4]:=2; shapes[0,3,5]:=0; shapes[0,3,6]:=3; shapes[0,3,7]:=0;

  { 1: O }
  shapes[1,0,0]:=0; shapes[1,0,1]:=0; shapes[1,0,2]:=0; shapes[1,0,3]:=1;
  shapes[1,0,4]:=1; shapes[1,0,5]:=0; shapes[1,0,6]:=1; shapes[1,0,7]:=1;

  shapes[1,1,0]:=0; shapes[1,1,1]:=0; shapes[1,1,2]:=0; shapes[1,1,3]:=1;
  shapes[1,1,4]:=1; shapes[1,1,5]:=0; shapes[1,1,6]:=1; shapes[1,1,7]:=1;

  shapes[1,2,0]:=0; shapes[1,2,1]:=0; shapes[1,2,2]:=0; shapes[1,2,3]:=1;
  shapes[1,2,4]:=1; shapes[1,2,5]:=0; shapes[1,2,6]:=1; shapes[1,2,7]:=1;

  shapes[1,3,0]:=0; shapes[1,3,1]:=0; shapes[1,3,2]:=0; shapes[1,3,3]:=1;
  shapes[1,3,4]:=1; shapes[1,3,5]:=0; shapes[1,3,6]:=1; shapes[1,3,7]:=1;

  { 2: T }
  shapes[2,0,0]:=0; shapes[2,0,1]:=0; shapes[2,0,2]:=0; shapes[2,0,3]:=1;
  shapes[2,0,4]:=0; shapes[2,0,5]:=2; shapes[2,0,6]:=1; shapes[2,0,7]:=1;

  shapes[2,1,0]:=0; shapes[2,1,1]:=0; shapes[2,1,2]:=1; shapes[2,1,3]:=0;
  shapes[2,1,4]:=1; shapes[2,1,5]:=1; shapes[2,1,6]:=2; shapes[2,1,7]:=0;

  shapes[2,2,0]:=0; shapes[2,2,1]:=1; shapes[2,2,2]:=1; shapes[2,2,3]:=0;
  shapes[2,2,4]:=1; shapes[2,2,5]:=1; shapes[2,2,6]:=1; shapes[2,2,7]:=2;

  shapes[2,3,0]:=0; shapes[2,3,1]:=1; shapes[2,3,2]:=1; shapes[2,3,3]:=0;
  shapes[2,3,4]:=1; shapes[2,3,5]:=1; shapes[2,3,6]:=2; shapes[2,3,7]:=1;

  { 3: S }
  shapes[3,0,0]:=0; shapes[3,0,1]:=1; shapes[3,0,2]:=0; shapes[3,0,3]:=2;
  shapes[3,0,4]:=1; shapes[3,0,5]:=0; shapes[3,0,6]:=1; shapes[3,0,7]:=1;

  shapes[3,1,0]:=0; shapes[3,1,1]:=0; shapes[3,1,2]:=1; shapes[3,1,3]:=0;
  shapes[3,1,4]:=1; shapes[3,1,5]:=1; shapes[3,1,6]:=2; shapes[3,1,7]:=1;

  shapes[3,2,0]:=0; shapes[3,2,1]:=1; shapes[3,2,2]:=0; shapes[3,2,3]:=2;
  shapes[3,2,4]:=1; shapes[3,2,5]:=0; shapes[3,2,6]:=1; shapes[3,2,7]:=1;

  shapes[3,3,0]:=0; shapes[3,3,1]:=0; shapes[3,3,2]:=1; shapes[3,3,3]:=0;
  shapes[3,3,4]:=1; shapes[3,3,5]:=1; shapes[3,3,6]:=2; shapes[3,3,7]:=1;

  { 4: Z }
  shapes[4,0,0]:=0; shapes[4,0,1]:=0; shapes[4,0,2]:=0; shapes[4,0,3]:=1;
  shapes[4,0,4]:=1; shapes[4,0,5]:=1; shapes[4,0,6]:=1; shapes[4,0,7]:=2;

  shapes[4,1,0]:=0; shapes[4,1,1]:=1; shapes[4,1,2]:=1; shapes[4,1,3]:=0;
  shapes[4,1,4]:=1; shapes[4,1,5]:=1; shapes[4,1,6]:=2; shapes[4,1,7]:=0;

  shapes[4,2,0]:=0; shapes[4,2,1]:=0; shapes[4,2,2]:=0; shapes[4,2,3]:=1;
  shapes[4,2,4]:=1; shapes[4,2,5]:=1; shapes[4,2,6]:=1; shapes[4,2,7]:=2;

  shapes[4,3,0]:=0; shapes[4,3,1]:=1; shapes[4,3,2]:=1; shapes[4,3,3]:=0;
  shapes[4,3,4]:=1; shapes[4,3,5]:=1; shapes[4,3,6]:=2; shapes[4,3,7]:=0;

  { 5: L }
  shapes[5,0,0]:=0; shapes[5,0,1]:=0; shapes[5,0,2]:=1; shapes[5,0,3]:=0;
  shapes[5,0,4]:=2; shapes[5,0,5]:=0; shapes[5,0,6]:=2; shapes[5,0,7]:=1;

  shapes[5,1,0]:=0; shapes[5,1,1]:=0; shapes[5,1,2]:=0; shapes[5,1,3]:=1;
  shapes[5,1,4]:=0; shapes[5,1,5]:=2; shapes[5,1,6]:=1; shapes[5,1,7]:=0;

  shapes[5,2,0]:=0; shapes[5,2,1]:=0; shapes[5,2,2]:=0; shapes[5,2,3]:=1;
  shapes[5,2,4]:=1; shapes[5,2,5]:=1; shapes[5,2,6]:=2; shapes[5,2,7]:=1;

  shapes[5,3,0]:=0; shapes[5,3,1]:=2; shapes[5,3,2]:=1; shapes[5,3,3]:=0;
  shapes[5,3,4]:=1; shapes[5,3,5]:=1; shapes[5,3,6]:=1; shapes[5,3,7]:=2;

  { 6: J }
  shapes[6,0,0]:=0; shapes[6,0,1]:=1; shapes[6,0,2]:=1; shapes[6,0,3]:=1;
  shapes[6,0,4]:=2; shapes[6,0,5]:=0; shapes[6,0,6]:=2; shapes[6,0,7]:=1;

  shapes[6,1,0]:=0; shapes[6,1,1]:=0; shapes[6,1,2]:=1; shapes[6,1,3]:=0;
  shapes[6,1,4]:=1; shapes[6,1,5]:=1; shapes[6,1,6]:=1; shapes[6,1,7]:=2;

  shapes[6,2,0]:=0; shapes[6,2,1]:=0; shapes[6,2,2]:=0; shapes[6,2,3]:=1;
  shapes[6,2,4]:=1; shapes[6,2,5]:=0; shapes[6,2,6]:=2; shapes[6,2,7]:=0;

  shapes[6,3,0]:=0; shapes[6,3,1]:=0; shapes[6,3,2]:=0; shapes[6,3,3]:=1;
  shapes[6,3,4]:=0; shapes[6,3,5]:=2; shapes[6,3,6]:=1; shapes[6,3,7]:=2
end;

{ ---- helpers ---------------------------------------------------- }

function Collides(bx, by, btype, brot : integer) : integer;
var k, dr, dc, nr, nc : integer;
begin
  Collides := 0;
  for k := 0 to 3 do
  begin
    dr := shapes[btype, brot, k*2];
    dc := shapes[btype, brot, k*2+1];
    nr := by + dr;
    nc := bx + dc;
    if (nr < 0) or (nr >= BOARD_H) or (nc < 0) or (nc >= BOARD_W) then
    begin
      Collides := 1;
      exit
    end;
    if board[nr, nc] <> 0 then
    begin
      Collides := 1;
      exit
    end
  end
end;

procedure LockPiece;
var k, dr, dc : integer;
begin
  for k := 0 to 3 do
  begin
    dr := shapes[ptype, prot, k*2];
    dc := shapes[ptype, prot, k*2+1];
    board[py + dr, px + dc] := ptype + 1
  end
end;

function ClearLines : integer;
var row, col, full, dst, src : integer;
  cleared : integer;
begin
  cleared := 0;
  dst := BOARD_H - 1;
  for src := BOARD_H - 1 downto 0 do
  begin
    full := 1;
    for col := 0 to BOARD_W - 1 do
      if board[src, col] = 0 then full := 0;
    if full = 0 then
    begin
      if dst <> src then
        for col := 0 to BOARD_W - 1 do
          board[dst, col] := board[src, col];
      dst := dst - 1
    end
    else
      cleared := cleared + 1
  end;
  for row := dst downto 0 do
    for col := 0 to BOARD_W - 1 do
      board[row, col] := 0;
  ClearLines := cleared
end;

procedure SpawnPiece;
var seed : integer;
begin
  seed := (ptype * 3 + lines + score) mod NPIECES;
  ptype := seed;
  prot  := 0;
  px    := BOARD_W div 2 - 1;
  py    := 0;
  if Collides(px, py, ptype, prot) = 1 then
    gameover := 1
end;

{ ---- rendering -------------------------------------------------- }

{ Colors for piece types 1-7 }
function PieceColor(t : integer) : integer;
begin
  if t = 1 then PieceColor := 14    { bright yellow - I }
  else if t = 2 then PieceColor := 11 { bright cyan  - O }
  else if t = 3 then PieceColor := 13 { bright magenta - T }
  else if t = 4 then PieceColor := 10 { bright green - S }
  else if t = 5 then PieceColor := 9  { bright red   - Z }
  else if t = 6 then PieceColor := 12 { bright blue  - L }
  else PieceColor := 6                { dark magenta - J }
end;

procedure DrawCell(sr, sc, color : integer);
begin
  gotoxy(ORIGIN_X + sc * 2, ORIGIN_Y + sr);
  textcolor(color);
  write('[]')
end;

procedure DrawBoard;
var row, col, cv : integer;
begin
  for row := 0 to BOARD_H - 1 do
    for col := 0 to BOARD_W - 1 do
    begin
      cv := board[row, col];
      if cv = 0 then
      begin
        gotoxy(ORIGIN_X + col * 2, ORIGIN_Y + row);
        textcolor(8);
        write('. ')
      end
      else
        DrawCell(row, col, PieceColor(cv))
    end
end;

procedure DrawPiece;
var k, dr, dc : integer;
begin
  for k := 0 to 3 do
  begin
    dr := shapes[ptype, prot, k*2];
    dc := shapes[ptype, prot, k*2+1];
    DrawCell(py + dr, px + dc, PieceColor(ptype + 1))
  end
end;

procedure ErasePiece;
var k, dr, dc : integer;
begin
  for k := 0 to 3 do
  begin
    dr := shapes[ptype, prot, k*2];
    dc := shapes[ptype, prot, k*2+1];
    gotoxy(ORIGIN_X + (px + dc) * 2, ORIGIN_Y + (py + dr));
    textcolor(8);
    write('. ')
  end
end;

procedure DrawBorder;
var row, col : integer;
begin
  textcolor(7);
  { top and bottom }
  gotoxy(ORIGIN_X - 1, ORIGIN_Y - 1);
  write('+');
  for col := 0 to BOARD_W - 1 do write('--');
  write('+');
  gotoxy(ORIGIN_X - 1, ORIGIN_Y + BOARD_H);
  write('+');
  for col := 0 to BOARD_W - 1 do write('--');
  write('+');
  { sides }
  for row := 0 to BOARD_H - 1 do
  begin
    gotoxy(ORIGIN_X - 1, ORIGIN_Y + row);
    write('|');
    gotoxy(ORIGIN_X + BOARD_W * 2, ORIGIN_Y + row);
    write('|')
  end
end;

procedure DrawStatus;
begin
  textcolor(7);
  gotoxy(ORIGIN_X + BOARD_W * 2 + 4, ORIGIN_Y + 2);
  write('SCORE: ');
  writeln(score);
  gotoxy(ORIGIN_X + BOARD_W * 2 + 4, ORIGIN_Y + 4);
  write('LINES: ');
  writeln(lines);
  gotoxy(ORIGIN_X + BOARD_W * 2 + 4, ORIGIN_Y + 7);
  write('a d - move');
  gotoxy(ORIGIN_X + BOARD_W * 2 + 4, ORIGIN_Y + 8);
  write('w   - rotate');
  gotoxy(ORIGIN_X + BOARD_W * 2 + 4, ORIGIN_Y + 9);
  write('s   - soft drop');
  gotoxy(ORIGIN_X + BOARD_W * 2 + 4, ORIGIN_Y + 10);
  write('spc - hard drop');
  gotoxy(ORIGIN_X + BOARD_W * 2 + 4, ORIGIN_Y + 11);
  write('q   - quit')
end;

{ ---- main ------------------------------------------------------- }

var  cleared : integer;
     newrot  : integer;

begin
  InitShapes;

  { zero the board }
  for r := 0 to BOARD_H + 1 do
    for c := 0 to BOARD_W + 1 do
      board[r, c] := 0;

  score    := 0;
  lines    := 0;
  gameover := 0;
  tick     := 0;
  ptype    := 0;
  prot     := 0;
  px       := BOARD_W div 2 - 1;
  py       := 0;

  hidecursor;
  clrscr;
  DrawBorder;
  DrawBoard;
  SpawnPiece;
  DrawStatus;

  { Put terminal in raw non-blocking mode }
  rawmode;

  while gameover = 0 do
  begin
    { Poll keyboard - 'a'/'d'/'s'/'q' (non-blocking) }
    if keypressed then
    begin
      ch := readkey;
      if ch = 'q' then gameover := 1
      else if ch = 'a' then
      begin
        ErasePiece;
        if Collides(px - 1, py, ptype, prot) = 0 then
          px := px - 1;
        DrawPiece
      end
      else if ch = 'd' then
      begin
        ErasePiece;
        if Collides(px + 1, py, ptype, prot) = 0 then
          px := px + 1;
        DrawPiece
      end
      else if ch = 's' then
      begin
        { soft drop }
        ErasePiece;
        if Collides(px, py + 1, ptype, prot) = 0 then
        begin
          py := py + 1;
          score := score + 1
        end;
        DrawPiece;
        tick := 0
      end
      else if ch = 'w' then
      begin
        { rotate }
        ErasePiece;
        newrot := (prot + 1) mod 4;
        if Collides(px, py, ptype, newrot) = 0 then
          prot := newrot;
        DrawPiece
      end
      else if ch = ' ' then
      begin
        { hard drop - fall as far as possible, then lock }
        ErasePiece;
        while Collides(px, py + 1, ptype, prot) = 0 do
        begin
          py := py + 1;
          score := score + 2
        end;
        DrawPiece;
        tick := DROP_TICKS   { force immediate lock on next gravity tick }
      end
    end;

    { Gravity }
    tick := tick + 1;
    if tick >= DROP_TICKS then
    begin
      tick := 0;
      ErasePiece;
      if Collides(px, py + 1, ptype, prot) = 0 then
        py := py + 1
      else
      begin
        { lock and spawn }
        LockPiece;
        cleared := ClearLines;
        if cleared > 0 then
        begin
          lines := lines + cleared;
          score := score + cleared * cleared * 100
        end;
        DrawBoard;
        SpawnPiece
      end;
      DrawPiece;
      DrawStatus
    end;

    delay(TICK_MS)
  end;

  normalmode;
  textcolor(7);
  clrscr;
  showcursor;
  write('Game Over!  Score: ');
  writeln(score)
end.
