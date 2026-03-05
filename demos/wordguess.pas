{ WordGuess – a Wordle-style 5-letter word game
  Green  = correct letter, correct position
  Yellow = correct letter, wrong position
  Gray   = letter not in word }
program wordguess;

const
  WCOUNT = 50;
  WLEN   = 5;
  MAXGUESSES = 6;

var
  words   : array[1..WCOUNT] of string[5];
  secret  : string[5];
  guess   : string[5];
  used    : array[1..MAXGUESSES] of string[5];
  result  : array[1..WLEN] of integer;  { 2=green 1=yellow 0=gray }
  inWord  : array[1..WLEN] of boolean;
  matched : array[1..WLEN] of boolean;
  nGuesses, attempt, i, j, wi : integer;
  won : boolean;
  ch  : char;
  letterUsed : array[1..26] of integer;  { 0=unused 1=gray 2=yellow 3=green }
  li  : integer;

procedure initWords;
begin
  words[1]  := 'apple'; words[2]  := 'brave'; words[3]  := 'chair';
  words[4]  := 'drink'; words[5]  := 'earth'; words[6]  := 'flame';
  words[7]  := 'grace'; words[8]  := 'house'; words[9]  := 'index';
  words[10] := 'joker'; words[11] := 'knack'; words[12] := 'light';
  words[13] := 'mango'; words[14] := 'nerve'; words[15] := 'ocean';
  words[16] := 'paint'; words[17] := 'queen'; words[18] := 'raven';
  words[19] := 'sweet'; words[20] := 'tiger'; words[21] := 'ultra';
  words[22] := 'vital'; words[23] := 'water'; words[24] := 'xenon';
  words[25] := 'youth'; words[26] := 'zebra'; words[27] := 'angle';
  words[28] := 'brick'; words[29] := 'crane'; words[30] := 'dusk';
  words[31] := 'elbow'; words[32] := 'frost'; words[33] := 'gavel';
  words[34] := 'haste'; words[35] := 'ivory'; words[36] := 'jelly';
  words[37] := 'karma'; words[38] := 'lunar'; words[39] := 'maple';
  words[40] := 'noble'; words[41] := 'onset'; words[42] := 'plank';
  words[43] := 'quirk'; words[44] := 'risky'; words[45] := 'stone';
  words[46] := 'trend'; words[47] := 'umbra'; words[48] := 'vivid';
  words[49] := 'witch'; words[50] := 'yield';
end;

function isValidGuess(s : string) : boolean;
var k : integer;
begin
  if length(s) <> WLEN then
  begin
    isValidGuess := false;
    exit;
  end;
  isValidGuess := true;
  for k := 1 to WLEN do
    if (s[k] < 'a') or (s[k] > 'z') then
      isValidGuess := false;
end;

procedure printLetterColor(c : char; col : integer);
begin
  case col of
    3 : begin
          write(chr(27));
          write('[42m');   { green bg }
          write(chr(27));
          write('[30m');   { black fg }
        end;
    2 : begin
          write(chr(27));
          write('[43m');   { yellow bg }
          write(chr(27));
          write('[30m');
        end;
    1 : begin
          write(chr(27));
          write('[100m');  { dark gray bg }
          write(chr(27));
          write('[37m');   { white fg }
        end;
  else
    begin
      write(chr(27));
      write('[7m');        { reverse video for unknown }
      write(chr(27));
      write('[37m');
    end;
  end;
  write(' ');
  write(c);
  write(' ');
  write(chr(27));
  write('[0m');
end;

procedure printRow(g : string);
var k : integer;
begin
  write('  ');
  for k := 1 to WLEN do
    printLetterColor(g[k], result[k]);
  writeln;
end;

procedure printKeyboard;
var
  row1, row2, row3 : string;
  k, idx, st : integer;
begin
  row1 := 'qwertyuiop';
  row2 := 'asdfghjkl';
  row3 := 'zxcvbnm';
  writeln;
  write('  ');
  for k := 1 to length(row1) do
  begin
    idx := ord(row1[k]) - ord('a') + 1;
    st := letterUsed[idx];
    if st = 0 then
      write(row1[k])
    else
    begin
      if st = 3 then
      begin
        write(chr(27)); write('[32m');
      end
      else if st = 2 then
      begin
        write(chr(27)); write('[33m');
      end
      else
      begin
        write(chr(27)); write('[90m');
      end;
      write(row1[k]);
      write(chr(27)); write('[0m');
    end;
    write(' ');
  end;
  writeln;
  write('   ');
  for k := 1 to length(row2) do
  begin
    idx := ord(row2[k]) - ord('a') + 1;
    st := letterUsed[idx];
    if st = 0 then
      write(row2[k])
    else
    begin
      if st = 3 then
      begin
        write(chr(27)); write('[32m');
      end
      else if st = 2 then
      begin
        write(chr(27)); write('[33m');
      end
      else
      begin
        write(chr(27)); write('[90m');
      end;
      write(row2[k]);
      write(chr(27)); write('[0m');
    end;
    write(' ');
  end;
  writeln;
  write('    ');
  for k := 1 to length(row3) do
  begin
    idx := ord(row3[k]) - ord('a') + 1;
    st := letterUsed[idx];
    if st = 0 then
      write(row3[k])
    else
    begin
      if st = 3 then
      begin
        write(chr(27)); write('[32m');
      end
      else if st = 2 then
      begin
        write(chr(27)); write('[33m');
      end
      else
      begin
        write(chr(27)); write('[90m');
      end;
      write(row3[k]);
      write(chr(27)); write('[0m');
    end;
    write(' ');
  end;
  writeln;
end;

procedure evalGuess;
var k, m : integer;
begin
  { Init }
  for k := 1 to WLEN do
  begin
    result[k]  := 0;
    inWord[k]  := false;
    matched[k] := false;
  end;

  { Pass 1: mark greens }
  for k := 1 to WLEN do
    if guess[k] = secret[k] then
    begin
      result[k]  := 3;
      matched[k] := true;
      inWord[k]  := true;
    end;

  { Pass 2: mark yellows }
  for k := 1 to WLEN do
    if result[k] <> 3 then
    begin
      m := 1;
      while m <= WLEN do
      begin
        if (secret[m] = guess[k]) and not matched[m] then
        begin
          result[k]  := 2;
          inWord[k]  := true;
          matched[m] := true;
          m := WLEN + 1;  { break }
        end
        else
          m := m + 1;
      end;
    end;

  { Update keyboard state }
  for k := 1 to WLEN do
  begin
    li := ord(guess[k]) - ord('a') + 1;
    if (li >= 1) and (li <= 26) then
    begin
      if result[k] > letterUsed[li] then
        letterUsed[li] := result[k];
    end;
  end;
end;

begin
  randomize;
  initWords;

  for i := 1 to 26 do
    letterUsed[i] := 0;

  wi     := random(WCOUNT) + 1;
  secret := words[wi];
  nGuesses := 0;
  won := false;

  clrscr;
  writeln;
  textcolor(14);
  writeln('  *** WordGuess ***');
  textcolor(7);
  writeln('  Guess the 5-letter word in 6 tries.');
  writeln('  Green=right spot  Yellow=wrong spot  Gray=not in word');
  writeln;

  while (nGuesses < MAXGUESSES) and not won do
  begin
    write('  Guess ', nGuesses + 1, '/6: ');
    readln(guess);

    { lowercase the input }
    for i := 1 to length(guess) do
      if (guess[i] >= 'A') and (guess[i] <= 'Z') then
        guess[i] := chr(ord(guess[i]) + 32);

    if not isValidGuess(guess) then
    begin
      textcolor(12);
      writeln('  Please enter exactly 5 lowercase letters.');
      textcolor(7);
    end
    else
    begin
      nGuesses := nGuesses + 1;
      evalGuess;
      printRow(guess);

      { check win }
      won := true;
      for i := 1 to WLEN do
        if result[i] <> 3 then
          won := false;

      printKeyboard;
      writeln;
    end;
  end;

  if won then
  begin
    textcolor(10);
    writeln('  Brilliant! You got it in ', nGuesses, ' guess(es)!');
    textcolor(7);
  end
  else
  begin
    textcolor(12);
    writeln('  Hard luck! The word was: ', secret);
    textcolor(7);
  end;

  writeln;
end.
