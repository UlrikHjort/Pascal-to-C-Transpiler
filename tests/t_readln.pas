{ Test: read/readln from stdin - integer, real, string }
program readtest;
var
  n : integer;
  r : real;
  s : string[64];
  c : char;
begin
  readln(n);
  readln(r);
  readln(s);
  readln(c);
  writeln(n * 2);
  writeln(r * 2.0 : 0 : 2);
  writeln(uppercase(s));
  writeln(c);
end.
