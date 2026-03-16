{ examples/case_test.pas - demonstrate case statement }
program CaseTest;
var
  day, i : integer;
begin
  { single value labels }
  for i := 1 to 7 do
  begin
    day := i;
    case day of
      1: writeln('Monday');
      2: writeln('Tuesday');
      3: writeln('Wednesday');
      4: writeln('Thursday');
      5: writeln('Friday');
      6, 7: writeln('Weekend')
    else
      writeln('Unknown')
    end
  end
end.
