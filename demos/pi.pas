{ Pi - approximate PI using four classic methods, side by side }
program pi;

const ITERS = 100000;

var
  i            : integer;
  leibniz      : real;   { Leibniz: 4*(1-1/3+1/5-1/7+...) }
  nilakantha   : real;   { Nilakantha series }
  wallis       : real;   { Wallis product }
  montecarlo   : real;   { Monte Carlo (random points in unit circle) }
  inside       : integer;
  x, y, dist   : real;
  sign         : real;
  denom        : real;
  k            : integer;

procedure printApprox(label2 : string; val : real; iters : integer);
begin
  textcolor(11);
  write('  ');
  write(label2);
  write(': ');
  textcolor(10);
  write(val);
  textcolor(8);
  write('   (');
  write(iters);
  writeln(' iterations)');
  textcolor(7);
end;

begin
  clrscr;
  textcolor(14);
  writeln('  === Approximating PI ===');
  textcolor(8);
  writeln('  True value: 3.14159265358979...');
  textcolor(7);
  writeln;
  writeln('  Computing...');

  { Leibniz formula: PI/4 = 1 - 1/3 + 1/5 - 1/7 + ... }
  leibniz := 0.0;
  sign    := 1.0;
  denom   := 1.0;
  for i := 1 to ITERS do
  begin
    leibniz := leibniz + sign / denom;
    sign    := -sign;
    denom   := denom + 2.0;
  end;
  leibniz := leibniz * 4.0;

  { Nilakantha: PI = 3 + 4/(2*3*4) - 4/(4*5*6) + 4/(6*7*8) - ... }
  nilakantha := 3.0;
  sign       := 1.0;
  k          := 2;
  for i := 1 to ITERS do
  begin
    nilakantha := nilakantha + sign * 4.0 / (k * (k+1) * (k+2));
    sign := -sign;
    k    := k + 2;
  end;

  { Wallis product: PI/2 = (2/1)*(2/3)*(4/3)*(4/5)*(6/5)*(6/7)*... }
  wallis := 1.0;
  for i := 1 to ITERS do
  begin
    k      := i * 2;
    wallis := wallis * (k / (k - 1)) * (k / (k + 1));
  end;
  wallis := wallis * 2.0;

  { Monte Carlo: ratio of random points inside unit circle }
  randomize;
  inside := 0;
  for i := 1 to ITERS do
  begin
    x    := random(10000) / 10000.0;
    y    := random(10000) / 10000.0;
    dist := x * x + y * y;
    if dist <= 1.0 then
      inside := inside + 1;
  end;
  montecarlo := 4.0 * inside / ITERS;

  clrscr;
  textcolor(14);
  writeln('  === Approximating PI ===');
  textcolor(8);
  writeln('  True value: 3.14159265358979...');
  writeln;
  textcolor(7);

  printApprox('Leibniz  (alternating series)  ', leibniz,    ITERS);
  printApprox('Nilakantha (faster converging) ', nilakantha, ITERS);
  printApprox('Wallis   (infinite product)    ', wallis,     ITERS);
  printApprox('Monte Carlo (random sampling)  ', montecarlo, ITERS);

  writeln;
  textcolor(11);
  writeln('  Note: Leibniz and Wallis converge slowly; Nilakantha is much faster.');
  textcolor(7);
  writeln;
  write('  Press Enter to exit.');
  readln;
end.
