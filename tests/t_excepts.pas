program TExcepts;
begin
  try
    raise 'oops';
  except
    on E: Exception do
      writeln(E);
  end;
  try
    raise 'second error';
  except
    on E: Exception do
      writeln('caught: ', E);
  end
end.
