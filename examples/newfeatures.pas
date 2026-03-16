program NewFeatures;

{ A: const in array bounds }
const
  Lo = 1;
  Hi = 5;

var
  a : array[Lo..Hi] of integer;
  i : integer;
  s1, s2, s3 : string;
  ch : char;

begin
  { A: const bounds }
  for i := Lo to Hi do
    a[i] := i * i;
  for i := Lo to Hi do
    write(a[i]:4);
  writeln;

  { B: string concatenation with + }
  s1 := 'Hello';
  s2 := ', world!';
  s3 := s1 + s2;
  writeln(s3);

  { C: char ranges in case }
  ch := 'g';
  case ch of
    'a'..'f': writeln('a-f');
    'g'..'z': writeln('g-z');
    'A'..'Z': writeln('upper');
  end;

  { D: writeln field widths }
  writeln(42:8);
  writeln(3.14159:10:3);
end.
