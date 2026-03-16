{ Wolfram Elementary Cellular Automaton - Rules 30, 90, 101, 110
  Each rule is shown for HEIGHT generations.
  Rule 30  - chaotic (used as a random-number generator)
  Rule 90  - Sierpinski triangle (XOR rule)
  Rule 101 - oscillating vacuum (background correction applied)
  Rule 110 - complex / Turing-complete
  Press any key to advance to the next rule, or q to quit. }
program rule101;

const
  WIDTH  = 79;
  HEIGHT = 38;
  NRULES = 4;

var
  ruleSet : array[1..NRULES] of integer;
  ruleDesc: array[1..NRULES] of string[50];

  cur  : array[0..WIDTH+1] of integer;
  nxt  : array[0..WIDTH+1] of integer;

  gen, col, left, centre, right : integer;
  bg, disp, ruleNum : integer;
  ri : integer;
  ch : char;
  quit : boolean;
  colors : array[0..7] of integer;

function applyRule(rn, l, c, r : integer) : integer;
var pattern : integer;
begin
  pattern   := l * 4 + c * 2 + r;
  applyRule := (rn shr pattern) and 1;
end;

procedure printRow(rn, background : integer);
var j, fg, dv : integer;
begin
  for j := 1 to WIDTH do
  begin
    dv := cur[j] xor background;
    if dv = 1 then
    begin
      fg := colors[((j - 1) div 10) mod 8];
      textcolor(fg);
      write('#');
    end
    else
    begin
      textcolor(8);
      write('.');
    end;
  end;
  textcolor(7);
  writeln;
end;

procedure showRule(ri2 : integer);
var k : integer;
begin
  ruleNum := ruleSet[ri2];
  clrscr;
  textcolor(14);
  write('  Rule ');
  write(ruleNum);
  write(' - ');
  writeln(ruleDesc[ri2]);
  textcolor(8);
  writeln('  Press any key for next rule, q to quit.');
  textcolor(7);
  writeln;

  { seed: single centre cell }
  for col := 0 to WIDTH + 1 do
    cur[col] := 0;
  cur[WIDTH div 2 + 1] := 1;
  bg := 0;

  gen := 0;
  while (gen < HEIGHT) and not keypressed do
  begin
    printRow(ruleNum, bg);

    for col := 1 to WIDTH do
    begin
      left   := cur[col - 1];
      centre := cur[col];
      right  := cur[col + 1];
      nxt[col] := applyRule(ruleNum, left, centre, right);
    end;
    nxt[0]       := applyRule(ruleNum, cur[WIDTH], cur[0],       cur[1]);
    nxt[WIDTH+1] := applyRule(ruleNum, cur[WIDTH], cur[WIDTH+1], cur[1]);

    for col := 0 to WIDTH + 1 do
      cur[col] := nxt[col];

    bg  := applyRule(ruleNum, bg, bg, bg);
    gen := gen + 1;
  end;
end;

begin
  ruleSet[1] := 30;   ruleDesc[1] := 'chaotic - looks random';
  ruleSet[2] := 90;   ruleDesc[2] := 'Sierpinski triangle';
  ruleSet[3] := 101;  ruleDesc[3] := 'oscillating vacuum (background-corrected)';
  ruleSet[4] := 110;  ruleDesc[4] := 'complex - proven Turing-complete';

  colors[0] := 14;
  colors[1] := 10;
  colors[2] := 11;
  colors[3] := 13;
  colors[4] :=  9;
  colors[5] := 12;
  colors[6] := 15;
  colors[7] := 14;

  rawmode;
  hidecursor;

  quit := false;
  ri   := 1;
  while (ri <= NRULES) and not quit do
  begin
    showRule(ri);

    { Wait for key }
    while not keypressed do
      delay(50);
    ch := readkey;
    if (ch = 'q') or (ch = 'Q') then
      quit := true;
    ri := ri + 1;
  end;

  normalmode;
  showcursor;
  clrscr;
  writeln;
  textcolor(11);
  writeln('  Wolfram rules: 30 (chaos)  90 (Sierpinski)  101 (vacuum)  110 (Turing)');
  textcolor(7);
  writeln;
end.
