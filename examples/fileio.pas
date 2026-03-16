program FileIO;
var
  f: text;
  line: string[64];
  n: integer;
begin
  { Write integers to a temp file }
  assign(f, '/tmp/pascal_test_io.txt');
  rewrite(f);
  writeln(f, 10);
  writeln(f, 20);
  writeln(f, 30);
  close(f);

  { Read them back and sum }
  assign(f, '/tmp/pascal_test_io.txt');
  reset(f);
  n := 0;
  while not eof(f) do begin
    readln(f, n);
    writeln(n)
  end;
  close(f)
end.
