program TStrings;
var
  s: string;
  n: integer;
begin
  s := concat('Hello', ' World');
  writeln(s);
  n := length('Pascal');
  writeln(n);
  s := copy('Hello', 2, 3);
  writeln(s);
  n := pos('lo', 'Hello');
  writeln(n);
  if 'abc' < 'abd' then writeln(1) else writeln(0)
end.
