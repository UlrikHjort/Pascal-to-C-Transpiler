{ Collatz Conjecture - show the sequence for any starting number.
  Bar chart shows the value at each step; sequence always reaches 1. }
program collatz;

const MAXSTEPS = 300;
const BARH     = 20;

var
  seq   : array[1..MAXSTEPS] of integer;
  steps : integer;
  n, maxVal, i, bh, col : integer;
  answer : char;

procedure drawBar(x, height, color : integer);
var r : integer;
begin
  textcolor(color);
  for r := 1 to height do
  begin
    gotoxy(x, BARH - r + 4);
    write('|');
  end;
  { clear above }
  textcolor(0);
  for r := height + 1 to BARH do
  begin
    gotoxy(x, BARH - r + 4);
    write(' ');
  end;
  textcolor(7);
end;

function barColor(val, mx : integer) : integer;
var ratio : integer;
begin
  ratio := val * 10 div mx;
  if ratio >= 8 then barColor := 12   { red }
  else if ratio >= 5 then barColor := 14  { yellow }
  else if ratio >= 3 then barColor := 10  { green }
  else barColor := 11;                    { cyan }
end;

begin
  answer := 'y';
  while answer = 'y' do
  begin
    clrscr;
    textcolor(14);
    writeln('  === Collatz Conjecture ===');
    textcolor(7);
    writeln('  Pick any number. Repeatedly: if even divide by 2,');
    writeln('  if odd multiply by 3 and add 1. It always reaches 1!');
    writeln;
    write('  Starting number (2 - 10000): ');
    readln(n);
    if n < 2   then n := 2;
    if n > 10000 then n := 10000;

    { Build sequence }
    steps    := 1;
    seq[1]   := n;
    maxVal   := n;
    while (seq[steps] <> 1) and (steps < MAXSTEPS) do
    begin
      if seq[steps] mod 2 = 0 then
        seq[steps + 1] := seq[steps] div 2
      else
        seq[steps + 1] := seq[steps] * 3 + 1;
      steps := steps + 1;
      if seq[steps] > maxVal then maxVal := seq[steps];
    end;

    clrscr;
    textcolor(14);
    write('  Collatz(');
    write(n);
    write(') - ');
    write(steps);
    write(' steps, peak = ');
    writeln(maxVal);
    textcolor(7);

    { Draw bar chart (up to 78 bars) }
    col := 1;
    i   := 1;
    while (i <= steps) and (col <= 78) do
    begin
      if maxVal > 0 then
        bh := seq[i] * BARH div maxVal
      else
        bh := 1;
      if bh < 1 then bh := 1;
      drawBar(col, bh, barColor(seq[i], maxVal));
      col := col + 1;
      i   := i + 1;
    end;

    { x-axis }
    gotoxy(1, BARH + 4);
    textcolor(8);
    for i := 1 to 78 do write('-');
    writeln;

    textcolor(11);
    write('  Steps: ');
    write(steps);
    write('   Peak: ');
    write(maxVal);
    write('   Start: ');
    writeln(n);
    textcolor(7);
    writeln;
    write('  Try another? (y/n): ');
    readln(answer);
  end;
end.
