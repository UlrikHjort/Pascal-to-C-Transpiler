program SortViz;

{ Animated sorting visualizer - bubble sort with ANSI bar chart }
{ Press any key after shuffle to start sorting                   }

const
  N      = 38;    { number of bars }
  TOP    = 2;     { top row of chart area }
  HEIGHT = 20;    { max bar height       }
  DELAY_MS = 40;

var
  bars   : array[1..N] of integer;
  i, j   : integer;
  tmp    : integer;
  swaps  : integer;
  cmps   : integer;
  ch     : char;

{ Draw a single bar column at position x with given height and color }
procedure draw_bar(x : integer; h : integer; color : integer);
var row : integer;
begin
  textcolor(color);
  { Fill from top down to bottom: blank above bar, filled below }
  for row := 1 to HEIGHT do begin
    gotoxy(x * 2, TOP + HEIGHT - row);
    if row <= h then
      write('##')
    else
      write('  ');
  end;
  textcolor(7);
end;

{ Draw all bars in default color (cyan) }
procedure draw_all;
var k : integer;
begin
  for k := 1 to N do
    draw_bar(k, bars[k], 14);
end;

{ Update status line }
procedure show_status(msg : string);
begin
  gotoxy(1, TOP + HEIGHT + 2);
  textcolor(11);
  write(msg);
  write('   cmps: ');
  write(cmps);
  write('   swaps: ');
  write(swaps);
  write('        ');
  textcolor(7);
end;

begin
  randomize;
  rawmode;
  hidecursor;
  clrscr;

  { Title }
  gotoxy(1, 1);
  textcolor(15);
  write('  Pascal2C Sorting Visualizer — Bubble Sort');
  textcolor(7);

  { Fill bars with values 1..N }
  for i := 1 to N do
    bars[i] := i;

  { Fisher-Yates shuffle }
  for i := N downto 2 do begin
    j := random(i) + 1;
    tmp    := bars[i];
    bars[i] := bars[j];
    bars[j] := tmp;
  end;

  swaps := 0;
  cmps  := 0;

  draw_all;
  gotoxy(1, TOP + HEIGHT + 2);
  textcolor(13);
  write('  Shuffled! Press any key to sort...');
  textcolor(7);

  { Wait for keypress }
  while not keypressed do
    delay(50);
  ch := readkey;

  clrscr;
  gotoxy(1, 1);
  textcolor(15);
  write('  Pascal2C Sorting Visualizer — Bubble Sort');
  textcolor(7);

  swaps := 0;
  cmps  := 0;
  draw_all;
  show_status('Sorting... ');

  { Bubble sort with animation }
  for i := N downto 2 do begin
    for j := 1 to i - 1 do begin
      cmps := cmps + 1;

      { Highlight comparison pair in red }
      draw_bar(j,     bars[j],     12);
      draw_bar(j + 1, bars[j + 1], 12);
      show_status('Sorting... ');
      delay(DELAY_MS);

      if bars[j] > bars[j + 1] then begin
        swaps := swaps + 1;
        tmp        := bars[j];
        bars[j]    := bars[j + 1];
        bars[j + 1] := tmp;

        { Show swap in yellow }
        draw_bar(j,     bars[j],     14);
        draw_bar(j + 1, bars[j + 1], 14);
        show_status('Sorting... ');
        delay(DELAY_MS);
      end else begin
        { Restore to cyan if no swap }
        draw_bar(j,     bars[j],     11);
        draw_bar(j + 1, bars[j + 1], 11);
        delay(DELAY_MS div 2);
      end;
    end;
    { Mark sorted bar green }
    draw_bar(i, bars[i], 10);
  end;
  { Mark last bar green too }
  draw_bar(1, bars[1], 10);

  { Done }
  gotoxy(1, TOP + HEIGHT + 2);
  textcolor(10);
  write('  Done!  cmps: ');
  write(cmps);
  write('   swaps: ');
  write(swaps);
  write('   Press any key to exit.');
  textcolor(7);
  gotoxy(1, TOP + HEIGHT + 4);

  while not keypressed do
    delay(50);
  ch := readkey;

  normalmode;
  showcursor;
end.
