program TStrcomp;
var
  a, b: string;
begin
  a := 'apple';
  b := 'banana';
  if a = b then writeln(1) else writeln(0);
  if a <> b then writeln(1) else writeln(0);
  if a < b then writeln(1) else writeln(0);
  if a > b then writeln(1) else writeln(0);
  if a <= b then writeln(1) else writeln(0);
  if a >= b then writeln(1) else writeln(0)
end.
