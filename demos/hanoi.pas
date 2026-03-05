{ Towers of Hanoi – animated ASCII pegs
  Moves a stack of discs from peg A to peg C using peg B as auxiliary.
  Each move is animated: disc lifts off, travels across, lands. }
program hanoi;

const
  NDISCS  = 7;
  PEGCOL1 = 10;
  PEGCOL2 = 40;
  PEGCOL3 = 70;
  PEGROW  = 22;   { bottom row of pegs }
  PEGH    = NDISCS + 2;

var
  pegs     : array[1..3, 1..NDISCS+1] of integer;  { disc widths, 0=empty }
  pegTop   : array[1..3] of integer;                 { index of top disc }
  pegCol   : array[1..3] of integer;
  moves    : integer;
  ch       : char;

procedure drawDisc(col, row, width, color : integer);
var j : integer;
begin
  gotoxy(col - width, row);
  textcolor(color);
  for j := 1 to 2 * width + 1 do
    write('=');
  textcolor(7);
end;

procedure eraseDisc(col, row, width : integer);
var j : integer;
begin
  gotoxy(col - width, row);
  for j := 1 to 2 * width + 1 do
    write(' ');
  { redraw peg pole }
  gotoxy(col, row);
  textcolor(8);
  write('|');
  textcolor(7);
end;

function discColor(w : integer) : integer;
var colors : array[1..7] of integer;
begin
  colors[1] := 12;
  colors[2] := 14;
  colors[3] := 10;
  colors[4] := 11;
  colors[5] := 13;
  colors[6] :=  9;
  colors[7] := 15;
  if (w >= 1) and (w <= 7) then
    discColor := colors[w]
  else
    discColor := 7;
end;

procedure drawPegs;
var p, r : integer;
begin
  for p := 1 to 3 do
  begin
    textcolor(8);
    for r := 1 to PEGH do
    begin
      gotoxy(pegCol[p], PEGROW - r + 1);
      write('|');
    end;
    { base }
    gotoxy(pegCol[p] - NDISCS - 1, PEGROW + 1);
    for r := 1 to 2 * NDISCS + 3 do
      write('=');
    { label }
    gotoxy(pegCol[p], PEGROW + 2);
    textcolor(11);
    if p = 1 then write('A')
    else if p = 2 then write('B')
    else write('C');
    textcolor(7);
  end;
end;

procedure drawAllDiscs;
var p, i, row : integer;
begin
  for p := 1 to 3 do
    for i := 1 to pegTop[p] do
    begin
      row := PEGROW - i + 1;
      drawDisc(pegCol[p], row, pegs[p, i], discColor(pegs[p, i]));
    end;
end;

procedure drawStatus;
begin
  gotoxy(1, PEGROW + 4);
  textcolor(11);
  write('  Moves: ');
  write(moves);
  write('   Discs: ');
  write(NDISCS);
  write('   Optimal: ');
  write(128 - 1);  { 2^7 - 1 = 127 }
  textcolor(7);
end;

procedure doMove(fromPeg, toPeg : integer);
var
  width, fromRow, toRow, liftRow, c : integer;
  fc, tc, step : integer;
begin
  { pick up disc from fromPeg }
  width  := pegs[fromPeg, pegTop[fromPeg]];
  fromRow := PEGROW - pegTop[fromPeg] + 1;
  liftRow := PEGROW - PEGH;  { lift to top }

  fc := pegCol[fromPeg];
  tc := pegCol[toPeg];

  { animate lift }
  c := fromRow;
  while c >= liftRow do
  begin
    eraseDisc(fc, c + 1, width);
    drawDisc(fc, c, width, discColor(width));
    delay(25);
    c := c - 1;
  end;
  eraseDisc(fc, liftRow, width);

  { animate travel }
  if fc < tc then step := 1 else step := -1;
  c := fc;
  while c <> tc do
  begin
    eraseDisc(c, liftRow, width);
    c := c + step;
    drawDisc(c, liftRow, width, discColor(width));
    delay(8);
  end;

  { destination row }
  toRow := PEGROW - pegTop[toPeg];  { land one above current top }

  { animate drop }
  c := liftRow;
  while c < toRow do
  begin
    eraseDisc(tc, c, width);
    c := c + 1;
    drawDisc(tc, c, width, discColor(width));
    delay(20);
  end;

  { update state }
  pegs[fromPeg, pegTop[fromPeg]] := 0;
  pegTop[fromPeg] := pegTop[fromPeg] - 1;
  pegTop[toPeg] := pegTop[toPeg] + 1;
  pegs[toPeg, pegTop[toPeg]] := width;

  moves := moves + 1;
  drawStatus;
end;

procedure hanoi(n, src, dst, aux : integer);
begin
  if n > 0 then
  begin
    hanoi(n - 1, src, aux, dst);
    doMove(src, dst);
    hanoi(n - 1, aux, dst, src);
  end;
end;

var i : integer;
begin
  pegCol[1] := PEGCOL1;
  pegCol[2] := PEGCOL2;
  pegCol[3] := PEGCOL3;

  { initialise pegs: all discs on peg 1, widest at bottom }
  for i := 1 to 3 do
    pegTop[i] := 0;
  for i := 1 to NDISCS do
  begin
    pegs[1, i] := NDISCS - i + 1;
    pegTop[1] := i;
  end;

  moves := 0;

  clrscr;
  hidecursor;

  drawPegs;
  drawAllDiscs;
  drawStatus;

  gotoxy(1, PEGROW + 5);
  textcolor(14);
  writeln('  Towers of Hanoi – press Enter to start');
  textcolor(7);
  readln;

  gotoxy(1, PEGROW + 5);
  write('                                        ');

  hanoi(NDISCS, 1, 3, 2);

  gotoxy(1, PEGROW + 5);
  textcolor(10);
  writeln('  Done! All discs moved to peg C.');
  textcolor(7);

  showcursor;
  readln;
  clrscr;
end.
