{ examples/builtins.pas – built-in math and string functions }
program Builtins;
var
  x    : real;
  n    : integer;
  s    : string;
begin
  { math }
  x := sqrt(16.0);
  write('sqrt(16) = ');
  writeln(x);

  x := abs(-7.5);
  write('abs(-7.5) = ');
  writeln(x);

  n := round(3.7);
  write('round(3.7) = ');
  writeln(n);

  n := trunc(9.9);
  write('trunc(9.9) = ');
  writeln(n);

  { ord / chr }
  n := ord('A');
  write('ord(A) = ');
  writeln(n);

  { succ / pred }
  n := succ(4);
  write('succ(4) = ');
  writeln(n);

  n := pred(4);
  write('pred(4) = ');
  writeln(n);

  { string }
  s := concat('Hello', ', World!');
  write('concat = ');
  writeln(s);

  n := length('Pascal');
  write('length(Pascal) = ');
  writeln(n);

  n := pos('sc', 'Pascal');
  write('pos(sc,Pascal) = ');
  writeln(n);

  s := copy('Pascal', 2, 3);
  write('copy(Pascal,2,3) = ');
  writeln(s)
end.
