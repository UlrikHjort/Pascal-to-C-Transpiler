{ Nim - take stones from heaps; player who takes the last stone wins.
  Computer plays the optimal strategy using XOR (nim-sum). }
program nim;

const
  NHEAPS = 4;

var
  heaps : array[1..NHEAPS] of integer;
  nimSum, h, take, best, bestH, bestT : integer;
  playerTurn : boolean;
  gameOver   : boolean;
  i, j       : integer;
  ch         : char;
  answer     : char;

procedure drawHeaps;
var row, col : integer;
begin
  writeln;
  textcolor(14);
  writeln('  === NIM ===');
  textcolor(7);
  writeln('  Take any number of stones from one heap.');
  writeln('  Player who takes the last stone WINS.');
  writeln;
  for i := 1 to NHEAPS do
  begin
    textcolor(11);
    write('  Heap ');
    write(i);
    write(': ');
    textcolor(10);
    for j := 1 to heaps[i] do
      write('O ');
    textcolor(8);
    write('[');
    write(heaps[i]);
    writeln(']');
  end;
  textcolor(7);
  writeln;
end;

function calcNimSum : integer;
var ns, k : integer;
begin
  ns := 0;
  for k := 1 to NHEAPS do
    ns := ns xor heaps[k];
  calcNimSum := ns;
end;

{ Find computer's optimal move }
procedure computerMove;
var k, t, ns : integer;
begin
  nimSum := calcNimSum;
  bestH := 0; bestT := 0;

  if nimSum = 0 then
  begin
    { losing position - just take 1 from largest heap }
    best := 0;
    for k := 1 to NHEAPS do
      if heaps[k] > best then
      begin
        best  := heaps[k];
        bestH := k;
      end;
    bestT := 1;
  end
  else
  begin
    { find a heap where heaps[k] XOR nimSum < heaps[k] }
    for k := 1 to NHEAPS do
    begin
      t := heaps[k] xor nimSum;
      if t < heaps[k] then
      begin
        bestH := k;
        bestT := heaps[k] - t;
      end;
    end;
  end;

  heaps[bestH] := heaps[bestH] - bestT;

  textcolor(13);
  write('  Computer takes ');
  write(bestT);
  write(' from heap ');
  write(bestH);
  writeln('.');
  textcolor(7);
end;

function allEmpty : boolean;
var k : integer;
begin
  allEmpty := true;
  for k := 1 to NHEAPS do
    if heaps[k] > 0 then
      allEmpty := false;
end;

begin
  answer := 'y';
  while answer = 'y' do
  begin
    { set up heaps }
    randomize;
    heaps[1] := random(7) + 1;
    heaps[2] := random(7) + 1;
    heaps[3] := random(7) + 1;
    heaps[4] := random(7) + 1;

    playerTurn := true;
    gameOver   := false;

    clrscr;
    drawHeaps;

    write('  Do you want to go first? (y/n) ');
    readln(ch);
    playerTurn := (ch = 'y') or (ch = 'Y');
    writeln;

    while not gameOver do
    begin
      clrscr;
      drawHeaps;

      if allEmpty then
      begin
        gameOver := true;
        if playerTurn then
        begin
          { computer just took last stone = computer won }
          textcolor(12);
          writeln('  Computer took the last stone. Computer wins!');
        end
        else
        begin
          textcolor(10);
          writeln('  You took the last stone. YOU WIN!');
        end;
        textcolor(7);
      end
      else if playerTurn then
      begin
        { player move }
        textcolor(14);
        write('  Choose heap (1-');
        write(NHEAPS);
        write('): ');
        textcolor(7);
        readln(h);

        if (h < 1) or (h > NHEAPS) or (heaps[h] = 0) then
        begin
          textcolor(12);
          writeln('  Invalid choice.');
          textcolor(7);
          delay(800);
        end
        else
        begin
          textcolor(14);
          write('  How many to take (1-');
          write(heaps[h]);
          write(')? ');
          textcolor(7);
          readln(take);

          if (take < 1) or (take > heaps[h]) then
          begin
            textcolor(12);
            writeln('  Invalid amount.');
            textcolor(7);
            delay(800);
          end
          else
          begin
            heaps[h] := heaps[h] - take;
            playerTurn := false;
          end;
        end;
      end
      else
      begin
        { computer move }
        computerMove;
        delay(1000);
        playerTurn := true;
      end;
    end;

    writeln;
    write('  Play again? (y/n) ');
    readln(answer);
    writeln;
  end;

  textcolor(11);
  writeln('  Thanks for playing Nim!');
  textcolor(7);
end.
