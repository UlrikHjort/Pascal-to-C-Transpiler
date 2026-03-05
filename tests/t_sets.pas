program TSets;
var
  s, t, u: set of integer;
begin
  s := [1, 2, 3];
  t := [2, 3, 4];
  u := s + t;
  if 4 in u then writeln(1) else writeln(0);
  u := s * t;
  if 1 in u then writeln(1) else writeln(0);
  if 2 in u then writeln(1) else writeln(0);
  u := s - t;
  if 1 in u then writeln(1) else writeln(0);
  if 2 in u then writeln(1) else writeln(0)
end.
