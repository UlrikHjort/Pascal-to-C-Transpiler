program StrLib;

var
  s: string[20];
  t: string[10];
  n, code: integer;

begin
  { Trim }
  writeln(trim('  hello world  '));

  { LowerCase / UpperCase }
  writeln(lowercase('Hello World'));
  writeln(uppercase('Hello World'));

  { Delete: remove ' World' from position 6, length 6 }
  s := 'Hello World';
  delete(s, 6, 6);
  writeln(s);

  { Insert 'l' at position 4 }
  s := 'Helo World';
  insert('l', s, 4);
  writeln(s);

  { Str / Val round-trip }
  str(42, t);
  writeln(t);
  val(t, n, code);
  writeln(n);
  writeln(code);
end.
