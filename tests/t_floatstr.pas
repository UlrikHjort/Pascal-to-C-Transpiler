program TFloatStr;
var
  x: real;
  s: string;
begin
  x := 3.14;
  s := floattostr(x);
  writeln(s);
  s := formatfloat('%.2f', x);
  writeln(s);
  s := formatfloat('%.0f', 2.718);
  writeln(s);
end.
