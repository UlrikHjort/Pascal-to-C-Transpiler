{ examples/records.pas – record types and field access }
program Records;

type
  Point = record
    x, y : real
  end;

  Person = record
    name : string;
    age  : integer
  end;

var
  p    : Point;
  q    : Point;
  alice: Person;

begin
  p.x := 3.0;
  p.y := 4.0;
  write('Point p = (');
  write(p.x);
  write(', ');
  write(p.y);
  writeln(')');

  q.x := p.x + 1.0;
  q.y := p.y + 1.0;
  write('Point q = (');
  write(q.x);
  write(', ');
  write(q.y);
  writeln(')');

  alice.name := 'Alice';
  alice.age  := 30;
  write('Name: ');
  writeln(alice.name);
  write('Age:  ');
  writeln(alice.age)
end.
