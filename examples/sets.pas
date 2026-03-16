program sets;
var
  s : set of integer;
  t : set of integer;
  u : set of integer;
begin
  s := [1, 2, 3, 5, 7];
  t := [2, 4, 6];
  u := s + t;            { union }
  s := s * t;            { intersection }
  t := [1, 2, 3, 5, 7] - [2];  { difference }
  if 2 in u then
    writeln('2 in union');
  if 4 in u then
    writeln('4 in union');
  if not (4 in s) then
    writeln('4 not in intersection');
  if 3 in t then
    writeln('3 in difference');
  if not (2 in t) then
    writeln('2 not in difference');
end.
