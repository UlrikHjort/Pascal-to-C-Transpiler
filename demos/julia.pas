{ Julia Set – coloured ASCII fractal, iterates through c values }
program julia;

const
  W      = 60;
  H      = 22;
  MAXITER = 32;

var
  i, j, iter, t : integer;
  zr, zi, cr, ci, tr, ti : integer;   { *1000 fixed-point }
  ch : char;
  palette : array[0..8] of integer;

{ fixed-point mul: (a*b)/1000 }
function fmul(a, b : integer) : integer;
begin
  fmul := (a * b) div 1000;
end;

function abs2(x : integer) : integer;
begin
  if x < 0 then abs2 := -x else abs2 := x;
end;

begin
  palette[0] := 0;
  palette[1] := 4;
  palette[2] := 1;
  palette[3] := 2;
  palette[4] := 6;
  palette[5] := 3;
  palette[6] := 5;
  palette[7] := 13;
  palette[8] := 15;

  clrscr;
  hidecursor;
  rawmode;
  t := 0;

  while not keypressed do
  begin
    { c = 0.7885 * e^(i*t) – slow rotation }
    cr := fmul(788, 1000 - fmul(t mod 360, t mod 360) div 32400);
    ci := fmul(788, (t mod 360) * 1000 div 180);
    if ci > 788 then ci := 1576 - ci;

    for i := 1 to H do
      for j := 1 to W do
      begin
        { map to [-1.5..1.5, -1.0..1.0] }
        zr := (j * 3000) div W - 1500;
        zi := (i * 2000) div H - 1000;

        iter := 0;
        while (iter < MAXITER) and
              (fmul(zr, zr) + fmul(zi, zi) < 4000) do
        begin
          tr := fmul(zr, zr) - fmul(zi, zi) + cr;
          ti := fmul(zr, zi) * 2 div 1000 + ci;
          zr := tr;
          zi := ti;
          iter := iter + 1;
        end;

        gotoxy(j + (80 - W) div 2, i + 1);

        if iter = MAXITER then
        begin
          textcolor(0);
          write(' ');
        end
        else
        begin
          textcolor(palette[iter mod 9]);
          if iter < 4 then write('.')
          else if iter < 12 then write('+')
          else if iter < 24 then write('*')
          else write('#');
        end;
      end;

    textcolor(7);
    t := (t + 3) mod 360;
    delay(60);
  end;

  ch := readkey;
  normalmode;
  showcursor;
  clrscr;
end.
