program ExceptionTest;

var
  x: integer;

begin
  x := 42;
  try
    if x > 0 then
      raise 'value is positive';
    writeln('no exception');
  except
    on Exception do
      writeln('caught exception');
  end;
  writeln('after try');
end.
