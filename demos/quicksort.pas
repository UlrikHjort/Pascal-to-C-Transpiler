{ QuickSort visualiser - bars show array state after each partition
  Pivot is highlighted in yellow, sorted elements in green,
  active partition range in cyan, unsorted in white. }
program quicksort;

const
  N      = 50;
  BARROW = 24;   { bottom of bar chart }

var
  arr      : array[1..N] of integer;
  sorted   : array[1..N] of boolean;
  comparisons, swaps : integer;
  i : integer;

procedure drawBar(idx, color : integer);
var r : integer;
begin
  textcolor(color);
  for r := 1 to arr[idx] do
  begin
    gotoxy(idx * 2 - 1, BARROW - r + 1);
    write('[]');
  end;
  { clear above }
  textcolor(0);
  for r := arr[idx] + 1 to N do
  begin
    gotoxy(idx * 2 - 1, BARROW - r + 1);
    write('  ');
  end;
  textcolor(7);
end;

procedure drawAll(lo, hi, pivotIdx : integer);
var j : integer;
begin
  for j := 1 to N do
  begin
    if sorted[j] then
      drawBar(j, 10)           { green = sorted }
    else if j = pivotIdx then
      drawBar(j, 14)           { yellow = pivot }
    else if (j >= lo) and (j <= hi) then
      drawBar(j, 11)           { cyan = active range }
    else
      drawBar(j, 7);           { white = unsorted }
  end;
end;

procedure swap(a, b : integer);
var tmp : integer;
begin
  tmp    := arr[a];
  arr[a] := arr[b];
  arr[b] := tmp;
  swaps  := swaps + 1;
end;

procedure drawStatus;
begin
  gotoxy(1, BARROW + 2);
  textcolor(11);
  write('  Comparisons: ');
  write(comparisons);
  write('   Swaps: ');
  write(swaps);
  write('        ');
  textcolor(7);
end;

procedure quicksortRec(lo, hi : integer);
var
  pivot, left, right : integer;
begin
  if lo >= hi then
  begin
    if lo = hi then sorted[lo] := true;
    exit;
  end;

  pivot := arr[(lo + hi) div 2];
  left  := lo;
  right := hi;

  while left <= right do
  begin
    comparisons := comparisons + 1;
    while arr[left] < pivot do
    begin
      left := left + 1;
      comparisons := comparisons + 1;
    end;

    comparisons := comparisons + 1;
    while arr[right] > pivot do
    begin
      right := right - 1;
      comparisons := comparisons + 1;
    end;

    if left <= right then
    begin
      swap(left, right);
      drawAll(lo, hi, (lo + hi) div 2);
      drawStatus;
      delay(30);
      left  := left + 1;
      right := right - 1;
    end;
  end;

  quicksortRec(lo, right);
  quicksortRec(left, hi);

  { mark this segment as sorted if it covers one element }
  if lo = hi then sorted[lo] := true;
end;

procedure markSorted;
var j : integer;
begin
  for j := 1 to N do
    sorted[j] := true;
end;

begin
  randomize;

  { fill with random heights 1..N }
  for i := 1 to N do
  begin
    arr[i]    := random(N) + 1;
    sorted[i] := false;
  end;

  comparisons := 0;
  swaps       := 0;

  clrscr;
  hidecursor;

  gotoxy(1, 1);
  textcolor(14);
  writeln('  QuickSort Visualiser  (', N, ' elements)');
  textcolor(8);
  writeln('  yellow=pivot  cyan=active range  green=sorted');
  textcolor(7);

  drawAll(1, N, 0);
  drawStatus;

  gotoxy(1, BARROW + 3);
  textcolor(14);
  write('  Press Enter to sort...');
  textcolor(7);
  readln;
  gotoxy(1, BARROW + 3);
  write('                        ');

  quicksortRec(1, N);

  markSorted;
  drawAll(1, N, 0);
  drawStatus;

  gotoxy(1, BARROW + 3);
  textcolor(10);
  write('  Sorted!  Press Enter to exit.');
  textcolor(7);

  showcursor;
  readln;
  clrscr;
end.
