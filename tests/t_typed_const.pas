{ Test: typed constants — scalar and array forms }
program typed_const_test;

const
  MaxVal : integer = 100;
  Pi     : real    = 3.14159;
  Msg    : string  = 'hello';
  Primes : array[1..5] of integer = (2, 3, 5, 7, 11);
  Flags  : array[1..4] of boolean = (true, false, true, false);

var
  i : integer;
begin
  writeln(MaxVal);
  writeln(Pi:0:5);
  writeln(Msg);
  for i := 1 to 5 do
    write(Primes[i], ' ');
  writeln;
  for i := 1 to 4 do
    write(Flags[i], ' ');
  writeln;
  { typed const is mutable in Pascal }
  MaxVal := 200;
  writeln(MaxVal);
end.
