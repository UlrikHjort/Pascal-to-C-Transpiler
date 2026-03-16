{ Number guessing game }
program guessing;

var
  secret, guess, attempts : integer;
  answer : char;

begin
  writeln('=== Number Guessing Game ===');
  writeln('I will pick a number between 1 and 100.');
  writeln;

  randomize;

  answer := 'y';
  while answer = 'y' do
  begin
    secret   := random(100) + 1;
    attempts := 0;

    writeln('I have picked a number. Start guessing!');
    writeln;

    guess := 0;
    while guess <> secret do
    begin
      write('Your guess: ');
      readln(guess);
      attempts := attempts + 1;

      if guess < secret then
        writeln('Too low!')
      else if guess > secret then
        writeln('Too high!')
      else
      begin
        writeln('Correct! The number was ', secret, '.');
        if attempts = 1 then
          writeln('Wow, first try!')
        else
          writeln('You got it in ', attempts, ' attempts.');
      end;
    end;

    writeln;
    write('Play again? (y/n) ');
    readln(answer);
    writeln;
  end;

  writeln('Thanks for playing!');
end.
