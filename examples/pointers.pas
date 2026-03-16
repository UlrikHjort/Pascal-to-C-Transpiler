{ examples/pointers.pas - pointer types, new, dispose }
program Pointers;

type
  PInt = ^integer;

var
  p : PInt;
  n : integer;

begin
  new(p);
  p^ := 42;
  n  := p^;
  write('value via pointer = ');
  writeln(n);
  p^ := p^ * 2;
  write('doubled via pointer = ');
  writeln(p^);
  dispose(p)
end.
