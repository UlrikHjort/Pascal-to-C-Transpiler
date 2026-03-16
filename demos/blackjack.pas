{ Blackjack - card game vs dealer, standard rules }
program blackjack;

const
  DECKSIZE = 52;

var
  deck      : array[1..DECKSIZE] of integer;
  deckpos   : integer;
  phand     : array[1..10] of integer;
  dhand     : array[1..10] of integer;
  pcount, dcount : integer;
  chips, bet : integer;
  i, j, tmp  : integer;
  answer     : char;
  ch         : char;

function cardValue(c : integer) : integer;
var face : integer;
begin
  face := ((c - 1) mod 13) + 1;
  if face > 10 then cardValue := 10
  else cardValue := face;
end;

function cardName(c : integer) : string;
var face, suit : integer;
    nm : string[8];
    suitSym : string[2];
begin
  face := ((c - 1) mod 13) + 1;
  suit := (c - 1) div 13;
  if face = 1  then nm := 'A'
  else if face = 11 then nm := 'J'
  else if face = 12 then nm := 'Q'
  else if face = 13 then nm := 'K'
  else nm := inttostr(face);
  case suit of
    0: suitSym := 'H';   { hearts }
    1: suitSym := 'D';   { diamonds }
    2: suitSym := 'C';   { clubs }
  else suitSym := 'S';   { spades }
  end;
  cardName := nm + suitSym;
end;

procedure shuffle;
var k : integer;
begin
  for i := 1 to DECKSIZE do deck[i] := i;
  for i := DECKSIZE downto 2 do
  begin
    j   := random(i) + 1;
    tmp := deck[i];
    deck[i] := deck[j];
    deck[j] := tmp;
  end;
  deckpos := 1;
end;

function deal : integer;
begin
  deal    := deck[deckpos];
  deckpos := deckpos + 1;
  if deckpos > DECKSIZE then shuffle;
end;

function handScore(hand : array[1..10] of integer; n : integer) : integer;
var score, aces, k : integer;
begin
  score := 0; aces := 0;
  for k := 1 to n do
  begin
    score := score + cardValue(hand[k]);
    if ((hand[k] - 1) mod 13) = 0 then aces := aces + 1;
  end;
  while (score > 21) and (aces > 0) do
  begin
    score := score - 10;
    aces  := aces - 1;
  end;
  handScore := score;
end;

procedure showHand(hand : array[1..10] of integer; n, hideFirst : integer);
var k : integer;
begin
  if (hideFirst = 1) and (n >= 1) then
  begin
    textcolor(8);
    write('[??] ');
    for k := 2 to n do
    begin
      textcolor(14);
      write('['); write(cardName(hand[k])); write('] ');
    end;
  end
  else
    for k := 1 to n do
    begin
      textcolor(14);
      write('['); write(cardName(hand[k])); write('] ');
    end;
  textcolor(7);
end;

procedure showTable(hideDealer : integer);
var ps, ds : integer;
begin
  clrscr;
  textcolor(11);
  write('  Chips: '); write(chips);
  write('   Bet: '); write(bet);
  writeln;
  writeln;
  textcolor(13);
  write('  Dealer: ');
  showHand(dhand, dcount, hideDealer);
  if hideDealer = 0 then
  begin
    ds := handScore(dhand, dcount);
    textcolor(8); write(' ('); write(ds); write(')');
  end;
  writeln;
  writeln;
  textcolor(10);
  write('  You:    ');
  showHand(phand, pcount, 0);
  ps := handScore(phand, pcount);
  textcolor(8); write(' ('); write(ps); write(')');
  writeln;
  writeln;
  textcolor(7);
end;

begin
  randomize;
  shuffle;
  chips := 200;

  answer := 'y';
  while (answer = 'y') and (chips > 0) do
  begin
    { get bet }
    clrscr;
    textcolor(11);
    write('  Chips: '); write(chips); writeln;
    textcolor(14);
    write('  Bet (1-');
    if chips > 50 then write(50) else write(chips);
    write('): ');
    textcolor(7);
    readln(bet);
    if bet < 1 then bet := 1;
    if bet > 50 then bet := 50;
    if bet > chips then bet := chips;

    { deal }
    pcount := 0; dcount := 0;
    pcount := pcount + 1; phand[pcount] := deal;
    dcount := dcount + 1; dhand[dcount] := deal;
    pcount := pcount + 1; phand[pcount] := deal;
    dcount := dcount + 1; dhand[dcount] := deal;

    { player turn }
    ch := 'h';
    while ch = 'h' do
    begin
      showTable(1);
      if handScore(phand, pcount) = 21 then
      begin
        textcolor(10); writeln('  Blackjack!'); textcolor(7);
        ch := 's';
      end
      else if handScore(phand, pcount) > 21 then
      begin
        textcolor(12); writeln('  Bust!'); textcolor(7);
        ch := 'b';
      end
      else
      begin
        write('  (h)it / (s)tand: ');
        readln(ch);
        if ch = 'h' then
        begin
          pcount := pcount + 1;
          phand[pcount] := deal;
        end;
      end;
    end;

    { dealer turn }
    if ch <> 'b' then
    begin
      while handScore(dhand, dcount) < 17 do
      begin
        dcount := dcount + 1;
        dhand[dcount] := deal;
      end;
    end;

    showTable(0);

    { result }
    i := handScore(phand, pcount);
    j := handScore(dhand, dcount);

    if ch = 'b' then
    begin
      textcolor(12); writeln('  You bust. Dealer wins.'); textcolor(7);
      chips := chips - bet;
    end
    else if j > 21 then
    begin
      textcolor(10); writeln('  Dealer busts. You win!'); textcolor(7);
      chips := chips + bet;
    end
    else if i > j then
    begin
      textcolor(10); writeln('  You win!'); textcolor(7);
      chips := chips + bet;
    end
    else if i < j then
    begin
      textcolor(12); writeln('  Dealer wins.'); textcolor(7);
      chips := chips - bet;
    end
    else
    begin
      textcolor(11); writeln('  Push (tie).'); textcolor(7);
    end;

    writeln;
    if chips <= 0 then
    begin
      textcolor(12); writeln('  Out of chips!'); textcolor(7);
      answer := 'n';
    end
    else
    begin
      write('  Play another hand? (y/n): ');
      readln(answer);
    end;
  end;

  writeln;
  textcolor(14);
  write('  Final chips: '); write(chips); writeln;
  textcolor(7);
end.
