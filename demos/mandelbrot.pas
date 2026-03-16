{ Mandelbrot set rendered in ASCII with ANSI 16-color terminal output.
  Each character represents one pixel; color encodes escape velocity. }

program Mandelbrot;

const
  WIDTH  = 78;
  HEIGHT = 40;
  MAXITER = 64;

var
  cx, cy   : real;
  zx, zy   : real;
  zx2, zy2 : real;
  iter     : integer;
  col, row : integer;

{ ANSI foreground colors 0-15 map via textcolor() }
procedure SetColor(n : integer);
begin
  textcolor(n)
end;

begin
  hidecursor;
  clrscr;
  for row := 0 to HEIGHT - 1 do
  begin
    for col := 0 to WIDTH - 1 do
    begin
      cx := col * 3.5 / (WIDTH  - 1) - 2.5;
      cy := row * 2.0 / (HEIGHT - 1) - 1.0;
      zx := 0.0;
      zy := 0.0;
      iter := 0;
      zx2 := zx * zx;
      zy2 := zy * zy;
      while (iter < MAXITER) and (zx2 + zy2 < 4.0) do
      begin
        zy   := 2.0 * zx * zy + cy;
        zx   := zx2 - zy2 + cx;
        zx2  := zx * zx;
        zy2  := zy * zy;
        iter := iter + 1
      end;
      if iter = MAXITER then
      begin
        textcolor(0);   { black - inside set }
        write(' ')
      end
      else
      begin
        { map escape speed to 14 colors (skip 0=black, avoid white=15) }
        SetColor((iter mod 14) + 1);
        write('*')
      end
    end;
    writeln('')
  end;
  textcolor(7);   { reset to normal white }
  showcursor
end.
