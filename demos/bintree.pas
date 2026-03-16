{ BinTree - binary search tree insert, search, and in-order traversal }
program bintree;

const
  MAXNODES = 63;

var
  val  : array[1..MAXNODES] of integer;
  lft  : array[1..MAXNODES] of integer;
  rgt  : array[1..MAXNODES] of integer;
  used : integer;
  root : integer;
  i, j, k, v : integer;
  answer : char;
  found : boolean;
  level : array[1..MAXNODES] of integer;
  xcol  : array[1..MAXNODES] of integer;

function newNode(v2 : integer) : integer;
begin
  used := used + 1;
  val[used] := v2;
  lft[used] := 0;
  rgt[used] := 0;
  newNode := used;
end;

procedure treeInsert(v2 : integer);
var cur, prev, nd : integer;
    goLeft : boolean;
begin
  nd := newNode(v2);
  if root = 0 then
    root := nd
  else
  begin
    cur := root; prev := 0; goLeft := false;
    while cur <> 0 do
    begin
      prev := cur;
      if v2 < val[cur] then
      begin goLeft := true;  cur := lft[cur]; end
      else if v2 > val[cur] then
      begin goLeft := false; cur := rgt[cur]; end
      else
      begin
        { duplicate - discard }
        used := used - 1;
        cur := 0;
        prev := 0;
      end;
    end;
    if prev <> 0 then
      if goLeft then lft[prev] := nd else rgt[prev] := nd;
  end;
end;

function search(v2 : integer) : boolean;
var cur : integer;
begin
  cur := root;
  while cur <> 0 do
  begin
    if v2 = val[cur] then
    begin search := true; exit; end
    else if v2 < val[cur] then cur := lft[cur]
    else cur := rgt[cur];
  end;
  search := false;
end;

{ Compute display positions via in-order traversal }
var inorder_seq : array[1..MAXNODES] of integer;
    inorder_cnt : integer;

procedure inorderFill(nd : integer);
begin
  if nd = 0 then exit;
  inorderFill(lft[nd]);
  inorder_cnt := inorder_cnt + 1;
  inorder_seq[inorder_cnt] := nd;
  inorderFill(rgt[nd]);
end;

procedure assignLevels(nd, lv : integer);
begin
  if nd = 0 then exit;
  level[nd] := lv;
  assignLevels(lft[nd], lv + 1);
  assignLevels(rgt[nd], lv + 1);
end;

procedure drawTree;
var cur_level, n, col_idx : integer;
    r, c2, prev_nd : integer;
begin
  clrscr;
  textcolor(14);
  writeln('  Binary Search Tree');
  writeln;

  inorder_cnt := 0;
  inorderFill(root);

  assignLevels(root, 1);

  { assign x positions from in-order sequence }
  for i := 1 to inorder_cnt do
    xcol[inorder_seq[i]] := i;

  { draw nodes by level }
  cur_level := 0;
  for i := 1 to inorder_cnt do
  begin
    n := inorder_seq[i];
    if level[n] <> cur_level then
    begin
      if cur_level > 0 then writeln;
      cur_level := level[n];
      write('  ');
    end;
    { pad to column }
    col_idx := xcol[n] * 4;
    gotoxy(col_idx, cur_level * 2 + 2);
    textcolor(11);
    write(val[n]);
  end;
  writeln;
  writeln;
  textcolor(7);
end;

begin
  used := 0; root := 0;

  { Insert some values }
  treeInsert(50); treeInsert(30); treeInsert(70); treeInsert(20); treeInsert(40);
  treeInsert(60); treeInsert(80); treeInsert(10); treeInsert(25); treeInsert(35);
  treeInsert(45); treeInsert(55); treeInsert(65); treeInsert(75); treeInsert(90);

  drawTree;

  textcolor(14);
  writeln('  In-order traversal: ');
  write('  ');
  textcolor(10);
  inorder_cnt := 0;
  inorderFill(root);
  for i := 1 to inorder_cnt do
  begin
    write(val[inorder_seq[i]]);
    if i < inorder_cnt then write(' -> ');
  end;
  writeln;
  textcolor(7);
  writeln;

  answer := 'y';
  while answer = 'y' do
  begin
    textcolor(14);
    write('  Search for value (0=quit): ');
    textcolor(7);
    readln(v);
    if v = 0 then answer := 'n'
    else
    begin
      if search(v) then
      begin textcolor(10); write('  Found: '); write(v); writeln(' is in the tree.'); end
      else begin textcolor(12); write('  Not found: '); write(v); writeln(' is not in the tree.'); end;
      textcolor(7);
    end;
  end;

  writeln;
  textcolor(14);
  write('  Insert value (0=done): ');
  textcolor(7);
  readln(v);
  while v <> 0 do
  begin
    treeInsert(v);
    drawTree;
    inorder_cnt := 0;
    inorderFill(root);
    write('  In-order: ');
    textcolor(10);
    for i := 1 to inorder_cnt do
    begin write(val[inorder_seq[i]]); if i < inorder_cnt then write(' '); end;
    writeln;
    textcolor(14);
    write('  Insert value (0=done): ');
    textcolor(7);
    readln(v);
  end;
end.
