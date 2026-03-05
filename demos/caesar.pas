{ Caesar cipher – encode and decode msg with a shift key }
program caesar;

var
  msg  : string[200];
  shift : integer;
  i, k  : integer;
  ch    : char;
  answer: char;
  mode  : char;

function encodeChar(c : char; s : integer) : char;
var n : integer;
begin
  if (c >= 'a') and (c <= 'z') then
    encodeChar := chr((ord(c) - ord('a') + s + 26) mod 26 + ord('a'))
  else if (c >= 'A') and (c <= 'Z') then
    encodeChar := chr((ord(c) - ord('A') + s + 26) mod 26 + ord('A'))
  else
    encodeChar := c;
end;

begin
  answer := 'y';
  while answer = 'y' do
  begin
    clrscr;
    textcolor(14);
    writeln('  === Caesar Cipher ===');
    textcolor(7);
    writeln;

    write('  Encode or decode? (e/d): ');
    readln(mode);
    writeln;

    write('  Shift key (1-25): ');
    readln(shift);
    if shift < 1 then shift := 1;
    if shift > 25 then shift := 25;
    writeln;

    write('  Enter msg: ');
    readln(msg);
    writeln;

    if (mode = 'd') or (mode = 'D') then
      shift := 26 - shift;   { decode = encode with inverse shift }

    textcolor(11);
    write('  Result: ');
    textcolor(10);
    for i := 1 to length(msg) do
      write(encodeChar(msg[i], shift));
    textcolor(7);
    writeln;
    writeln;

    write('  Again? (y/n): ');
    readln(answer);
  end;
end.
