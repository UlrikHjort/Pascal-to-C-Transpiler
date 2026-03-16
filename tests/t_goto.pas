program TGotoLabel;
label skip, done;
var i : integer;
begin
  i := 0;
  goto skip;
  writeln('should not print');
  skip:
  i := i + 1;
  writeln(i);
  { integer label }
  10:
  i := i + 1;
  writeln(i);
  goto done;
  writeln('also not printed');
  done:
  writeln('done');
end.
