program FixedStrTest;

var
  name : string[20];
  greeting : string[50];

begin
  name := 'Pascal';
  greeting := 'Hello, world!';
  writeln(name);
  writeln(greeting);
  writeln(length(name));
end.
