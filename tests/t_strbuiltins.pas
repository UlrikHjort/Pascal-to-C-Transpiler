{ Test: str builtin with integer and real, string builtins }
program str_test;
var
  s : string[32];
  n : integer;
  r : real;
begin
  { str: integer -> string }
  n := 42;
  str(n, s);
  writeln(s);

  { str: real -> string }
  r := 3.14;
  str(r, s);
  writeln(s);

  { delete }
  s := 'Hello, World!';
  delete(s, 7, 7);
  writeln(s);

  { insert }
  s := 'Helo';
  insert('l', s, 3);
  writeln(s);

  { pos }
  writeln(pos('World', 'Hello, World!'));

  { copy }
  writeln(copy('Hello, World!', 1, 5));

  { uppercase / lowercase }
  writeln(uppercase('hello'));
  writeln(lowercase('WORLD'));

  { trim }
  writeln(trim('  spaces  '));
end.
