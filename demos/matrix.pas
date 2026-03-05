{ Matrix – falling green characters, classic digital rain effect }
program matrix;

const
  COLS  = 40;
  ROWS  = 24;
  NSTREAMS = 30;

var
  { each stream: column, head row, length, speed counter, speed }
  scol   : array[1..NSTREAMS] of integer;
  srow   : array[1..NSTREAMS] of integer;
  slen   : array[1..NSTREAMS] of integer;
  stick  : array[1..NSTREAMS] of integer;  { countdown to next move }
  sspeed : array[1..NSTREAMS] of integer;  { ticks per step }
  grid   : array[1..ROWS, 1..COLS] of integer;  { 0=empty 1=trail 2=head }
  i, j, s : integer;
  ch : char;
  chars : string[20];

procedure randomChar;
var c : integer;
begin
  c := random(62);
  if c < 10 then
    write(chr(c + ord('0')))
  else if c < 36 then
    write(chr(c - 10 + ord('A')))
  else
    write(chr(c - 36 + ord('a')));
end;

procedure drawCell(r, c2, kind : integer);
begin
  gotoxy(c2 * 2 - 1, r + 1);
  if kind = 2 then
  begin
    textcolor(15);  { bright white head }
    randomChar;
    randomChar;
  end
  else if kind = 1 then
  begin
    textcolor(10);  { green trail }
    randomChar;
    randomChar;
  end
  else
  begin
    textcolor(0);
    write('  ');
  end;
  textcolor(7);
end;

begin
  randomize;

  { init streams }
  for i := 1 to NSTREAMS do
  begin
    scol[i]   := random(COLS) + 1;
    srow[i]   := -(random(ROWS));
    slen[i]   := random(8) + 4;
    sspeed[i] := random(3) + 1;
    stick[i]  := sspeed[i];
  end;

  for i := 1 to ROWS do
    for j := 1 to COLS do
      grid[i, j] := 0;

  clrscr;
  hidecursor;

  rawmode;

  while not keypressed do
  begin
    delay(40);

    for s := 1 to NSTREAMS do
    begin
      stick[s] := stick[s] - 1;
      if stick[s] <= 0 then
      begin
        stick[s] := sspeed[s];

        { erase tail }
        if (srow[s] - slen[s]) >= 1 then
        begin
          grid[srow[s] - slen[s], scol[s]] := 0;
          drawCell(srow[s] - slen[s], scol[s], 0);
        end;

        { old head becomes trail }
        if (srow[s] >= 1) and (srow[s] <= ROWS) then
        begin
          grid[srow[s], scol[s]] := 1;
          drawCell(srow[s], scol[s], 1);
        end;

        srow[s] := srow[s] + 1;

        { draw new head }
        if (srow[s] >= 1) and (srow[s] <= ROWS) then
        begin
          grid[srow[s], scol[s]] := 2;
          drawCell(srow[s], scol[s], 2);
        end;

        { respawn when off screen }
        if srow[s] - slen[s] > ROWS then
        begin
          scol[s]  := random(COLS) + 1;
          srow[s]  := -(random(ROWS));
          slen[s]  := random(8) + 4;
          sspeed[s]:= random(3) + 1;
          stick[s] := sspeed[s];
        end;
      end;
    end;
  end;

  ch := readkey;
  normalmode;
  showcursor;
  clrscr;
end.
