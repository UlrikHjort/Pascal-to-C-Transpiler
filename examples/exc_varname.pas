program ExcVarName;

begin
  try
    raise 'something went wrong';
  except
    on E: Exception do
      writeln('error: ', E);
  end;
end.
