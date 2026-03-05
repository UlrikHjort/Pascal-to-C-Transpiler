program StrCmp;
var
  a, b: string;
begin
  a := 'hello';
  b := 'world';
  if a = b then writeln('equal') else writeln('not equal');
  if a < b then writeln('a before b') else writeln('a not before b');
  if a <> b then writeln('different') else writeln('same');
  a := 'hello';
  b := 'hello';
  if a = b then writeln('now equal') else writeln('still not equal')
end.
