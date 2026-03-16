program ForwardTest;

{ Forward declarations allow mutually recursive functions }

function IsEven(n: integer): boolean; forward;
function IsOdd(n: integer): boolean; forward;

function IsEven(n: integer): boolean;
begin
  if n = 0 then IsEven := true
  else IsEven := IsOdd(n - 1);
end;

function IsOdd(n: integer): boolean;
begin
  if n = 0 then IsOdd := false
  else IsOdd := IsEven(n - 1);
end;

begin
  if IsEven(4) then writeln('4 is even') else writeln('4 is odd');
  if IsOdd(7)  then writeln('7 is odd')  else writeln('7 is even');
end.
