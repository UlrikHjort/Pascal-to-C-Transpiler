{ Base Converter – convert integers between binary, octal, decimal, hex }
program baseconv;

const MAXBITS = 32;

var
  n      : integer;
  answer : char;
  i, rem, tmp : integer;
  digits : array[1..MAXBITS] of integer;
  dcount : integer;
  hexdig : string[16];

procedure printBase(val, base, width : integer; label2 : string);
var d : array[1..MAXBITS] of integer;
    cnt, v, j : integer;
begin
  if val = 0 then
  begin
    textcolor(11); write(label2); write(': ');
    textcolor(10);
    j := width;
    while j > 1 do begin write('0'); j := j - 1; end;
    writeln('0');
    textcolor(7);
    exit;
  end;
  cnt := 0;
  v   := val;
  while v > 0 do
  begin
    cnt      := cnt + 1;
    d[cnt]   := v mod base;
    v        := v div base;
  end;
  textcolor(11); write(label2); write(': ');
  textcolor(10);
  { padding }
  j := width - cnt;
  while j > 0 do begin write('0'); j := j - 1; end;
  { digits high to low }
  j := cnt;
  while j >= 1 do
  begin
    if d[j] < 10 then
      write(d[j])
    else
    begin
      case d[j] of
        10: write('A'); 11: write('B'); 12: write('C');
        13: write('D'); 14: write('E'); 15: write('F');
      end;
    end;
    j := j - 1;
  end;
  textcolor(7);
  writeln;
end;

begin
  answer := 'y';
  while answer = 'y' do
  begin
    clrscr;
    textcolor(14);
    writeln('  === Base Converter ===');
    textcolor(7);
    writeln;
    write('  Enter a decimal number (0 - 2147483647): ');
    readln(n);
    if n < 0 then n := 0;
    writeln;

    textcolor(14);
    writeln('  Conversions:');
    writeln;
    printBase(n, 10,  1, '  Decimal    (10) ');
    printBase(n, 16,  8, '  Hex        (16) ');
    printBase(n,  8, 11, '  Octal       (8) ');
    printBase(n,  2, 32, '  Binary      (2) ');
    writeln;

    write('  Convert another? (y/n): ');
    readln(answer);
  end;
end.
