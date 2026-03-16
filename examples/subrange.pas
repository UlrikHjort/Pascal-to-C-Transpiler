program subrange;
type
  Digit  = 0..9;
  Score  = 1..100;
var
  d  : Digit;
  s  : Score;
  lo : set of 0..7;
  hi : set of 0..7;
  both : set of 0..7;
begin
  d := 5;
  s := 42;
  writeln(d);
  writeln(s);
  lo   := [0, 1, 2, 3];
  hi   := [4, 5, 6, 7];
  both := lo + hi;
  if 3 in lo then
    writeln('3 in lo');
  if 6 in hi then
    writeln('6 in hi');
  if 7 in both then
    writeln('7 in both');
  if not (8 in both) then
    writeln('8 not in both');
end.
