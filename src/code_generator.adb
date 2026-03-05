-- ***************************************************************************
--              Pascal to C Transpiler - Code generator
--
--           Copyright (C) 2026 By Ulrik Hørlyk Hjort
--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
-- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
-- OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ***************************************************************************            

with AST_Binding;         use AST_Binding;
with Interfaces.C;        use Interfaces.C;
with Interfaces.C.Strings;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Text_IO;           use Ada.Text_IO;
with System;

package body Code_Generator is

   --  Make "=" for System.Address (= Node_Addr / RType_Addr) visible.
   use type System.Address;

   --  ================================================================
   --  State (file-scope equivalent of C statics)
   --  ================================================================
   CG_Out_Ptr  : access File_Type := null;  --  output C file (via 'Unrestricted_Access)
   CG_Indent   : Natural := 0;
   CG_ST_Ptr   : access Symtab.Table;
   CG_Func     : Unbounded_String;   -- current function name (empty if main)
   CG_Is_Proc  : Boolean := False;

   --  With-stack inside codegen (mirrors typechk's)
   Max_CG_With : constant := 8;
   type CG_With_Frame is record
      Var_Name  : Unbounded_String;
      Type_Name : Unbounded_String;
   end record;
   type CG_With_Stack_T is array (0 .. Max_CG_With - 1) of CG_With_Frame;
   CG_With     : CG_With_Stack_T;
   CG_WDepth   : Natural := 0;

   --  ================================================================
   --  Helpers
   --  ================================================================
   function S (P : Interfaces.C.Strings.chars_ptr) return String is
      use Interfaces.C.Strings;
   begin
      if P = Null_Ptr then return ""; end if;
      return Value (P);
   end S;

   --  Strip leading space from Integer'Image
   function I_Img (V : Integer) return String is
      Raw : constant String := Integer'Image (V);
   begin
      if Raw'Length > 0 and Raw (Raw'First) = ' ' then
         return Raw (Raw'First + 1 .. Raw'Last);
      end if;
      return Raw;
   end I_Img;

   --  Format a real as %g using our C helper
   function Real_Img (V : Interfaces.C.double) return String is
      Buf : Char64;
   begin
      Format_Real (V, Buf, 64);
      declare
         S2 : String (1 .. 64);
         L  : Natural := 0;
      begin
         for I in Buf'Range loop
            exit when Interfaces.C.To_Ada (Buf (I)) = ASCII.NUL;
            L := L + 1;
            S2 (L) := Interfaces.C.To_Ada (Buf (I));
         end loop;
         return S2 (1 .. L);
      end;
   end Real_Img;

   --  Emit a string to the output file
   procedure E (Str : String) is
   begin
      Put (CG_Out_Ptr.all, Str);
   end E;

   procedure EL (Str : String) is
   begin
      Put_Line (CG_Out_Ptr.all, Str);
   end EL;

   procedure Emit_Indent is
   begin
      for I in 1 .. CG_Indent loop
         Put (CG_Out_Ptr.all, "    ");
      end loop;
   end Emit_Indent;

   --  Escape a Pascal string for a C string literal
   function Escape_String (Src : String) return String is
      Buf : Unbounded_String;
   begin
      for C of Src loop
         if    C = '"'  then Append (Buf, "\""");
         elsif C = '\' then Append (Buf, "\\");
         else                Append (Buf, C);
         end if;
      end loop;
      return To_String (Buf);
   end Escape_String;

   --  ================================================================
   --  Type-node → C string helpers
   --  ================================================================
   function Type_C_Base (T : Node_Addr) return String is
      Kind : Integer;
   begin
      if T = Null_Node then return "int"; end if;
      Kind := Integer (Get_Kind (T));
      if    Kind = ND_TYPE_INT    then return "int";
      elsif Kind = ND_TYPE_REAL   then return "double";
      elsif Kind = ND_TYPE_BOOL   then return "int";
      elsif Kind = ND_TYPE_CHAR   then return "char";
      elsif Kind = ND_TYPE_STRING then
          if Integer (Get_Ival (T)) > 0 then
             return "char";   --  fixed-length; suffix provides [N+1]
          end if;
          return "char *";
      elsif Kind = ND_TYPE_ARRAY then
         if int (Child_Count (T)) > 0 then
            return Type_C_Base (Get_Child (T, 0));
         end if;
         return "int";
      elsif Kind = ND_TYPE_PTR then
         if int (Child_Count (T)) > 0 then
            return Type_C_Base (Get_Child (T, 0)) & " *";
         end if;
         return "void *";
      elsif Kind = ND_TYPE_NAMED then
         declare
            N : constant String := S (Get_Sval (T));
         begin
            return (if N /= "" then N else "int");
         end;
      elsif Kind = ND_TYPE_SET then
         return "uint64_t";
      elsif Kind = ND_TYPE_SUBRANGE then
         return "int";
      elsif Kind = ND_TYPE_ENUM_SUBRANGE then
         return "int";
      elsif Kind = ND_TYPE_FILE then
         return "pascal_file_t";
      elsif Kind = ND_TYPE_FUNCPTR then
         --  For variable declarations: use the typedef name if available,
         --  otherwise emit as void* fallback
         return "void *";
      else
         return "int";
      end if;
   end Type_C_Base;

   function Type_C_Suffix (T : Node_Addr) return String is
      Kind : Integer;
   begin
      if T = Null_Node then return ""; end if;
      Kind := Integer (Get_Kind (T));
      if Kind = ND_TYPE_ARRAY then
         declare
            Lo  : constant Integer := Integer (Get_Arr_Lo (T));
            Hi  : constant Integer := Integer (Get_Arr_Hi (T));
            Sz  : Integer := Hi - Lo + 1;
         begin
            if Sz <= 0 then Sz := 1; end if;
            if int (Child_Count (T)) > 0 then
               return "[" & I_Img (Sz) & "]" &
                      Type_C_Suffix (Get_Child (T, 0));
            else
               return "[" & I_Img (Sz) & "]";
            end if;
         end;
      elsif Kind = ND_TYPE_STRING then
         declare
            N : constant Integer := Integer (Get_Ival (T));
         begin
            if N > 0 then return "[" & I_Img (N + 1) & "]"; end if;
         end;
         return "";
      else
         return "";
      end if;
   end Type_C_Suffix;

   function Type_C_Init (T : Node_Addr) return String is
      Kind : Integer;
   begin
      if T = Null_Node then return ""; end if;
      Kind := Integer (Get_Kind (T));
      if Kind = ND_TYPE_STRING then
         if Integer (Get_Ival (T)) > 0 then
            return " = " & '"' & '"';  --  fixed-length char array
         end if;
         return " = NULL";
      elsif Kind = ND_TYPE_PTR then
         return " = NULL";
      elsif Kind = ND_TYPE_SET then
         return " = 0";
      else
         return "";
      end if;
   end Type_C_Init;

   --  Like Type_C_Base but string[N] returns char * (for function signatures)
   function Type_C_Base_Sig (T : Node_Addr) return String is
   begin
      if T /= Null_Node
        and then Integer (Get_Kind (T)) = ND_TYPE_STRING
      then
         return "char *";
      end if;
      return Type_C_Base (T);
   end Type_C_Base_Sig;

   --  ================================================================
   --  Built-in function → C expression
   --  ================================================================
   function Resolve_Builtin (Name : String; Args : String) return String is
      Lo : constant String := To_Lower (Name);
   begin
      if    Lo = "abs"        then return "fabs(" & Args & ")";
      elsif Lo = "sqr"        then return "((" & Args & ")*(" & Args & "))";
      elsif Lo = "sqrt"       then return "sqrt(" & Args & ")";
      elsif Lo = "sin"        then return "sin(" & Args & ")";
      elsif Lo = "cos"        then return "cos(" & Args & ")";
      elsif Lo = "ln"         then return "log(" & Args & ")";
      elsif Lo = "exp"        then return "exp(" & Args & ")";
      elsif Lo = "round"      then return "(int)round(" & Args & ")";
      elsif Lo = "trunc"      then return "(int)(" & Args & ")";
      elsif Lo = "frac"       then return "((" & Args & ")-(int)(" & Args & "))";
      elsif Lo = "odd"        then return "((" & Args & ")%2!=0)";
      elsif Lo = "ord"        then return "(int)(" & Args & ")";
      elsif Lo = "chr"        then return "(char)(" & Args & ")";
      elsif Lo = "succ"       then return "((" & Args & ")+1)";
      elsif Lo = "pred"       then return "((" & Args & ")-1)";
      elsif Lo = "float"      then return "(double)(" & Args & ")";
      elsif Lo = "integer"    then return "(int)(" & Args & ")";
      elsif Lo = "length"     then return "(int)strlen(" & Args & ")";
      elsif Lo = "upcase"     then return "toupper(" & Args & ")";
      elsif Lo = "copy"       then return "pascal_copy(" & Args & ")";
      elsif Lo = "concat"     then return "pascal_concat(" & Args & ")";
      elsif Lo = "pos"        then return "pascal_pos(" & Args & ")";
      elsif Lo = "inttostr"    then return "pascal_inttostr(" & Args & ")";
      elsif Lo = "floattostr"  then return "pascal_floattostr(" & Args & ")";
      elsif Lo = "formatfloat" then return "pascal_formatfloat(" & Args & ")";
      elsif Lo = "strtoint"   then return "atoi(" & Args & ")";
      elsif Lo = "strtofloat" then return "atof(" & Args & ")";
      elsif Lo = "trim"       then return "pascal_trim(" & Args & ")";
      elsif Lo = "lowercase"  then return "pascal_lowercase(" & Args & ")";
      elsif Lo = "uppercase"  then return "pascal_uppercase(" & Args & ")";
      elsif Lo = "delete"     then return "pascal_delete(" & Args & ")";
      elsif Lo = "insert"     then return "pascal_insert(" & Args & ")";
      elsif Lo = "str"        then return "pascal_str(" & Args & ")";
      elsif Lo = "eof"        then return "pascal_eof(" & Args & ")";
      elsif Lo = "eoln"       then return "pascal_eof(" & Args & ")";
      --  Terminal / ANSI helpers
      elsif Lo = "clrscr"     then return "pascal_clrscr()";
      elsif Lo = "gotoxy"     then return "pascal_gotoxy(" & Args & ")";
      elsif Lo = "delay"      then return "pascal_delay(" & Args & ")";
      elsif Lo = "textcolor"  then return "pascal_textcolor(" & Args & ")";
      elsif Lo = "hidecursor" then return "pascal_hide_cursor()";
      elsif Lo = "showcursor" then return "pascal_show_cursor()";
      elsif Lo = "rawmode"    then return "pascal_raw_mode()";
      elsif Lo = "normalmode" then return "pascal_normal_mode()";
      elsif Lo = "keypressed" then return "pascal_keypressed()";
      elsif Lo = "readkey"    then return "pascal_readkey()";
      elsif Lo = "random"     then return "pascal_random_real()";
      elsif Lo = "randomize"  then return "pascal_randomize()";
      else                         return "";
      end if;
   end Resolve_Builtin;

   --  ================================================================
   --  With-stack resolution
   --  ================================================================
   function CG_Resolve_With (Name : String) return String is
      Lo_Name : constant String := To_Lower (Name);
   begin
      for D in reverse 0 .. CG_WDepth - 1 loop
         declare
            Frame : CG_With_Frame renames CG_With (D);
            TN    : constant String := To_String (Frame.Type_Name);
            TD    : constant access constant Symtab.Type_Def :=
              Symtab.Lookup_Type (CG_ST_Ptr.all, TN);
         begin
            if TD /= null then
               for F in TD.Fields.First_Index .. TD.Fields.Last_Index loop
                  declare
                     FE : Symtab.Field_Entry renames
                       TD.Fields.Constant_Reference (F);
                  begin
                     if To_Lower (To_String (FE.Name)) = Lo_Name then
                        return To_String (Frame.Var_Name) & "." & Name;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
      return "";
   end CG_Resolve_With;

   --  ================================================================
   --  Expression code generation  (returns a C expression String)
   --  ================================================================
   function CG_Expr (N : Node_Addr) return String is
      Kind : Integer;
   begin
      if N = Null_Node then return "0"; end if;
      Kind := Integer (Get_Kind (N));

      case Kind is
         when ND_INT_LIT =>
            return I_Img (Integer (Get_Ival (N)));

         when ND_REAL_LIT =>
            return Real_Img (Get_Rval (N));

         when ND_BOOL_LIT =>
            return I_Img (Integer (Get_Ival (N)));

         when ND_STR_LIT =>
            --  If the type-checker tagged this as TY_CHAR (single-char literal),
            --  emit a C char literal 'x' instead of a string "x"
            if Integer (RType_Kind (N)) = TY_CHAR then
               return "'" & S (Get_Sval (N)) & "'";
            end if;
            return """" & Escape_String (S (Get_Sval (N))) & """";

         when ND_NIL =>
            return "NULL";

          when ND_IDENT =>
            declare
               Name : constant String := S (Get_Sval (N));
               W    : constant String := CG_Resolve_With (Name);
            begin
               if W /= "" then return W; end if;
               --  Check if it's a zero-arg builtin (e.g. clrscr, keypressed)
               declare
                  R : constant String := Resolve_Builtin (To_Lower (Name), "");
               begin
                  if R /= "" then return R; end if;
               end;
               --  Check if it's a zero-arg function call (not the current func name)
               if not (To_Lower (To_String (CG_Func)) = To_Lower (Name))
               then
                  declare
                     Idx : constant Integer :=
                       Symtab.Lookup_Subr_Index (CG_ST_Ptr.all, Name);
                  begin
                     if Idx >= 0 then
                        return Name & "()";
                     end if;
                  end;
               end if;
               return Name;
            end;

         when ND_FUNC_CALL =>
            declare
               Name : constant String  := S (Get_Sval (N));
               Lo   : constant String  := To_Lower (Name);
               CC   : constant Integer := Integer (Child_Count (N));
               Args : Unbounded_String;
            begin
               --  val(s, n, code) — args 1 and 2 need address-of
               if Lo = "val" and then CC = 3 then
                  return "pascal_val(" &
                     CG_Expr (Get_Child (N, 0)) & ", &(" &
                     CG_Expr (Get_Child (N, 1)) & "), &(" &
                     CG_Expr (Get_Child (N, 2)) & "))";
               end if;
               --  str(n, s) — type-aware: real → %g, integer → %d
               if Lo = "str" and then CC = 2 then
                  declare
                     Num_RK : constant Integer :=
                       Integer (RType_Kind (Get_Child (N, 0)));
                     Num_S  : constant String := CG_Expr (Get_Child (N, 0));
                     Dst_S  : constant String := CG_Expr (Get_Child (N, 1));
                  begin
                     if Num_RK = TY_REAL then
                        return "sprintf(" & Dst_S & ", ""%g"", (double)(" &
                               Num_S & "))";
                     else
                        return "sprintf(" & Dst_S & ", ""%d"", (int)(" &
                               Num_S & "))";
                     end if;
                  end;
               end if;
               --  insert(src, dest, pos) — if src is TY_CHAR, wrap in compound lit
               if Lo = "insert" and then CC = 3 then
                  declare
                     Src  : constant Node_Addr := Get_Child (N, 0);
                     S0   : constant String :=
                       (if Integer (RType_Kind (Src)) = TY_CHAR
                        then "(const char[]){" & CG_Expr (Src) & ", 0}"
                        else CG_Expr (Src));
                     S1   : constant String := CG_Expr (Get_Child (N, 1));
                     S2   : constant String := CG_Expr (Get_Child (N, 2));
                  begin
                     return "pascal_insert(" & S0 & ", " & S1 & ", " & S2 & ")";
                  end;
               end if;
               --  random – 0 args → real [0,1);  1 arg → int [0,n-1)
               if Lo = "random" then
                  if CC = 0 then return "pascal_random_real()";
                  else return "pascal_random_int(" & CG_Expr (Get_Child (N, 0)) & ")";
                  end if;
               end if;
               --  randomize – always no-arg
               if Lo = "randomize" then return "pascal_randomize()"; end if;
               for I in 0 .. CC - 1 loop
                  if I > 0 then Append (Args, ", "); end if;
                  Append (Args, CG_Expr (Get_Child (N, int (I))));
               end loop;
               declare
                  A : constant String := To_String (Args);
                  R : constant String := Resolve_Builtin (Name, A);
               begin
                  if R /= "" then return R;
                  elsif A /= "" then return Name & "(" & A & ")";
                  else               return Name & "()";
                  end if;
               end;
            end;

         when ND_BINOP =>
            declare
               L   : constant String  := CG_Expr (Get_Child (N, 0));
               R   : constant String  := (if int (Child_Count (N)) > 1
                                          then CG_Expr (Get_Child (N, 1))
                                          else "0");
               Op  : constant Integer := Integer (Get_Op (N));
               LK  : Integer          := TY_INT;
            begin
               if int (Child_Count (N)) > 0 then
                  LK := Integer (RType_Kind (Get_Child (N, 0)));
               end if;
               if Op = Character'Pos ('i') then
                  --  elem IN set  →  ((set >> elem) & 1ULL)
                  return "((" & R & " >> (" & L & ")) & 1ULL)";
               elsif LK = TY_SET then
                  --  Set arithmetic / comparison
                  if    Op = Character'Pos ('+') then
                     return "(" & L & " | " & R & ")";
                  elsif Op = Character'Pos ('-') then
                     return "(" & L & " & ~(" & R & "))";
                  elsif Op = Character'Pos ('*') then
                     return "(" & L & " & " & R & ")";
                  elsif Op = Character'Pos ('=') then
                     return "(" & L & " == " & R & ")";
                  elsif Op = Character'Pos ('N') then
                     return "(" & L & " != " & R & ")";
                  elsif Op = Character'Pos ('L') then  --  <= subset
                     return "((" & L & " & " & R & ") == " & L & ")";
                  elsif Op = Character'Pos ('G') then  --  >= superset
                     return "((" & L & " & " & R & ") == " & R & ")";
                  else
                     return "(" & L & " | " & R & ")";
                  end if;
               elsif (LK = TY_STRING or LK = TY_STRING_FIXED)
                  and Op = Character'Pos ('+')
               then
                  return "pascal_strcat_new(" & L & ", " & R & ")";
               elsif LK = TY_STRING or LK = TY_STRING_FIXED then
                  --  String relational comparison via strcmp macros
                  if    Op = Character'Pos ('=') then return "pascal_seq(" & L & ", " & R & ")";
                  elsif Op = Character'Pos ('N') then return "pascal_sne(" & L & ", " & R & ")";
                  elsif Op = Character'Pos ('<') then return "pascal_slt(" & L & ", " & R & ")";
                  elsif Op = Character'Pos ('>') then return "pascal_sgt(" & L & ", " & R & ")";
                  elsif Op = Character'Pos ('L') then return "pascal_sle(" & L & ", " & R & ")";
                  elsif Op = Character'Pos ('G') then return "pascal_sge(" & L & ", " & R & ")";
                  else return L & " + " & R;
                  end if;
               elsif Op = Character'Pos ('+') then return "(" & L & " + " & R & ")";
               elsif Op = Character'Pos ('-') then return "(" & L & " - " & R & ")";
               elsif Op = Character'Pos ('*') then return "(" & L & " * " & R & ")";
               elsif Op = Character'Pos ('/') then
                  return "((double)(" & L & ") / (double)(" & R & "))";
               elsif Op = Character'Pos ('D') then return "(" & L & " / " & R & ")";  -- DIV
               elsif Op = Character'Pos ('M') then return "(" & L & " % " & R & ")";  -- MOD
               elsif Op = Character'Pos ('<') then return "(" & L & " < " & R & ")";
               elsif Op = Character'Pos ('>') then return "(" & L & " > " & R & ")";
               elsif Op = Character'Pos ('L') then return "(" & L & " <= " & R & ")"; -- LE
               elsif Op = Character'Pos ('G') then return "(" & L & " >= " & R & ")"; -- GE
               elsif Op = Character'Pos ('=') then return "(" & L & " == " & R & ")";
               elsif Op = Character'Pos ('N') then return "(" & L & " != " & R & ")"; -- NE
               elsif Op = Character'Pos ('&') then
                   if LK = TY_BOOL then return "(" & L & " && " & R & ")";
                   else                   return "(" & L & " & "  & R & ")";
                   end if; -- AND
               elsif Op = Character'Pos ('|') then
                   if LK = TY_BOOL then return "(" & L & " || " & R & ")";
                   else                   return "(" & L & " | "  & R & ")";
                   end if; -- OR
               elsif Op = Character'Pos ('X') then return "(" & L & " ^ "  & R & ")"; -- XOR
               elsif Op = Character'Pos ('K') then return "(" & L & " << " & R & ")"; -- SHL
               elsif Op = Character'Pos ('R') then return "(" & L & " >> " & R & ")"; -- SHR
               else                                return "(" & L & " + " & R & ")";
               end if;
            end;

         when ND_UNOP =>
            declare
               C2 : constant String  := CG_Expr (Get_Child (N, 0));
               Op : constant Integer := Integer (Get_Op (N));
            begin
               if    Op = Character'Pos ('!') then return "!(" & C2 & ")"; -- NOT
               elsif Op = Character'Pos ('-') then return "-" & C2;
               elsif Op = Character'Pos ('@') then return "&(" & C2 & ")";
               else                                return "-" & C2;
               end if;
            end;

         when ND_INDEX =>
            if int (Child_Count (N)) < 2 then return "0"; end if;
            declare
               Base  : constant Node_Addr := Get_Child (N, 0);
               Idx   : constant Node_Addr := Get_Child (N, 1);
               Base_S: constant String    := CG_Expr (Base);
               Idx_S : constant String    := CG_Expr (Idx);
               BK    : constant Integer   := Integer (RType_Kind (Base));
               Lo    : Integer            := Integer (RType_Arr_Lo (Base));
            begin
               --  Pascal strings are 1-indexed; C char arrays are 0-indexed
               if (BK = TY_STRING or BK = TY_STRING_FIXED) and Lo = 0 then
                  Lo := 1;
               end if;
               if Lo = 0 then
                  return Base_S & "[" & Idx_S & "]";
               else
                  return Base_S & "[(" & Idx_S & ")-(" & I_Img (Lo) & ")]";
               end if;
            end;

         when ND_FIELD =>
            if int (Child_Count (N)) = 0 then return "0"; end if;
            return CG_Expr (Get_Child (N, 0)) & "." & S (Get_Sval (N));

         when ND_DEREF =>
            if int (Child_Count (N)) = 0 then return "0"; end if;
            return "(*" & CG_Expr (Get_Child (N, 0)) & ")";

         when ND_ADDR_OF =>
            if int (Child_Count (N)) = 0 then return "0"; end if;
            declare
               Child : constant Node_Addr := Get_Child (N, 0);
               CKind : constant Integer   := Integer (Get_Kind (Child));
            begin
               --  @FuncName → just emit function name (C function pointer)
               if CKind = ND_IDENT or CKind = ND_FUNC_CALL then
                  return S (Get_Sval (Child));
               end if;
               return "&(" & CG_Expr (Child) & ")";
            end;

         when ND_SET_LIT =>
            if int (Child_Count (N)) = 0 then return "(uint64_t)0"; end if;
            declare
               Buf : Unbounded_String := To_Unbounded_String ("(");
            begin
               for I in 0 .. Integer (Child_Count (N)) - 1 loop
                  if I > 0 then Append (Buf, " | "); end if;
                  declare
                     Child : constant Node_Addr := Get_Child (N, int (I));
                     CK    : constant Integer   := Integer (Get_Kind (Child));
                  begin
                     if CK = ND_SET_RANGE then
                        Append (Buf, "pascal_set_range(" &
                                CG_Expr (Get_Child (Child, 0)) & ", " &
                                CG_Expr (Get_Child (Child, 1)) & ")");
                     else
                        Append (Buf, "(1ULL << (" & CG_Expr (Child) & "))");
                     end if;
                  end;
               end loop;
               Append (Buf, ")");
               return To_String (Buf);
            end;

         when others =>
            return "0";
      end case;
   end CG_Expr;

   --  ================================================================
   --  Printf format for a resolved type
   --  ================================================================
   function Fmt_For_RType (RK : Integer) return String is
   begin
      if    RK = TY_REAL   then return "%g";
      elsif RK = TY_CHAR   then return "%c";
      elsif RK = TY_STRING or RK = TY_STRING_FIXED then return "%s";
      else                      return "%d";
      end if;
   end Fmt_For_RType;

   --  ================================================================
   --  Statement code generation
   --  ================================================================
   procedure CG_Stmt (N : Node_Addr);        --  forward
   procedure CG_Func_Decl (N : Node_Addr);   --  forward
   procedure CG_Typed_Const (N : Node_Addr; Is_Local : Boolean);  --  forward

   procedure Emit_Write_Arg (Arg : Node_Addr) is
      Kind   : constant Integer := Integer (Get_Kind (Arg));
   begin
      Emit_Indent;
      if Kind = ND_WRITE_FMT then
         --  expr:width or expr:width:prec
         declare
            Inner : constant Node_Addr := Get_Child (Arg, 0);
            Expr_S: constant String    := CG_Expr (Inner);
            RK    : constant Integer   := Integer (RType_Kind (Inner));
            Width : constant Integer   := Integer (Get_Arr_Lo (Arg));
            Prec  : constant Integer   := Integer (Get_Arr_Hi (Arg));
            Fmt   : Unbounded_String;
         begin
            Append (Fmt, "%");
            Append (Fmt, I_Img (Width));
            if Prec >= 0 then
               Append (Fmt, ".");
               Append (Fmt, I_Img (Prec));
               Append (Fmt, "f");
            elsif RK = TY_REAL then
               Append (Fmt, "g");
            elsif RK = TY_STRING or RK = TY_STRING_FIXED then
               Append (Fmt, "s");
            elsif RK = TY_CHAR then
               Append (Fmt, "c");
            else
               Append (Fmt, "d");
            end if;
            EL ("printf(""" & To_String (Fmt) & """, " & Expr_S & ");");
         end;
      else
         declare
            Expr_S : constant String  := CG_Expr (Arg);
            RK     : constant Integer := Integer (RType_Kind (Arg));
            Fmt    : constant String  := Fmt_For_RType (RK);
         begin
            if RK = TY_BOOL then
               EL ("printf(""%s"", (" & Expr_S & ") ? ""TRUE"" : ""FALSE"");");
            else
               EL ("printf(""" & Fmt & """, " & Expr_S & ");");
            end if;
         end;
      end if;
   end Emit_Write_Arg;

   --  Emit a single write arg to a file handle (using fprintf)
   procedure Emit_FWrite_Arg (File_S : String; Arg : Node_Addr) is
      Kind   : constant Integer := Integer (Get_Kind (Arg));
   begin
      Emit_Indent;
      if Kind = ND_WRITE_FMT then
         declare
            Inner : constant Node_Addr := Get_Child (Arg, 0);
            Expr_S: constant String    := CG_Expr (Inner);
            RK    : constant Integer   := Integer (RType_Kind (Inner));
            Width : constant Integer   := Integer (Get_Arr_Lo (Arg));
            Prec  : constant Integer   := Integer (Get_Arr_Hi (Arg));
            Fmt   : Unbounded_String;
         begin
            Append (Fmt, "%");
            Append (Fmt, I_Img (Width));
            if Prec >= 0 then
               Append (Fmt, ".");
               Append (Fmt, I_Img (Prec));
               Append (Fmt, "f");
            elsif RK = TY_REAL then
               Append (Fmt, "g");
            elsif RK = TY_STRING or RK = TY_STRING_FIXED then
               Append (Fmt, "s");
            elsif RK = TY_CHAR then
               Append (Fmt, "c");
            else
               Append (Fmt, "d");
            end if;
            EL ("fprintf((" & File_S & ").fp, """ & To_String (Fmt) &
                """, " & Expr_S & ");");
         end;
      else
         declare
            Expr_S : constant String  := CG_Expr (Arg);
            RK     : constant Integer := Integer (RType_Kind (Arg));
            Fmt    : constant String  := Fmt_For_RType (RK);
         begin
            EL ("fprintf((" & File_S & ").fp, """ & Fmt & """, " & Expr_S & ");");
         end;
      end if;
   end Emit_FWrite_Arg;

   procedure CG_Stmt (N : Node_Addr) is
      Kind : Integer;
   begin
      if N = Null_Node then return; end if;
      Kind := Integer (Get_Kind (N));

      case Kind is
         when ND_EMPTY =>
            null;

         when ND_COMPOUND =>
            Emit_Indent; EL ("{");
            CG_Indent := CG_Indent + 1;
            for I in 0 .. Integer (Child_Count (N)) - 1 loop
               CG_Stmt (Get_Child (N, int (I)));
            end loop;
            CG_Indent := CG_Indent - 1;
            Emit_Indent; EL ("}");

         when ND_ASSIGN =>
            if int (Child_Count (N)) < 2 then return; end if;
            declare
               Lhs : constant Node_Addr := Get_Child (N, 0);
               L_S : constant String := CG_Expr (Lhs);
               R_S : constant String := CG_Expr (Get_Child (N, 1));
               FN  : constant String := To_Lower (To_String (CG_Func));
               LK  : constant Integer := Integer (RType_Kind (Lhs));
            begin
               Emit_Indent;
               if FN /= "" and To_Lower (L_S) = FN then
                  EL ("__pascal_ret__ = " & R_S & ";");
               elsif LK = TY_STRING_FIXED then
                  --  Fixed-length string: use strncpy for bounds safety
                  --  If RHS is a single char (TY_CHAR), wrap as compound literal
                  declare
                     Rhs      : constant Node_Addr := Get_Child (N, 1);
                     RK       : constant Integer   := Integer (RType_Kind (Rhs));
                     Cap      : constant Integer   := Integer (RType_Arr_Hi (Lhs));
                     N_S      : constant String    :=
                       (if Cap > 0 then ", " & I_Img (Cap) else "");
                     R_As_Str : constant String :=
                       (if RK = TY_CHAR
                        then "(char[]){" & R_S & ", 0}"
                        else R_S);
                  begin
                     EL ("strncpy(" & L_S & ", " & R_As_Str & N_S & ");");
                  end;
               else
                  EL (L_S & " = " & R_S & ";");
               end if;
            end;

         when ND_IF =>
            if int (Child_Count (N)) < 2 then return; end if;
            declare
               Cond_S : constant String := CG_Expr (Get_Child (N, 0));
            begin
               Emit_Indent; EL ("if (" & Cond_S & ")");
               CG_Indent := CG_Indent + 1;
               CG_Stmt (Get_Child (N, 1));
               CG_Indent := CG_Indent - 1;
               if int (Child_Count (N)) > 2 then
                  Emit_Indent; EL ("else");
                  CG_Indent := CG_Indent + 1;
                  CG_Stmt (Get_Child (N, 2));
                  CG_Indent := CG_Indent - 1;
               end if;
            end;

         when ND_WHILE =>
            if int (Child_Count (N)) < 2 then return; end if;
            declare
               Cond_S : constant String := CG_Expr (Get_Child (N, 0));
            begin
               Emit_Indent; EL ("while (" & Cond_S & ")");
               CG_Indent := CG_Indent + 1;
               CG_Stmt (Get_Child (N, 1));
               CG_Indent := CG_Indent - 1;
            end;

         when ND_FOR =>
            if int (Child_Count (N)) < 4 then return; end if;
            declare
               Var_S  : constant String  := CG_Expr (Get_Child (N, 0));
               From_S : constant String  := CG_Expr (Get_Child (N, 1));
               To_S   : constant String  := CG_Expr (Get_Child (N, 2));
               Downto : constant Boolean := Integer (Get_Flags (N)) /= 0;
            begin
               Emit_Indent;
               if Downto then
                  EL ("for (" & Var_S & " = " & From_S &
                      "; " & Var_S & " >= " & To_S &
                      "; --" & Var_S & ")");
               else
                  EL ("for (" & Var_S & " = " & From_S &
                      "; " & Var_S & " <= " & To_S &
                      "; ++" & Var_S & ")");
               end if;
               CG_Indent := CG_Indent + 1;
               CG_Stmt (Get_Child (N, 3));
               CG_Indent := CG_Indent - 1;
            end;

         when ND_FOR_IN =>
            if int (Child_Count (N)) < 4 then return; end if;
            declare
               Var_S  : constant String := CG_Expr (Get_Child (N, 0));
               From_S : constant String := CG_Expr (Get_Child (N, 1));
               To_S   : constant String := CG_Expr (Get_Child (N, 2));
            begin
               Emit_Indent;
               EL ("for (" & Var_S & " = " & From_S &
                   "; " & Var_S & " <= " & To_S &
                   "; ++" & Var_S & ")");
               CG_Indent := CG_Indent + 1;
               CG_Stmt (Get_Child (N, 3));
               CG_Indent := CG_Indent - 1;
            end;

         when ND_REPEAT =>
            if int (Child_Count (N)) < 1 then return; end if;
            Emit_Indent; EL ("do {");
            CG_Indent := CG_Indent + 1;
            for I in 0 .. Integer (Child_Count (N)) - 2 loop
               CG_Stmt (Get_Child (N, int (I)));
            end loop;
            CG_Indent := CG_Indent - 1;
            declare
               Cond_S : constant String :=
                 CG_Expr (Get_Child (N, int (Child_Count (N) - 1)));
            begin
               Emit_Indent; EL ("} while (!(" & Cond_S & "));");
            end;

         when ND_CASE =>
            if int (Child_Count (N)) < 1 then return; end if;
            declare
               Expr_S : constant String := CG_Expr (Get_Child (N, 0));
            begin
               Emit_Indent; EL ("switch (" & Expr_S & ") {");
               CG_Indent := CG_Indent + 1;
               for I in 1 .. Integer (Child_Count (N)) - 1 loop
                  CG_Stmt (Get_Child (N, int (I)));
               end loop;
               CG_Indent := CG_Indent - 1;
               Emit_Indent; EL ("}");
            end;

         when ND_CASE_ELEM =>
            --  children: [label1, ..., stmt]  – last child is the body
            if int (Child_Count (N)) < 1 then return; end if;
            declare
               N_Lab : constant Integer := Integer (Child_Count (N)) - 1;
            begin
               for I in 0 .. N_Lab - 1 loop
                  declare
                     Lab  : constant Node_Addr := Get_Child (N, int (I));
                     LKind: constant Integer   := Integer (Get_Kind (Lab));
                  begin
                     Emit_Indent;
                     if LKind = ND_INT_LIT then
                        if Integer (Get_Ival (Lab)) = -1 then
                           EL ("default:");  --  case else sentinel
                        else
                           EL ("case " & I_Img (Integer (Get_Ival (Lab))) & ":");
                        end if;
                     elsif LKind = ND_CASE_RANGE then
                        --  GCC range extension: case lo ... hi:
                        EL ("case " & I_Img (Integer (Get_Arr_Lo (Lab))) &
                            " ... " & I_Img (Integer (Get_Arr_Hi (Lab))) & ":");
                     elsif LKind = ND_IDENT then
                        EL ("case " & S (Get_Sval (Lab)) & ":");
                     else
                        EL ("case " & CG_Expr (Lab) & ":");
                     end if;
                  end;
               end loop;
               CG_Indent := CG_Indent + 1;
               CG_Stmt (Get_Child (N, int (Child_Count (N) - 1)));
               Emit_Indent; EL ("break;");
               CG_Indent := CG_Indent - 1;
            end;

         when ND_WITH =>
            if int (Child_Count (N)) < 2 then return; end if;
            declare
               Var   : constant Node_Addr := Get_Child (N, 0);
               VN    : constant String    := S (Get_Sval (Var));
               VRT   : constant RType_Addr :=
                 Symtab.Lookup_Var (CG_ST_Ptr.all, VN);
               TName : Unbounded_String;
            begin
               if VRT /= Null_RType then
                  TName := To_Unbounded_String
                    (S (RT_Get_Name (VRT)));
               end if;
               Emit_Indent; EL ("{ /* with */");
               CG_Indent := CG_Indent + 1;
               if CG_WDepth < Max_CG_With then
                  CG_With (CG_WDepth).Var_Name  :=
                    To_Unbounded_String (VN);
                  CG_With (CG_WDepth).Type_Name := TName;
                  CG_WDepth := CG_WDepth + 1;
               end if;
               CG_Stmt (Get_Child (N, 1));
               if CG_WDepth > 0 then
                  CG_WDepth := CG_WDepth - 1;
               end if;
               CG_Indent := CG_Indent - 1;
               Emit_Indent; EL ("}");
            end;

         when ND_WRITELN | ND_WRITE =>
            declare
               Num_Args  : constant Integer := Integer (Child_Count (N));
               --  Check if first arg is a file variable (TY_FILE)
               Has_File  : constant Boolean :=
                 Num_Args > 0 and then
                 Integer (RType_Kind (Get_Child (N, 0))) = TY_FILE;
               Start_I   : constant Integer := (if Has_File then 1 else 0);
               File_S    : constant String  :=
                 (if Has_File then CG_Expr (Get_Child (N, 0)) else "");
               Val_Args  : constant Integer := Num_Args - Start_I;
               Needs_Braces : constant Boolean :=
                 (Kind = ND_WRITELN and Val_Args > 0) or Val_Args > 1;
            begin
               if Needs_Braces then
                  Emit_Indent; EL ("{");
                  CG_Indent := CG_Indent + 1;
               end if;
               for I in Start_I .. Num_Args - 1 loop
                  if Has_File then
                     Emit_FWrite_Arg (File_S, Get_Child (N, int (I)));
                  else
                     Emit_Write_Arg (Get_Child (N, int (I)));
                  end if;
               end loop;
               if Kind = ND_WRITELN then
                  Emit_Indent;
                  if Has_File then
                     EL ("fprintf((" & File_S & ").fp, ""\n"");");
                  else
                     EL ("printf(""\n"");");
                  end if;
               end if;
               if Needs_Braces then
                  CG_Indent := CG_Indent - 1;
                  Emit_Indent; EL ("}");
               end if;
            end;

         when ND_READLN | ND_READ =>
            declare
               Num_Args  : constant Integer := Integer (Child_Count (N));
               Is_Readln : constant Boolean :=
                 Integer (Get_Kind (N)) = ND_READLN;
               Has_File  : constant Boolean :=
                 Num_Args > 0 and then
                 Integer (RType_Kind (Get_Child (N, 0))) = TY_FILE;
               Start_I   : constant Integer := (if Has_File then 1 else 0);
               File_S    : constant String  :=
                 (if Has_File then CG_Expr (Get_Child (N, 0)) else "");
               Last_Was_Str : Boolean := False;
            begin
               for I in Start_I .. Num_Args - 1 loop
                  declare
                     Arg   : constant Node_Addr := Get_Child (N, int (I));
                     Arg_S : constant String    := CG_Expr (Arg);
                     RK    : constant Integer   := Integer (RType_Kind (Arg));
                  begin
                     Emit_Indent;
                     Last_Was_Str := False;
                     if Has_File then
                        EL ("PASCAL_FREADLN(" & File_S & ", " & Arg_S & ");");
                     elsif RK = TY_REAL then
                        EL ("scanf("" %lf"", &(" & Arg_S & "));");
                     elsif RK = TY_CHAR then
                        EL ("scanf(""%c"", &(" & Arg_S & "));");
                     elsif RK = TY_STRING or RK = TY_STRING_FIXED then
                        --  fgets already consumes the newline
                        EL ("PASCAL_READ_LINE(" & Arg_S & ");");
                        Last_Was_Str := True;
                     else
                        EL ("scanf("" %d"", &(" & Arg_S & "));");
                     end if;
                  end;
               end loop;
               --  readln: flush to end of current input line
               --  (skip if last arg was a string — fgets already consumed it)
               if Is_Readln and then not Has_File
                  and then not Last_Was_Str
               then
                  Emit_Indent; EL ("PASCAL_SKIP_LINE();");
               end if;
            end;

         when ND_INC =>
            if int (Child_Count (N)) = 1 then
               Emit_Indent;
               EL (CG_Expr (Get_Child (N, 0)) & "++;");
            elsif int (Child_Count (N)) >= 2 then
               Emit_Indent;
               EL (CG_Expr (Get_Child (N, 0)) & " += " &
                   CG_Expr (Get_Child (N, 1)) & ";");
            end if;

         when ND_DEC =>
            if int (Child_Count (N)) = 1 then
               Emit_Indent;
               EL (CG_Expr (Get_Child (N, 0)) & "--;");
            elsif int (Child_Count (N)) >= 2 then
               Emit_Indent;
               EL (CG_Expr (Get_Child (N, 0)) & " -= " &
                   CG_Expr (Get_Child (N, 1)) & ";");
            end if;

         when ND_NEW =>
            if int (Child_Count (N)) = 1 then
               Emit_Indent;
               EL ("PASCAL_NEW(" & CG_Expr (Get_Child (N, 0)) & ");");
            end if;

         when ND_DISPOSE =>
            if int (Child_Count (N)) = 1 then
               Emit_Indent;
               EL ("PASCAL_DISPOSE(" & CG_Expr (Get_Child (N, 0)) & ");");
            end if;

         when ND_ASSIGN_FILE =>
            if int (Child_Count (N)) = 2 then
               Emit_Indent;
               EL ("pascal_assign(" & CG_Expr (Get_Child (N, 0)) &
                   ", " & CG_Expr (Get_Child (N, 1)) & ");");
            end if;

         when ND_REWRITE =>
            if int (Child_Count (N)) = 1 then
               Emit_Indent;
               EL ("pascal_rewrite(" & CG_Expr (Get_Child (N, 0)) & ");");
            end if;

         when ND_RESET =>
            if int (Child_Count (N)) = 1 then
               Emit_Indent;
               EL ("pascal_reset(" & CG_Expr (Get_Child (N, 0)) & ");");
            end if;

         when ND_CLOSE_FILE =>
            if int (Child_Count (N)) = 1 then
               Emit_Indent;
               EL ("pascal_close(" & CG_Expr (Get_Child (N, 0)) & ");");
            end if;

         when ND_HALT =>
            Emit_Indent;
            if int (Child_Count (N)) = 0 then
               EL ("exit(0);");
            else
               EL ("exit(" & CG_Expr (Get_Child (N, 0)) & ");");
            end if;

         when ND_EXIT =>
            Emit_Indent;
            if int (Child_Count (N)) > 0 then
               declare
                  V_S  : constant String  := CG_Expr (Get_Child (N, 0));
                  FN   : constant String  := To_String (CG_Func);
               begin
                  if FN /= "" and not CG_Is_Proc then
                     EL ("__pascal_ret__ = " & V_S &
                         "; return __pascal_ret__;");
                  else
                     EL ("return " & V_S & ";");
                  end if;
               end;
            else
               if To_String (CG_Func) /= "" and not CG_Is_Proc then
                  EL ("return __pascal_ret__;");
               elsif CG_Is_Proc then
                  EL ("return;");
               else
                  EL ("return 0;");
               end if;
            end if;

         when ND_TRY =>
            --  try/except or try/finally
            declare
               Is_Finally : constant Boolean := Integer (Get_Flags (N)) = 2;
               Body_Node  : constant Node_Addr := Get_Child (N, 0);
               Other_Node : constant Node_Addr :=
                 (if int (Child_Count (N)) > 1
                  then Get_Child (N, 1)
                  else Null_Node);
            begin
               Emit_Indent; EL ("PASCAL_TRY");
               CG_Stmt (Body_Node);
               if Is_Finally then
                  Emit_Indent; EL ("PASCAL_FINALLY");
                  if Other_Node /= Null_Node then
                     CG_Stmt (Other_Node);
                  end if;
               else
                  Emit_Indent; EL ("PASCAL_EXCEPT");
                  if Other_Node /= Null_Node then
                     --  Iterate handler children
                     for I in 0 .. Integer (Child_Count (Other_Node)) - 1 loop
                        CG_Stmt (Get_Child (Other_Node, int (I)));
                     end loop;
                  end if;
               end if;
               Emit_Indent; EL ("PASCAL_END_TRY;");
            end;

         when ND_EXCEPT_HANDLER =>
            --  Individual handler or catch-all
            declare
               Is_Catchall : constant Boolean := Integer (Get_Flags (N)) = 1;
               CC          : constant Integer := Integer (Child_Count (N));
               Has_Var     : constant Boolean :=
                  (not Is_Catchall) and then CC >= 2 and then
                  Integer (Get_Kind (Get_Child (N, 0))) = ND_IDENT;
            begin
               if Is_Catchall then
                  Emit_Indent; EL ("/* catch-all */");
                  if CC > 0 then CG_Stmt (Get_Child (N, 0)); end if;
               else
                  Emit_Indent;
                  EL ("/* on " & S (Get_Sval (N)) & " */");
                  if Has_Var then
                     --  on VarName: ExcType do — bind var to pascal_exc_msg
                     declare
                        Var_Name : constant String :=
                          S (Get_Sval (Get_Child (N, 0)));
                     begin
                        Emit_Indent;
                        EL ("{ const char *" & Var_Name &
                            " = pascal_exc_msg;");
                        CG_Stmt (Get_Child (N, 1));
                        Emit_Indent; EL ("}");
                     end;
                  elsif CC > 0 then
                     CG_Stmt (Get_Child (N, 0));
                  end if;
               end if;
            end;

         when ND_RAISE =>
            Emit_Indent;
            if int (Child_Count (N)) > 0 then
               EL ("PASCAL_RAISE_MSG(" & CG_Expr (Get_Child (N, 0)) & ");");
            else
               EL ("PASCAL_RAISE(pascal_exc_code, pascal_exc_msg);");
            end if;

         when ND_BREAK =>
            Emit_Indent; EL ("break;");

         when ND_CONTINUE =>
            Emit_Indent; EL ("continue;");

         when ND_GOTO =>
            Emit_Indent;
            EL ("goto _lbl_" & S (Get_Sval (N)) & ";");

         when ND_LABELED_STMT =>
            declare
               Lbl  : constant String   := S (Get_Sval (N));
               Stmt : constant Node_Addr := Get_Child (N, 0);
            begin
               Emit_Indent;
               EL ("_lbl_" & Lbl & ":;");
               CG_Stmt (Stmt);
            end;

         when ND_PROC_CALL =>
            declare
               Name : constant String := S (Get_Sval (N));
               Lo   : constant String := To_Lower (Name);
               CC   : constant Integer := Integer (Child_Count (N));
               Args : Unbounded_String;
            begin
               for I in 0 .. CC - 1 loop
                  if I > 0 then Append (Args, ", "); end if;
                  Append (Args, CG_Expr (Get_Child (N, int (I))));
               end loop;
               Emit_Indent;
               declare
                  A : constant String := To_String (Args);
               begin
                  --  Map Pascal procedure names to C helpers
                  if    Lo = "delete" then
                     EL ("pascal_delete(" & A & ");");
                  elsif Lo = "insert" then
                     EL ("pascal_insert(" & A & ");");
                  elsif Lo = "str" and then CC = 2 then
                     --  str(n, s): n can be integer or real
                     declare
                        Num_RK : constant Integer :=
                          Integer (RType_Kind (Get_Child (N, 0)));
                        Num_S  : constant String := CG_Expr (Get_Child (N, 0));
                        Dst_S  : constant String := CG_Expr (Get_Child (N, 1));
                     begin
                        if Num_RK = TY_REAL then
                           EL ("sprintf(" & Dst_S & ", ""%g"", (double)(" &
                               Num_S & "));");
                        else
                           EL ("sprintf(" & Dst_S & ", ""%d"", (int)(" &
                               Num_S & "));");
                        end if;
                     end;
                  elsif Lo = "val" and then CC = 3 then
                     --  val(s, n, code) — last two args need address-of
                     declare
                        S0 : constant String := CG_Expr (Get_Child (N, 0));
                        S1 : constant String := CG_Expr (Get_Child (N, 1));
                        S2 : constant String := CG_Expr (Get_Child (N, 2));
                     begin
                        EL ("pascal_val(" & S0 & ", &(" & S1 &
                            "), &(" & S2 & "));");
                     end;
                  elsif A /= "" then
                     EL (Name & "(" & A & ");");
                  else
                     EL (Name & "();");
                  end if;
               end;
            end;

         when others =>
            --  Expression-as-statement
            Emit_Indent; EL (CG_Expr (N) & ";");
      end case;
   end CG_Stmt;

   --  ================================================================
   --  Emit a type declaration
   --  ================================================================
   procedure CG_Type_Decl (N : Node_Addr) is
   begin
      if int (Child_Count (N)) = 0 then return; end if;
      declare
         TName : constant String    := S (Get_Sval (N));
         TNode : constant Node_Addr := Get_Child (N, 0);
         TKind : constant Integer   := Integer (Get_Kind (TNode));
      begin
         if TKind = ND_TYPE_RECORD then
            EL ("typedef struct {");
            for I in 0 .. Integer (Child_Count (TNode)) - 1 loop
               declare
                  FD  : constant Node_Addr := Get_Child (TNode, int (I));
                  FK  : constant Integer   := Integer (Get_Kind (FD));
               begin
                  if FK = ND_VARIANT_PART then
                     --  Emit tag field (child 0) if not ND_EMPTY
                     declare
                        Tag : constant Node_Addr := Get_Child (FD, 0);
                        TgK : constant Integer   := Integer (Get_Kind (Tag));
                     begin
                        if TgK /= ND_EMPTY then
                           declare
                              TagT : constant Node_Addr :=
                                (if int (Child_Count (Tag)) > 0
                                 then Get_Child (Tag, 0) else Null_Node);
                           begin
                              EL ("    " & Type_C_Base (TagT) & " " &
                                  S (Get_Sval (Tag)) & Type_C_Suffix (TagT) & ";");
                           end;
                        end if;
                     end;
                     --  Emit anonymous union of anonymous structs
                     EL ("    union {");
                     for V in 1 .. Integer (Child_Count (FD)) - 1 loop
                        declare
                           VI    : constant Node_Addr := Get_Child (FD, int (V));
                           VCC   : constant Integer   := Integer (Child_Count (VI));
                           Past_Sep : Boolean := False;
                        begin
                           EL ("        struct {");
                           for F in 0 .. VCC - 1 loop
                              declare
                                 FC : constant Node_Addr := Get_Child (VI, int (F));
                                 FCK: constant Integer   := Integer (Get_Kind (FC));
                              begin
                                 if FCK = ND_EMPTY and then
                                    Integer (Get_Flags (FC)) = -1 then
                                    Past_Sep := True;  -- separator sentinel
                                 elsif Past_Sep and FCK = ND_VAR_DECL then
                                    declare
                                       FT : constant Node_Addr :=
                                         (if int (Child_Count (FC)) > 0
                                          then Get_Child (FC, 0) else Null_Node);
                                    begin
                                       EL ("            " & Type_C_Base (FT) &
                                           " " & S (Get_Sval (FC)) &
                                           Type_C_Suffix (FT) & ";");
                                    end;
                                 end if;
                              end;
                           end loop;
                           EL ("        };");
                        end;
                     end loop;
                     EL ("    };");
                  else
                     --  Regular field
                     declare
                        FT  : Node_Addr := Null_Node;
                        Base: String (1 .. 64) := (others => ' ');
                        BLen: Natural := 0;
                        Suf : String (1 .. 64) := (others => ' ');
                        SLen: Natural := 0;
                     begin
                        if int (Child_Count (FD)) > 0 then
                           FT := Get_Child (FD, 0);
                        end if;
                        declare
                           B : constant String := Type_C_Base (FT);
                           SF: constant String := Type_C_Suffix (FT);
                        begin
                           BLen := B'Length;
                           Base (1 .. BLen) := B;
                           SLen := SF'Length;
                           Suf (1 .. SLen) := SF;
                        end;
                        EL ("    " & Base (1 .. BLen) & " " &
                            S (Get_Sval (FD)) &
                            Suf (1 .. SLen) & ";");
                     end;
                  end if;
               end;
            end loop;
            EL ("} " & TName & ";");
            New_Line (CG_Out_Ptr.all);
         elsif TKind = ND_TYPE_ENUM then
            E ("typedef enum { ");
            for I in 0 .. Integer (Child_Count (TNode)) - 1 loop
               if I > 0 then E (", "); end if;
               E (S (Get_Sval (Get_Child (TNode, int (I)))));
            end loop;
            EL ("} " & TName & ";");
            New_Line (CG_Out_Ptr.all);
         else
            declare
               Base : constant String := Type_C_Base (TNode);
               Suf  : constant String := Type_C_Suffix (TNode);
            begin
               if Integer (Get_Kind (TNode)) = ND_TYPE_FUNCPTR then
                  --  typedef rettype (*TName)(params);
                  declare
                     Is_Proc : constant Boolean := Integer (Get_Flags (TNode)) = 1;
                     Ret     : constant Node_Addr := Get_Child (TNode, 0);
                     RetBase : constant String    :=
                       (if Is_Proc then "void" else Type_C_Base (Ret));
                     CC      : constant Integer := Integer (Child_Count (TNode));
                     Params  : Unbounded_String;
                  begin
                     for I in 1 .. CC - 1 loop
                        declare
                           P  : constant Node_Addr := Get_Child (TNode, int (I));
                           PT : constant Node_Addr :=
                             (if int (Child_Count (P)) > 0 then Get_Child (P, 0) else Null_Node);
                        begin
                           if I > 1 then Append (Params, ", "); end if;
                           Append (Params, Type_C_Base (PT));
                        end;
                     end loop;
                     if CC <= 1 then Append (Params, "void"); end if;
                     EL ("typedef " & RetBase & " (*" & TName & ")(" &
                         To_String (Params) & ");");
                     New_Line (CG_Out_Ptr.all);
                  end;
               else
                  EL ("typedef " & Base & " " & TName & Suf & ";");
                  New_Line (CG_Out_Ptr.all);
               end if;
            end;
         end if;
      end;
   end CG_Type_Decl;

   --  ================================================================
   --  Emit a variable declaration
   --  ================================================================
   procedure CG_Var_Decl (N : Node_Addr; Is_Local : Boolean) is
   begin
      if int (Child_Count (N)) = 0 then return; end if;
      declare
         TNode : constant Node_Addr := Get_Child (N, 0);
         TKind : constant Integer   := Integer (Get_Kind (TNode));
         VName : constant String    := S (Get_Sval (N));
      begin
         if Is_Local then Emit_Indent; end if;
         if TKind = ND_TYPE_FUNCPTR then
            --  Emit inline function pointer: rettype (*name)(params)
            declare
               Is_Proc : constant Boolean := Integer (Get_Flags (TNode)) = 1;
               Ret     : constant Node_Addr := Get_Child (TNode, 0);
               RetBase : constant String    :=
                 (if Is_Proc then "void" else Type_C_Base (Ret));
               CC      : constant Integer := Integer (Child_Count (TNode));
               Params  : Unbounded_String;
            begin
               for I in 1 .. CC - 1 loop
                  declare
                     P  : constant Node_Addr := Get_Child (TNode, int (I));
                     PT : constant Node_Addr :=
                       (if int (Child_Count (P)) > 0 then Get_Child (P, 0) else Null_Node);
                  begin
                     if I > 1 then Append (Params, ", "); end if;
                     Append (Params, Type_C_Base (PT));
                  end;
               end loop;
               if CC <= 1 then Append (Params, "void"); end if;
               EL (RetBase & " (*" & VName & ")(" & To_String (Params) & ") = NULL;");
            end;
         else
            declare
               Base : constant String := Type_C_Base (TNode);
               Suf  : constant String := Type_C_Suffix (TNode);
               Init : constant String := Type_C_Init (TNode);
            begin
               EL (Base & " " & VName & Suf & Init & ";");
            end;
         end if;
      end;
   end CG_Var_Decl;

   --  ================================================================
   --  Emit a typed constant declaration (Pascal: const N: T = val)
   --  Emitted as a C static variable with initializer.
   --  ================================================================
   procedure CG_Typed_Const (N : Node_Addr; Is_Local : Boolean) is
   begin
      if int (Child_Count (N)) < 2 then return; end if;
      declare
         Name   : constant String    := S (Get_Sval (N));
         T_Node : constant Node_Addr := Get_Child (N, 0);
         I_Node : constant Node_Addr := Get_Child (N, 1);
         TK     : constant Integer   := Integer (Get_Kind (T_Node));
         IK     : constant Integer   := Integer (Get_Kind (I_Node));
         Base   : constant String    := Type_C_Base (T_Node);
         Suf    : constant String    := Type_C_Suffix (T_Node);
      begin
         if Is_Local then Emit_Indent; end if;
         if TK = ND_TYPE_ARRAY and then IK = ND_CONST_INIT then
            --  Array typed const: static int name[N] = {a, b, c};
            declare
               Items : Unbounded_String;
               CC    : constant Integer := Integer (Child_Count (I_Node));
            begin
               for I in 0 .. CC - 1 loop
                  if I > 0 then Append (Items, ", "); end if;
                  Append (Items, CG_Expr (Get_Child (I_Node, int (I))));
               end loop;
               EL ("static " & Base & " " & Name & Suf &
                   " = {" & To_String (Items) & "};");
            end;
         else
            --  Scalar typed const: static type name = expr;
            EL ("static " & Base & " " & Name & Suf &
                " = " & CG_Expr (I_Node) & ";");
         end if;
      end;
   end CG_Typed_Const;
   --  ================================================================
   procedure CG_Func_Decl_Proto (N : Node_Addr) is
      Old : constant Interfaces.C.int := Get_Flags (N);
   begin
      Set_Flags (N, 1);       --  temporarily mark as forward
      CG_Func_Decl (N);
      Set_Flags (N, Old);     --  restore
   end CG_Func_Decl_Proto;

   --  ================================================================
   --  Emit a function/procedure declaration
   --  ================================================================
   procedure CG_Func_Decl (N : Node_Addr) is
      Kind         : constant Integer := Integer (Get_Kind (N));
      Is_Proc      : constant Boolean := (Kind = ND_PROC_DECL);
      Is_Forward   : constant Boolean := (Integer (Get_Flags (N)) = 1);
      FName        : constant String  := S (Get_Sval (N));
      CI           : Integer := 0;
      Saved_Indent : constant Natural := CG_Indent;  --  for nesting
   begin
      --  Determine return type
      declare
         Ret_Base : String (1 .. 64) := (others => ' ');
         RBLen    : Natural          := 4;  -- "void"
         Ret_Node : Node_Addr        := Null_Node;
      begin
         Ret_Base (1 .. 4) := "void";
         if not Is_Proc and int (Child_Count (N)) > 0 then
            declare
               C0K : constant Integer :=
                 Integer (Get_Kind (Get_Child (N, 0)));
            begin
               if C0K /= ND_PARAM and C0K /= ND_VAR_DECL and C0K /= ND_COMPOUND then
                  Ret_Node := Get_Child (N, 0);
                  declare
                     B : constant String := Type_C_Base_Sig (Ret_Node);
                  begin
                     RBLen := B'Length;
                     Ret_Base (1 .. RBLen) := B;
                  end;
                  CI := 1;
               end if;
            end;
         end if;

         --  Emit signature (Emit_Indent for nested functions; no-op at top level)
         Emit_Indent; E (Ret_Base (1 .. RBLen) & " " & FName & "(");

         --  Find extent of params
         declare
            Param_End  : Integer := CI;
            First_Param: Boolean := True;
         begin
            while Param_End < Integer (Child_Count (N))
               and Integer (Get_Kind (Get_Child (N, int (Param_End)))) = ND_PARAM
            loop
               Param_End := Param_End + 1;
            end loop;

            for I in CI .. Param_End - 1 loop
               declare
                  P  : constant Node_Addr := Get_Child (N, int (I));
                  PT : Node_Addr := Null_Node;
                  PB : Unbounded_String;
                  PS : Unbounded_String;
               begin
                  if int (Child_Count (P)) > 0 then
                     PT := Get_Child (P, 0);
                  end if;
                  PB := To_Unbounded_String (Type_C_Base_Sig (PT));
                  PS := To_Unbounded_String (Type_C_Suffix (PT));
                  if not First_Param then E (", "); end if;
                  First_Param := False;
                  if Integer (Get_Flags (P)) /= 0 then
                     E (To_String (PB) & " *" & S (Get_Sval (P)) &
                        To_String (PS));
                  else
                     E (To_String (PB) & " " & S (Get_Sval (P)) &
                        To_String (PS));
                  end if;
               end;
            end loop;

            --  Forward declaration: emit prototype only (no body)
            if Is_Forward then
               EL (");");
               return;
            end if;

            EL (")");
            Emit_Indent; EL ("{");
            CG_Indent := Saved_Indent + 1;

            --  Return value holder for functions
            if not Is_Proc and Ret_Node /= Null_Node then
               declare
                  RB : constant String := Type_C_Base_Sig (Ret_Node);
               begin
                  Emit_Indent; EL (RB & " __pascal_ret__;");
               end;
            end if;

            --  Save/restore function context
            declare
               Saved_Func : constant Unbounded_String := CG_Func;
               Saved_Proc : constant Boolean           := CG_Is_Proc;
            begin
               CG_Func    := To_Unbounded_String (FName);
               CG_Is_Proc := Is_Proc;

               --  Nested function/procedure declarations (GCC extension)
               for I in Param_End .. Integer (Child_Count (N)) - 1 loop
                  declare
                     C  : constant Node_Addr := Get_Child (N, int (I));
                     CK : constant Integer   := Integer (Get_Kind (C));
                  begin
                     if CK = ND_FUNC_DECL or CK = ND_PROC_DECL then
                        CG_Func_Decl (C);
                     end if;
                  end;
               end loop;

               --  Local var decls (between params and body)
               for I in Param_End .. Integer (Child_Count (N)) - 1 loop
                  declare
                     C : constant Node_Addr := Get_Child (N, int (I));
                  begin
                     if Integer (Get_Kind (C)) = ND_VAR_DECL then
                        CG_Var_Decl (C, True);
                     end if;
                  end;
               end loop;

               --  Body (last ND_COMPOUND child)
               for I in reverse CI .. Integer (Child_Count (N)) - 1 loop
                  declare
                     C : constant Node_Addr := Get_Child (N, int (I));
                  begin
                     if Integer (Get_Kind (C)) = ND_COMPOUND then
                        for J in 0 .. Integer (Child_Count (C)) - 1 loop
                           CG_Stmt (Get_Child (C, int (J)));
                        end loop;
                        exit;
                     end if;
                  end;
               end loop;

               if not Is_Proc then
                  Emit_Indent; EL ("return __pascal_ret__;");
               end if;

               CG_Func    := Saved_Func;
               CG_Is_Proc := Saved_Proc;
            end;

            CG_Indent := Saved_Indent;
            Emit_Indent; EL ("}");
            if Saved_Indent = 0 then
               New_Line (CG_Out_Ptr.all);
            end if;
         end;
      end;
   end CG_Func_Decl;

   --  ================================================================
   --  Public entry point
   --  ================================================================
   procedure Generate (Root     : System.Address;
                       ST       : in out Symtab.Table;
                       Out_File : in out Ada.Text_IO.File_Type) is
      N_Children : Integer;
      N_Decls    : Integer;
      Body_Node  : Node_Addr;
   begin
      if Root = System.Null_Address then return; end if;
      if Integer (Get_Kind (Root)) /= ND_PROGRAM then return; end if;

      CG_Out_Ptr := Out_File'Unrestricted_Access;
      CG_Indent := 0;
      CG_ST_Ptr := ST'Unrestricted_Access;
      CG_Func   := Null_Unbounded_String;
      CG_Is_Proc:= False;
      CG_WDepth := 0;

      EL ("/* Generated by pascal2c – source: " & S (Get_Sval (Root)) & " */");
      EL ("#include ""pascal_runtime.h""");

      N_Children := Integer (Child_Count (Root));
      if N_Children = 0 then return; end if;

      --  Check for leading ND_USES child
      declare
         First : constant Integer := Integer (Get_Kind (Get_Child (Root, 0)));
      begin
         if First = ND_USES then
            for J in 0 .. Integer (Child_Count (Get_Child (Root, 0))) - 1 loop
               declare
                  Unit_N : constant Node_Addr :=
                    Get_Child (Get_Child (Root, 0), int (J));
                  UName  : constant String := S (Get_Sval (Unit_N));
               begin
                  EL ("#include """ & To_Lower (UName) & ".h""");
               end;
            end loop;
         end if;
      end;

      New_Line (CG_Out_Ptr.all);

      N_Decls   := N_Children - 1;
      Body_Node := Get_Child (Root, int (N_Children - 1));

      --  Pass 1: type defs + constants
      for I in 0 .. N_Decls - 1 loop
         declare
            D  : constant Node_Addr := Get_Child (Root, int (I));
            DK : constant Integer   := Integer (Get_Kind (D));
         begin
            if DK = ND_TYPE_DECL then
               CG_Type_Decl (D);
            elsif DK = ND_CONST_DECL then
               if int (Child_Count (D)) > 0 then
                  declare
                     Val_S : constant String :=
                       CG_Expr (Get_Child (D, 0));
                  begin
                     EL ("#define " & S (Get_Sval (D)) & " " & Val_S);
                  end;
               end if;
            elsif DK = ND_TYPED_CONST then
               CG_Typed_Const (D, False);
            end if;
         end;
      end loop;

      --  Pass 2: global var decls
      for I in 0 .. N_Decls - 1 loop
         declare
            D  : constant Node_Addr := Get_Child (Root, int (I));
         begin
            if Integer (Get_Kind (D)) = ND_VAR_DECL then
               CG_Var_Decl (D, False);
            end if;
         end;
      end loop;

      --  Pass 3: function/procedure definitions
      for I in 0 .. N_Decls - 1 loop
         declare
            D  : constant Node_Addr := Get_Child (Root, int (I));
            DK : constant Integer   := Integer (Get_Kind (D));
         begin
            if DK = ND_FUNC_DECL or DK = ND_PROC_DECL then
               CG_Func_Decl (D);
            end if;
         end;
      end loop;

      --  main()
      New_Line (CG_Out_Ptr.all);
      EL ("int main(void)");
      EL ("{");
      CG_Indent := 1;

      for I in 0 .. Integer (Child_Count (Body_Node)) - 1 loop
         CG_Stmt (Get_Child (Body_Node, int (I)));
      end loop;

      Emit_Indent; EL ("return 0;");
      EL ("}");
      CG_Indent := 0;
   end Generate;

   --  ================================================================
   --  Unit mode: emit header + implementation
   --  ================================================================
   procedure Generate_Unit (Root      : System.Address;
                             ST        : in out Symtab.Table;
                             Hdr_File  : in out Ada.Text_IO.File_Type;
                             Impl_File : in out Ada.Text_IO.File_Type;
                             Unit_Name : String)
   is
      Guard : constant String := To_Upper (Unit_Name) & "_H";
   begin
      if Root = System.Null_Address then return; end if;
      if Integer (Get_Kind (Root)) /= ND_UNIT then return; end if;

      CG_ST_Ptr := ST'Unrestricted_Access;
      CG_Func   := Null_Unbounded_String;
      CG_Is_Proc:= False;
      CG_WDepth := 0;

      --  ── Header file ──────────────────────────────────────────────
      CG_Out_Ptr := Hdr_File'Unrestricted_Access;
      CG_Indent := 0;
      EL ("/* Generated by pascal2c – unit: " & Unit_Name & " */");
      EL ("#ifndef " & Guard);
      EL ("#define " & Guard);
      EL ("#include ""pascal_runtime.h""");
      New_Line (CG_Out_Ptr.all);

      --  Interface section = child 0 of ND_UNIT
      if Integer (Child_Count (Root)) > 0 then
         declare
            Iface : constant Node_Addr := Get_Child (Root, 0);
         begin
            for I in 0 .. Integer (Child_Count (Iface)) - 1 loop
               declare
                  D  : constant Node_Addr := Get_Child (Iface, int (I));
                  DK : constant Integer   := Integer (Get_Kind (D));
               begin
                  if DK = ND_TYPE_DECL then
                     CG_Type_Decl (D);
                  elsif DK = ND_CONST_DECL then
                     if int (Child_Count (D)) > 0 then
                        EL ("#define " & S (Get_Sval (D)) & " " &
                            CG_Expr (Get_Child (D, 0)));
                     end if;
                  elsif DK = ND_VAR_DECL then
                     --  In the header, vars are extern declarations
                     CG_Var_Decl (D, True);  --  True = extern
                  elsif DK = ND_FUNC_DECL or DK = ND_PROC_DECL then
                     --  Emit only the prototype (forward-style)
                     declare
                        Old_Flags : constant Interfaces.C.int := Get_Flags (D);
                     begin
                        CG_Func_Decl_Proto (D);
                     end;
                  end if;
               end;
            end loop;
         end;
      end if;

      New_Line (CG_Out_Ptr.all);
      EL ("#endif /* " & Guard & " */");

      --  ── Implementation file ──────────────────────────────────────
      CG_Out_Ptr := Impl_File'Unrestricted_Access;
      CG_Indent := 0;
      EL ("/* Generated by pascal2c – unit: " & Unit_Name & " (implementation) */");
      EL ("#include """ & To_Lower (Unit_Name) & ".h""");
      New_Line (CG_Out_Ptr.all);

      --  Implementation section = child 1 of ND_UNIT
      if Integer (Child_Count (Root)) > 1 then
         declare
            Impl : constant Node_Addr := Get_Child (Root, 1);
         begin
            --  Pass 1: types + consts (if any in impl section)
            for I in 0 .. Integer (Child_Count (Impl)) - 1 loop
               declare
                  D  : constant Node_Addr := Get_Child (Impl, int (I));
                  DK : constant Integer   := Integer (Get_Kind (D));
               begin
                  if DK = ND_TYPE_DECL then
                     CG_Type_Decl (D);
                  elsif DK = ND_CONST_DECL then
                     if int (Child_Count (D)) > 0 then
                        EL ("#define " & S (Get_Sval (D)) & " " &
                            CG_Expr (Get_Child (D, 0)));
                     end if;
                  end if;
               end;
            end loop;
            --  Pass 2: vars
            for I in 0 .. Integer (Child_Count (Impl)) - 1 loop
               declare
                  D  : constant Node_Addr := Get_Child (Impl, int (I));
               begin
                  if Integer (Get_Kind (D)) = ND_VAR_DECL then
                     CG_Var_Decl (D, False);
                  end if;
               end;
            end loop;
            --  Pass 3: function/procedure bodies
            for I in 0 .. Integer (Child_Count (Impl)) - 1 loop
               declare
                  D  : constant Node_Addr := Get_Child (Impl, int (I));
                  DK : constant Integer   := Integer (Get_Kind (D));
               begin
                  if DK = ND_FUNC_DECL or DK = ND_PROC_DECL then
                     CG_Func_Decl (D);
                  end if;
               end;
            end loop;
         end;
      end if;
   end Generate_Unit;

end Code_Generator;
