program TFileio;
var
  f: text;
  n: integer;
begin
  assign(f, '/tmp/t_fileio_test.txt');
  rewrite(f);
  writeln(f, 100);
  writeln(f, 200);
  writeln(f, 300);
  close(f);
  assign(f, '/tmp/t_fileio_test.txt');
  reset(f);
  while not eof(f) do begin
    readln(f, n);
    writeln(n)
  end;
  close(f)
end.
