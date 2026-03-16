{ Simple interactive calculator }
program calculator;

var
  a, b : real;
  op   : char;
  cont : char;

procedure show_result(val : real);
begin
  if trunc(val) = val then
    writeln('= ', trunc(val) : 1)
  else
    writeln('= ', val : 0 : 6);
end;

begin
  writeln('=== Pascal Calculator ===');
  writeln('Operators: + - * /  (q to quit)');
  writeln;

  cont := 'y';
  while cont <> 'q' do
  begin
    write('First number : ');  readln(a);
    write('Operator     : ');  readln(op);

    if op = 'q' then
    begin
      cont := 'q';
    end
    else
    begin
      write('Second number: ');  readln(b);

      if op = '+' then show_result(a + b)
      else if op = '-' then show_result(a - b)
      else if op = '*' then show_result(a * b)
      else if op = '/' then
      begin
        if b = 0.0 then
          writeln('Error: division by zero')
        else
          show_result(a / b)
      end
      else
        writeln('Unknown operator: ', op);

      writeln;
      write('Again? (y=yes / q=quit): ');
      readln(cont);
      writeln;
    end;
  end;

  writeln('Bye!');
end.
