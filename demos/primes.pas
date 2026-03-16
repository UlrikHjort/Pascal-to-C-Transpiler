{ Sieve of Eratosthenes - animated grid visualisation
  Numbers are laid out in a grid. Composite numbers are struck out
  one prime at a time, with colour showing which prime struck them. }
program primes;

const
  LIMIT = 400;
  COLS  = 20;

var
  sieve  : array[2..LIMIT] of boolean;  { true = still candidate }
  struck : array[2..LIMIT] of integer;  { which prime struck it (0=none) }
  p, i, col, row, num : integer;
  primeCount : integer;
  colors : array[1..12] of integer;
  ci : integer;
  numCX, numCY : integer;  { used by drawNum }

procedure drawNum(n, startRow : integer);
var fg : integer;
begin
  numCX := ((n - 2) mod COLS) * 4 + 2;
  numCY := ((n - 2) div COLS) + startRow;
  gotoxy(numCX, numCY);
  fg := struck[n];
  if fg = 0 then
  begin
    textcolor(15);
    if n < 10 then write('  ');
    if (n >= 10) and (n < 100) then write(' ');
    write(n);
  end
  else if sieve[n] then
  begin
    { prime - bright colour }
    textcolor(fg);
    if n < 10 then write('  ');
    if (n >= 10) and (n < 100) then write(' ');
    write(n);
  end
  else
  begin
    { composite - dimmed }
    textcolor(8);
    write('  . ');
  end;
  textcolor(7);
end;

var startRow : integer;

begin
  colors[1]  := 12;  { red }
  colors[2]  := 10;  { green }
  colors[3]  := 14;  { yellow }
  colors[4]  := 11;  { cyan }
  colors[5]  := 13;  { magenta }
  colors[6]  :=  9;  { blue }
  colors[7]  := 15;  { white }
  colors[8]  := 12;
  colors[9]  := 10;
  colors[10] := 14;
  colors[11] := 11;
  colors[12] := 13;

  for i := 2 to LIMIT do
  begin
    sieve[i]  := true;
    struck[i] := 0;
  end;

  clrscr;
  hidecursor;

  startRow := 3;

  { Title }
  gotoxy(1, 1);
  textcolor(14);
  write('  Sieve of Eratosthenes  (2 .. ');
  write(LIMIT);
  writeln(')');
  textcolor(7);

  { Draw all numbers }
  for num := 2 to LIMIT do
    drawNum(num, startRow);

  primeCount := 0;
  ci := 1;
  p := 2;
  while p <= LIMIT do
  begin
    if sieve[p] then
    begin
      primeCount := primeCount + 1;
      struck[p] := colors[ci];

      { mark p as prime with its colour }
      drawNum(p, startRow);

      { strike out all multiples }
      i := p * p;
      while i <= LIMIT do
      begin
        if sieve[i] then
        begin
          sieve[i]  := false;
          struck[i] := colors[ci];
          drawNum(i, startRow);
          delay(12);
        end;
        i := i + p;
      end;

      ci := ci + 1;
      if ci > 12 then ci := 1;
    end;
    p := p + 1;
  end;

  { Final pass: colour remaining primes brightly }
  for num := 2 to LIMIT do
    if sieve[num] and (struck[num] = 0) then
    begin
      struck[num] := colors[ci];
      drawNum(num, startRow);
      ci := ci + 1;
      if ci > 12 then ci := 1;
    end;

  { Status line }
  row := ((LIMIT - 2) div COLS) + startRow + 2;
  gotoxy(1, row);
  textcolor(11);
  write('  Found ');
  write(primeCount);
  write(' primes up to ');
  write(LIMIT);
  writeln('.  Press Enter to exit.');
  textcolor(7);

  showcursor;
  readln;
  clrscr;
end.
