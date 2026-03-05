{ TicTacToe – player (X) vs minimax AI (O)
  The AI never loses. See if you can force a draw! }
program tictactoe;

var
  board  : array[1..9] of integer;  { 0=empty 1=X 2=O }
  move, winner, score, best, bestMove : integer;
  i : integer;
  gameOver : boolean;
  answer : char;

procedure drawBoard;
var r, c, idx, val : integer;
begin
  clrscr;
  textcolor(14);
  writeln('  TicTacToe  –  You are X, Computer is O');
  textcolor(7);
  writeln('  Positions: 1 2 3 / 4 5 6 / 7 8 9');
  writeln;
  for r := 0 to 2 do
  begin
    write('  ');
    for c := 0 to 2 do
    begin
      idx := r * 3 + c + 1;
      val := board[idx];
      if val = 1 then
      begin
        textcolor(10);
        write('X');
      end
      else if val = 2 then
      begin
        textcolor(12);
        write('O');
      end
      else
      begin
        textcolor(8);
        write(idx);
      end;
      textcolor(7);
      if c < 2 then write('|');
    end;
    writeln;
    if r < 2 then writeln('  -+-+-');
  end;
  writeln;
end;

function checkWinner : integer;
var wins : array[1..8, 1..3] of integer;
    k, p, w : integer;
begin
  wins[1,1]:=1; wins[1,2]:=2; wins[1,3]:=3;
  wins[2,1]:=4; wins[2,2]:=5; wins[2,3]:=6;
  wins[3,1]:=7; wins[3,2]:=8; wins[3,3]:=9;
  wins[4,1]:=1; wins[4,2]:=4; wins[4,3]:=7;
  wins[5,1]:=2; wins[5,2]:=5; wins[5,3]:=8;
  wins[6,1]:=3; wins[6,2]:=6; wins[6,3]:=9;
  wins[7,1]:=1; wins[7,2]:=5; wins[7,3]:=9;
  wins[8,1]:=3; wins[8,2]:=5; wins[8,3]:=7;

  checkWinner := 0;
  for k := 1 to 8 do
  begin
    p := board[wins[k,1]];
    if (p <> 0) and (p = board[wins[k,2]]) and (p = board[wins[k,3]]) then
      checkWinner := p;
  end;
end;

function boardFull : boolean;
var k : integer;
begin
  boardFull := true;
  for k := 1 to 9 do
    if board[k] = 0 then boardFull := false;
end;

{ Minimax – player 2 (O) maximises, player 1 (X) minimises }
function minimax(depth, player : integer) : integer;
var
  w, k, s, best2 : integer;
begin
  w := checkWinner;
  if w = 2 then begin minimax :=  10 - depth; exit; end;
  if w = 1 then begin minimax := -10 + depth; exit; end;
  if boardFull   then begin minimax := 0; exit; end;

  if player = 2 then
  begin
    best2 := -99;
    for k := 1 to 9 do
      if board[k] = 0 then
      begin
        board[k] := 2;
        s := minimax(depth + 1, 1);
        board[k] := 0;
        if s > best2 then best2 := s;
      end;
    minimax := best2;
  end
  else
  begin
    best2 := 99;
    for k := 1 to 9 do
      if board[k] = 0 then
      begin
        board[k] := 1;
        s := minimax(depth + 1, 2);
        board[k] := 0;
        if s < best2 then best2 := s;
      end;
    minimax := best2;
  end;
end;

procedure computerMove;
var k, s : integer;
begin
  best     := -99;
  bestMove := 0;
  for k := 1 to 9 do
    if board[k] = 0 then
    begin
      board[k] := 2;
      s := minimax(0, 1);
      board[k] := 0;
      if s > best then
      begin
        best     := s;
        bestMove := k;
      end;
    end;
  board[bestMove] := 2;
end;

begin
  answer := 'y';
  while answer = 'y' do
  begin
    for i := 1 to 9 do
      board[i] := 0;

    gameOver := false;

    while not gameOver do
    begin
      drawBoard;

      winner := checkWinner;
      if (winner <> 0) or boardFull then
        gameOver := true
      else
      begin
        { player move }
        textcolor(14);
        write('  Your move (1-9): ');
        textcolor(7);
        readln(move);

        if (move >= 1) and (move <= 9) and (board[move] = 0) then
        begin
          board[move] := 1;
          winner := checkWinner;
          if (winner <> 0) or boardFull then
            gameOver := true
          else
          begin
            computerMove;
          end;
        end
        else
        begin
          textcolor(12);
          writeln('  Invalid move. Try again.');
          textcolor(7);
          delay(700);
        end;
      end;
    end;

    drawBoard;
    winner := checkWinner;

    if winner = 1 then
    begin
      textcolor(10);
      writeln('  You win! (how?)');
    end
    else if winner = 2 then
    begin
      textcolor(12);
      writeln('  Computer wins!');
    end
    else
    begin
      textcolor(11);
      writeln('  Draw! Well played.');
    end;
    textcolor(7);

    writeln;
    write('  Play again? (y/n) ');
    readln(answer);
  end;

  writeln;
  textcolor(11);
  writeln('  Thanks for playing!');
  textcolor(7);
end.
