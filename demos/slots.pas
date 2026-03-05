{ Slots – one-armed bandit with 3 reels and paylines }
program slots;

const
  NSYMBOLS = 6;
  CREDITS_START = 100;

var
  symbols : array[1..NSYMBOLS] of string[4];
  colors  : array[1..NSYMBOLS] of integer;
  reels   : array[1..3] of integer;
  credits : integer;
  bet, win, i : integer;
  answer  : char;
  spinning : boolean;

procedure drawMachine;
begin
  clrscr;
  textcolor(14);
  writeln('  *** LUCKY SLOTS ***');
  textcolor(8);
  writeln('  +-------+-------+-------+');
  write('  |  ');
  textcolor(colors[reels[1]]); write(symbols[reels[1]]);
  textcolor(8); write('  |  ');
  textcolor(colors[reels[2]]); write(symbols[reels[2]]);
  textcolor(8); write('  |  ');
  textcolor(colors[reels[3]]); write(symbols[reels[3]]);
  textcolor(8); writeln('  |');
  writeln('  +-------+-------+-------+');
  textcolor(7);
  writeln;
  textcolor(11);
  write('  Credits: '); write(credits);
  textcolor(7);
  writeln;
end;

function calcWin(b : integer) : integer;
var r1, r2, r3 : integer;
begin
  r1 := reels[1]; r2 := reels[2]; r3 := reels[3];
  if (r1 = r2) and (r2 = r3) then
  begin
    { Jackpot! }
    case r1 of
      1: calcWin := b * 50;   { 7s }
      2: calcWin := b * 20;   { $ }
      3: calcWin := b * 10;   { * }
      4: calcWin := b * 7;    { # }
      5: calcWin := b * 5;    { @ }
      6: calcWin := b * 3;    { + }
    else calcWin := b * 2;
    end;
  end
  else if (r1 = r2) or (r2 = r3) or (r1 = r3) then
    calcWin := b * 2   { any pair }
  else
    calcWin := 0;
end;

begin
  symbols[1] := ' 7 '; symbols[2] := ' $ ';
  symbols[3] := ' * '; symbols[4] := ' # ';
  symbols[5] := ' @ '; symbols[6] := ' + ';

  colors[1] := 14; colors[2] := 10;
  colors[3] := 13; colors[4] := 11;
  colors[5] := 12; colors[6] :=  7;

  randomize;
  credits := CREDITS_START;

  answer := 'y';
  while (answer = 'y') and (credits > 0) do
  begin
    reels[1] := random(NSYMBOLS) + 1;
    reels[2] := random(NSYMBOLS) + 1;
    reels[3] := random(NSYMBOLS) + 1;

    drawMachine;

    if credits = 0 then
    begin
      textcolor(12);
      writeln('  Out of credits!');
      textcolor(7);
      answer := 'n';
    end
    else
    begin
      textcolor(14);
      write('  Bet (1-');
      if credits < 10 then write(credits) else write(10);
      write(', 0=quit): ');
      textcolor(7);
      readln(bet);

      if bet = 0 then
        answer := 'n'
      else
      begin
        if bet < 1 then bet := 1;
        if bet > 10 then bet := 10;
        if bet > credits then bet := credits;

        credits := credits - bet;

        { Spin! }
        for i := 1 to 8 do
        begin
          reels[1] := random(NSYMBOLS) + 1;
          reels[2] := random(NSYMBOLS) + 1;
          reels[3] := random(NSYMBOLS) + 1;
          drawMachine;
          textcolor(8); write('  Spinning...');
          delay(80);
        end;

        reels[1] := random(NSYMBOLS) + 1;
        reels[2] := random(NSYMBOLS) + 1;
        reels[3] := random(NSYMBOLS) + 1;

        win := calcWin(bet);
        credits := credits + win;

        drawMachine;

        if win > 0 then
        begin
          textcolor(10);
          if (reels[1] = reels[2]) and (reels[2] = reels[3]) then
          begin
            write('  *** JACKPOT ***  Won: ');
            write(win);
            writeln(' credits!');
          end
          else
          begin
            write('  Pair! Won: ');
            write(win);
            writeln(' credits.');
          end;
        end
        else
        begin
          textcolor(12);
          writeln('  No win this time.');
        end;
        textcolor(7);
        writeln;

        if credits > 0 then
        begin
          write('  Spin again? (y/n): ');
          readln(answer);
        end;
      end;
    end;
  end;

  writeln;
  textcolor(11);
  write('  Final credits: ');
  write(credits);
  if credits > CREDITS_START then
  begin
    textcolor(10);
    writeln('  -- You beat the house!');
  end
  else if credits = 0 then
  begin
    textcolor(12);
    writeln('  -- Broke!');
  end
  else
  begin
    textcolor(8);
    writeln;
  end;
  textcolor(7);
end.
