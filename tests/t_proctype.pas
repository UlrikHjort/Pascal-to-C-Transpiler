program TProcType;
type
  MathFn = function(x : integer) : integer;
  Printer = procedure(s : string);

function Double(x : integer) : integer;
begin
  Double := x * 2;
end;

function Triple(x : integer) : integer;
begin
  Triple := x * 3;
end;

procedure PrintIt(s : string);
begin
  writeln(s);
end;

var
  f : MathFn;
  p : Printer;
begin
  f := @Double;
  writeln(f(5));    { 10 }
  f := @Triple;
  writeln(f(5));    { 15 }
  p := @PrintIt;
  p('hello');
end.
