{ Calendar - print any month with correct weekday alignment
  Uses Tomohiko Sakamoto's algorithm for day-of-week }
program calendar;

var
  year, month, day : integer;
  startDay         : integer;   { 0=Sun 1=Mon ... 6=Sat }
  daysInMonth      : integer;
  i                : integer;
  answer           : char;
  monthNames : array[1..12] of string[9];
  dayNames   : array[0..6]  of string[3];

function dayOfWeek(y, m, d : integer) : integer;
{ Tomohiko Sakamoto algorithm, returns 0=Sun..6=Sat }
var t : array[1..12] of integer;
    yy : integer;
begin
  t[1]  := 0; t[2]  := 3; t[3]  := 2; t[4]  := 5;
  t[5]  := 0; t[6]  := 3; t[7]  := 5; t[8]  := 1;
  t[9]  := 4; t[10] := 6; t[11] := 2; t[12] := 4;
  yy := y;
  if m < 3 then yy := yy - 1;
  dayOfWeek := (yy + yy div 4 - yy div 100 + yy div 400 + t[m] + d) mod 7;
end;

function isLeap(y : integer) : boolean;
begin
  isLeap := ((y mod 4 = 0) and (y mod 100 <> 0)) or (y mod 400 = 0);
end;

function daysIn(m, y : integer) : integer;
var days : array[1..12] of integer;
begin
  days[1]  := 31; days[2]  := 28; days[3]  := 31;
  days[4]  := 30; days[5]  := 31; days[6]  := 30;
  days[7]  := 31; days[8]  := 31; days[9]  := 30;
  days[10] := 31; days[11] := 30; days[12] := 31;
  if isLeap(y) then days[2] := 29;
  daysIn := days[m];
end;

procedure printMonth(m, y : integer);
var sd, dim, col, d : integer;
begin
  sd  := dayOfWeek(y, m, 1);  { 0=Sun }
  dim := daysIn(m, y);

  writeln;
  textcolor(14);
  write('       ');
  write(monthNames[m]);
  write(' ');
  writeln(y);
  textcolor(11);
  writeln('  Sun Mon Tue Wed Thu Fri Sat');
  textcolor(8);
  writeln('  --- --- --- --- --- --- ---');
  textcolor(7);

  write('  ');
  { indent to start day }
  for i := 0 to sd - 1 do
    write('    ');

  col := sd;
  for d := 1 to dim do
  begin
    if d = day then
    begin
      textcolor(10);
      if d < 10 then write(' ');
      write(d);
      write(' ');
      textcolor(7);
    end
    else
    begin
      { weekend in dim color }
      if (col mod 7 = 0) or (col mod 7 = 6) then
        textcolor(12)
      else
        textcolor(7);
      if d < 10 then write(' ');
      write(d);
      write(' ');
      textcolor(7);
    end;
    col := col + 1;
    if col mod 7 = 0 then
    begin
      writeln;
      write('  ');
    end;
  end;
  writeln;
  writeln;
end;

begin
  monthNames[1]  := 'January';   monthNames[2]  := 'February';
  monthNames[3]  := 'March';     monthNames[4]  := 'April';
  monthNames[5]  := 'May';       monthNames[6]  := 'June';
  monthNames[7]  := 'July';      monthNames[8]  := 'August';
  monthNames[9]  := 'September'; monthNames[10] := 'October';
  monthNames[11] := 'November';  monthNames[12] := 'December';

  answer := 'y';
  while answer = 'y' do
  begin
    clrscr;
    textcolor(14);
    writeln('  === Calendar ===');
    textcolor(7);
    writeln;

    write('  Year  (e.g. 2025): '); readln(year);
    write('  Month (1-12):      '); readln(month);
    if month < 1  then month := 1;
    if month > 12 then month := 12;

    day := 0;  { 0 = no highlight }
    write('  Day to highlight (0=none): '); readln(day);

    printMonth(month, year);

    write('  Another month? (y/n): ');
    readln(answer);
  end;
end.
