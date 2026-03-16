program EnumSet;

type
  Day = (Mon, Tue, Wed, Thu, Fri, Sat, Sun);

var
  workdays : set of Mon..Fri;
  weekend  : set of Sat..Sun;
  d        : Day;

begin
  workdays := [Mon, Wed, Fri];
  weekend  := [Sat, Sun];

  { Test membership }
  if Mon in workdays then writeln('Mon is a workday');
  if Sat in weekend  then writeln('Sat is weekend');
  if not (Sat in workdays) then writeln('Sat is not a workday');

  { ord of enum values }
  writeln(ord(Mon));
  writeln(ord(Fri));
  writeln(ord(Sun));
end.
