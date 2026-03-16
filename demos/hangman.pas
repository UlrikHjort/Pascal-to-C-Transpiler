{ Hangman - guess the word before the man is hanged
  6 wrong guesses allowed; ASCII gallows shows progress }
program hangman;

const
  MAXWRONG = 6;
  WCOUNT   = 40;

var
  words   : array[1..WCOUNT] of string[12];
  secret  : string[12];
  guessed : array[1..26] of boolean;
  wrong   : integer;
  i, j, wi : integer;
  ch       : char;
  answer   : char;
  won, lost, found : boolean;
  allFound : boolean;

procedure initWords;
begin
  words[1]  := 'elephant';   words[2]  := 'keyboard';
  words[3]  := 'journal';    words[4]  := 'mystery';
  words[5]  := 'volcano';    words[6]  := 'blanket';
  words[7]  := 'compass';    words[8]  := 'lantern';
  words[9]  := 'pyramid';    words[10] := 'crystal';
  words[11] := 'thunder';    words[12] := 'penguin';
  words[13] := 'cabinet';    words[14] := 'dolphin';
  words[15] := 'emperor';    words[16] := 'factory';
  words[17] := 'giraffe';    words[18] := 'harvest';
  words[19] := 'integer';    words[20] := 'kitchen';
  words[21] := 'leopard';    words[22] := 'mercury';
  words[23] := 'network';    words[24] := 'octopus';
  words[25] := 'pilgrim';    words[26] := 'quarter';
  words[27] := 'rainbow';    words[28] := 'sandbox';
  words[29] := 'tractor';    words[30] := 'uniform';
  words[31] := 'village';    words[32] := 'western';
  words[33] := 'yoghurt';    words[34] := 'zipper';
  words[35] := 'avocado';    words[36] := 'buffalo';
  words[37] := 'cactus';     words[38] := 'diamond';
  words[39] := 'eclipse';    words[40] := 'flamingo';
end;

procedure drawGallows(w : integer);
begin
  gotoxy(2, 3);  textcolor(8);
  writeln('  +---+  ');
  write('  |   ');
  if w >= 1 then begin textcolor(15); write('O'); end else write(' ');
  textcolor(8); writeln('  ');
  write('  |  ');
  if w >= 3 then begin textcolor(15); write('/'); end else write(' ');
  if w >= 2 then begin textcolor(15); write('|'); end else write(' ');
  if w >= 4 then begin textcolor(15); write(chr(92)); end else write(' ');
  textcolor(8); writeln(' ');
  write('  |  ');
  if w >= 5 then begin textcolor(15); write('/'); end else write(' ');
  write(' ');
  if w >= 6 then begin textcolor(15); write(chr(92)); end else write(' ');
  textcolor(8); writeln(' ');
  writeln('  |       ');
  writeln(' _|_      ');
  textcolor(7);
end;

procedure drawWord;
var k : integer;
begin
  gotoxy(2, 11);
  textcolor(14);
  write('  Word: ');
  for k := 1 to length(secret) do
  begin
    if guessed[ord(secret[k]) - ord('a') + 1] then
    begin
      textcolor(10);
      write(secret[k]);
    end
    else
    begin
      textcolor(8);
      write('_');
    end;
    write(' ');
    textcolor(7);
  end;
  writeln;
end;

procedure drawGuessed;
var k : integer;
begin
  gotoxy(2, 13);
  textcolor(11);
  write('  Wrong guesses: ');
  for k := 1 to 26 do
    if guessed[k] then
    begin
      ch := chr(k + ord('a') - 1);
      if secret[1] = 'X' then  { never true - just reference secret }
        write('?');
      { check if letter is in word }
      found := false;
      for j := 1 to length(secret) do
        if secret[j] = ch then found := true;
      if not found then
      begin
        textcolor(12);
        write(ch);
        write(' ');
        textcolor(11);
      end;
    end;
  writeln;
  textcolor(7);
end;

begin
  randomize;
  initWords;

  answer := 'y';
  while answer = 'y' do
  begin
    for i := 1 to 26 do guessed[i] := false;
    wi     := random(WCOUNT) + 1;
    secret := words[wi];
    wrong  := 0;
    won    := false;
    lost   := false;

    while not won and not lost do
    begin
      clrscr;
      textcolor(14);
      gotoxy(2, 1);
      write('  === Hangman ===   (');
      write(MAXWRONG - wrong);
      writeln(' chances left)');
      drawGallows(wrong);
      drawWord;
      drawGuessed;

      gotoxy(2, 15);
      textcolor(14);
      write('  Guess a letter: ');
      textcolor(7);
      readln(ch);

      { lowercase }
      if (ch >= 'A') and (ch <= 'Z') then
        ch := chr(ord(ch) + 32);

      if (ch < 'a') or (ch > 'z') then
      begin
        { ignore non-letters }
      end
      else
      begin
        i := ord(ch) - ord('a') + 1;
        if guessed[i] then
        begin
          { already guessed }
        end
        else
        begin
          guessed[i] := true;
          { check if in word }
          found := false;
          for j := 1 to length(secret) do
            if secret[j] = ch then found := true;
          if not found then
            wrong := wrong + 1;
        end;
      end;

      { Check win }
      allFound := true;
      for j := 1 to length(secret) do
        if not guessed[ord(secret[j]) - ord('a') + 1] then
          allFound := false;
      if allFound then won := true;
      if wrong >= MAXWRONG then lost := true;
    end;

    clrscr;
    drawGallows(wrong);
    gotoxy(2, 11);

    if won then
    begin
      textcolor(10);
      writeln('  You got it! The word was: ', secret);
    end
    else
    begin
      textcolor(12);
      writeln('  Game over! The word was: ', secret);
    end;
    textcolor(7);

    writeln;
    write('  Play again? (y/n): ');
    readln(answer);
  end;
end.
