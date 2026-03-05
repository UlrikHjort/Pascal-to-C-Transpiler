{ MergeSort visualiser – companion to quicksort.pas
  Shows the divide phase top-down, then the merge phase bottom-up }
program mergesort;

const
  N      = 50;
  BARROW = 24;

var
  arr  : array[1..N] of integer;
  tmp  : array[1..N] of integer;
  i    : integer;
  comparisons, merges : integer;

procedure drawBar(idx, color : integer);
var r : integer;
begin
  textcolor(color);
  for r := 1 to arr[idx] do
  begin
    gotoxy(idx * 2 - 1, BARROW - r + 1);
    write('[]');
  end;
  textcolor(0);
  for r := arr[idx] + 1 to N do
  begin
    gotoxy(idx * 2 - 1, BARROW - r + 1);
    write('  ');
  end;
  textcolor(7);
end;

procedure drawRange(lo, hi, color : integer);
var j : integer;
begin
  for j := lo to hi do
    drawBar(j, color);
end;

procedure drawStatus;
begin
  gotoxy(1, BARROW + 2);
  textcolor(11);
  write('  Comparisons: '); write(comparisons);
  write('   Merges: '); write(merges);
  write('        ');
  textcolor(7);
end;

procedure merge(lo, mid, hi : integer);
var a, b, k : integer;
begin
  a := lo; b := mid + 1; k := lo;
  while (a <= mid) and (b <= hi) do
  begin
    comparisons := comparisons + 1;
    if arr[a] <= arr[b] then
    begin
      tmp[k] := arr[a];
      a := a + 1;
    end
    else
    begin
      tmp[k] := arr[b];
      b := b + 1;
    end;
    k := k + 1;
  end;
  while a <= mid do
  begin
    tmp[k] := arr[a];
    a := a + 1; k := k + 1;
  end;
  while b <= hi do
  begin
    tmp[k] := arr[b];
    b := b + 1; k := k + 1;
  end;
  for k := lo to hi do
  begin
    arr[k] := tmp[k];
    drawBar(k, 11);
  end;
  merges := merges + 1;
  drawStatus;
  delay(20);
end;

procedure mergesortRec(lo, hi : integer);
var mid : integer;
begin
  if lo >= hi then exit;
  mid := (lo + hi) div 2;
  drawRange(lo, mid, 14);
  delay(15);
  drawRange(mid+1, hi, 12);
  delay(15);
  mergesortRec(lo, mid);
  mergesortRec(mid + 1, hi);
  merge(lo, mid, hi);
  drawRange(lo, hi, 10);
end;

begin
  randomize;
  for i := 1 to N do
    arr[i] := random(N) + 1;

  comparisons := 0;
  merges := 0;

  clrscr;
  hidecursor;
  gotoxy(1, 1);
  textcolor(14);
  writeln('  MergeSort Visualiser  (', N, ' elements)');
  textcolor(8);
  writeln('  yellow=left half  red=right half  cyan=merging  green=sorted');
  textcolor(7);

  for i := 1 to N do drawBar(i, 7);
  drawStatus;

  gotoxy(1, BARROW + 3);
  textcolor(14);
  write('  Press Enter to sort...');
  textcolor(7);
  readln;
  gotoxy(1, BARROW + 3);
  write('                        ');

  mergesortRec(1, N);

  for i := 1 to N do drawBar(i, 10);

  gotoxy(1, BARROW + 3);
  textcolor(10);
  write('  Sorted!  Press Enter to exit.');
  textcolor(7);
  showcursor;
  readln;
  clrscr;
end.
