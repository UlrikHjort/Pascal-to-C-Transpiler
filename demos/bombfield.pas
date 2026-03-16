{ BombField - reveal all safe cells without hitting a bomb.
  The number in each revealed cell tells you how many of its
  8 neighbouring cells contain a hidden bomb.
  Use logic to deduce which cells are safe, flag the rest.

  Controls (type and press Enter):
    r c       - reveal cell at row r, column c  (e.g. "3 5")
    f r c     - flag / unflag a suspected bomb  (e.g. "f 2 4")
    h         - show this help screen
    q         - quit

  A blank/zero cell auto-expands to all connected safe neighbours.
  You win when every non-bomb cell is revealed. }

program bombfield;

const
  COLS  = 16;
  ROWS  = 9;
  MINES = 20;

var
  bomb     : array[1..ROWS, 1..COLS] of boolean;
  revealed : array[1..ROWS, 1..COLS] of boolean;
  flagged  : array[1..ROWS, 1..COLS] of boolean;
  adj      : array[1..ROWS, 1..COLS] of integer;
  r, c, d, e, nr, nc : integer;
  bombCount, flagCount, safeRevealed, totalSafe : integer;
  parsePos : integer;
  gameOver, won : boolean;
  cmd : string[20];
  answer : char;

procedure showHelp;
begin
  clrscr;
  textcolor(14);
  writeln('  *** BombField - How to Play ***');
  writeln;
  textcolor(7);
  writeln('  The grid contains hidden bombs.');
  writeln('  Your goal: reveal every safe cell without hitting a bomb.');
  writeln;
  textcolor(11);
  writeln('  What the grid shows:');
  textcolor(7);
  writeln('    .          unrevealed cell');
  writeln('    F          cell you have flagged as a suspected bomb');
  textcolor(10);
  write('    1 2 3 ...  ');
  textcolor(7);
  writeln('number of bombs in the 8 surrounding cells');
  textcolor(7);
  writeln('    (blank)    safe cell with no bomb neighbours - auto-expands');
  writeln;
  textcolor(11);
  writeln('  Commands (type and press Enter):');
  textcolor(7);
  writeln('    r c     reveal cell at row r, column c     example: 3 5');
  writeln('    f r c   flag or unflag a cell              example: f 2 4');
  writeln('    h       show this help screen');
  writeln('    q       quit');
  writeln;
  textcolor(11);
  writeln('  Tips:');
  textcolor(7);
  writeln('    * Start somewhere in the middle - you often get a big open area.');
  writeln('    * A "1" next to only one unrevealed cell means that cell is a bomb.');
  writeln('    * Flag bombs so you don''t accidentally reveal them.');
  writeln('    * Flags are just reminders - flagging does NOT reveal a cell.');
  writeln;
  textcolor(8);
  writeln('  Press Enter to return to the game...');
  textcolor(7);
  readln;
end;

procedure placeAdjacency;
var rr, cc, dd, ee, cnt : integer;
begin
  for rr := 1 to ROWS do
    for cc := 1 to COLS do
    begin
      cnt := 0;
      for dd := -1 to 1 do
        for ee := -1 to 1 do
        begin
          nr := rr + dd; nc := cc + ee;
          if (nr >= 1) and (nr <= ROWS) and
             (nc >= 1) and (nc <= COLS) and
             bomb[nr, nc] then
            cnt := cnt + 1;
        end;
      adj[rr, cc] := cnt;
    end;
end;

function adjColor(n : integer) : integer;
begin
  case n of
    1 : adjColor :=  9;
    2 : adjColor := 10;
    3 : adjColor := 12;
    4 : adjColor := 13;
    5 : adjColor := 14;
    6 : adjColor := 11;
    7 : adjColor := 15;
    8 : adjColor :=  8;
  else  adjColor :=  7;
  end;
end;

procedure drawBoard(showBombs : boolean);
var rr, cc, n : integer;
begin
  clrscr;
  textcolor(14);
  write('  BombField  ');
  textcolor(8);
  write(COLS);
  write('x');
  write(ROWS);
  write('  Bombs: ');
  write(MINES);
  textcolor(7);
  writeln('   Type h for help, q to quit');
  writeln;

  { column header }
  textcolor(8);
  write('      ');
  for cc := 1 to COLS do
  begin
    if cc < 10 then write(' ');
    write(cc);
    write(' ');
  end;
  writeln;
  write('      ');
  for cc := 1 to COLS do
    write('---');
  writeln;

  for rr := 1 to ROWS do
  begin
    textcolor(8);
    write('  ');
    if rr < 10 then write(' ');
    write(rr);
    write(' | ');
    for cc := 1 to COLS do
    begin
      if flagged[rr, cc] and not revealed[rr, cc] then
      begin
        textcolor(12); write(' F ');
      end
      else if not revealed[rr, cc] then
      begin
        if showBombs and bomb[rr, cc] then
        begin textcolor(12); write('[*]'); end
        else
        begin textcolor(8); write(' . '); end;
      end
      else if bomb[rr, cc] then
      begin
        textcolor(12); write('[*]');
      end
      else
      begin
        n := adj[rr, cc];
        if n = 0 then
        begin textcolor(7); write('   '); end
        else
        begin
          textcolor(adjColor(n));
          write(' '); write(n); write(' ');
        end;
      end;
      textcolor(7);
    end;
    writeln;
  end;

  writeln;
  textcolor(11);
  write('  Flags: '); write(flagCount); write(' / '); write(MINES);
  write('     Safe revealed: '); write(safeRevealed); write(' / '); writeln(totalSafe);
  textcolor(14);
  write('  Command (r c / f r c / h / q): ');
  textcolor(7);
end;

{ Flood-fill reveal }
procedure doReveal(rr, cc : integer);
begin
  if (rr < 1) or (rr > ROWS) or (cc < 1) or (cc > COLS) then exit;
  if revealed[rr, cc] or flagged[rr, cc] then exit;
  revealed[rr, cc] := true;
  if not bomb[rr, cc] then
    safeRevealed := safeRevealed + 1;
  if (not bomb[rr, cc]) and (adj[rr, cc] = 0) then
  begin
    doReveal(rr-1, cc-1); doReveal(rr-1, cc); doReveal(rr-1, cc+1);
    doReveal(rr,   cc-1);                      doReveal(rr,   cc+1);
    doReveal(rr+1, cc-1); doReveal(rr+1, cc);  doReveal(rr+1, cc+1);
  end;
end;

{ Parse one integer from string starting at position pos, advance pos }
function parseInt(s : string) : integer;
var n : integer;
begin
  while (parsePos <= length(s)) and (s[parsePos] = ' ') do
    parsePos := parsePos + 1;
  n := 0;
  while (parsePos <= length(s)) and (s[parsePos] >= '0') and (s[parsePos] <= '9') do
  begin
    n   := n * 10 + ord(s[parsePos]) - ord('0');
    parsePos := parsePos + 1;
  end;
  parseInt := n;
end;

begin
  answer := 'y';
  while answer = 'y' do
  begin
    randomize;
    for r := 1 to ROWS do
      for c := 1 to COLS do
      begin
        bomb[r, c]     := false;
        revealed[r, c] := false;
        flagged[r, c]  := false;
      end;

    bombCount := 0;
    while bombCount < MINES do
    begin
      r := random(ROWS) + 1;
      c := random(COLS) + 1;
      if not bomb[r, c] then
      begin
        bomb[r, c] := true;
        bombCount  := bombCount + 1;
      end;
    end;

    placeAdjacency;
    totalSafe    := ROWS * COLS - MINES;
    safeRevealed := 0;
    flagCount    := 0;
    gameOver     := false;
    won          := false;

    showHelp;

    while not gameOver do
    begin
      drawBoard(false);
      readln(cmd);

      if (length(cmd) >= 1) and ((cmd[1] = 'q') or (cmd[1] = 'Q')) then
        gameOver := true

      else if (length(cmd) >= 1) and ((cmd[1] = 'h') or (cmd[1] = 'H')) then
        showHelp

      else if (length(cmd) >= 1) and ((cmd[1] = 'f') or (cmd[1] = 'F')) then
      begin
        parsePos := 2;
        r   := parseInt(cmd);
        c   := parseInt(cmd);
        if (r >= 1) and (r <= ROWS) and (c >= 1) and (c <= COLS) then
        begin
          if not revealed[r, c] then
          begin
            if flagged[r, c] then
            begin
              flagged[r, c] := false;
              flagCount := flagCount - 1;
            end
            else
            begin
              flagged[r, c] := true;
              flagCount := flagCount + 1;
            end;
          end;
        end
        else
        begin
          drawBoard(false);
          textcolor(12);
          writeln;
          writeln('  Invalid position. Rows 1-', ROWS, ', cols 1-', COLS, '.');
          textcolor(7);
          delay(1200);
        end;
      end

      else
      begin
        parsePos := 1;
        r   := parseInt(cmd);
        c   := parseInt(cmd);
        if (r >= 1) and (r <= ROWS) and (c >= 1) and (c <= COLS) then
        begin
          if revealed[r, c] then
          begin
            { already revealed - ignore silently }
          end
          else if bomb[r, c] then
          begin
            revealed[r, c] := true;
            gameOver := true;
            won := false;
          end
          else
          begin
            doReveal(r, c);
            if safeRevealed = totalSafe then
            begin
              gameOver := true;
              won := true;
            end;
          end;
        end
        else
        begin
          drawBoard(false);
          textcolor(12);
          writeln;
          writeln('  Unknown command. Type h for help.');
          textcolor(7);
          delay(1200);
        end;
      end;
    end;

    if not ((length(cmd) >= 1) and ((cmd[1] = 'q') or (cmd[1] = 'Q'))) then
    begin
      drawBoard(not won);
      writeln;
      if won then
      begin
        textcolor(10);
        writeln('  YOU WIN! All safe cells revealed!');
      end
      else
      begin
        textcolor(12);
        writeln('  BOOM! You revealed a bomb!');
      end;
      textcolor(7);
    end;

    writeln;
    write('  Play again? (y/n) ');
    readln(answer);
  end;

  writeln;
  textcolor(11);
  writeln('  Thanks for playing BombField!');
  textcolor(7);
end.
