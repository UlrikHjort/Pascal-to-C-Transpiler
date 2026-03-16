-- ***************************************************************************
--              Pascal to C Transpiler - type checker
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
with Ada.Text_IO;
with System;

package body Type_Checker is

   use type System.Address;  --  makes "=" for Node_Addr / RType_Addr visible

   --  Error counter reset at the start of each Check call
   TC_Error_Count : Natural := 0;

   --  Set when the program has a 'uses' clause; suppresses undeclared-identifier errors
   --  so that symbols from interface-only units (header-only imports) are tolerated.
   TC_Has_Uses : Boolean := False;

   --  Emit a compiler diagnostic to stderr
   procedure Err (N : Node_Addr; Msg : String) is
      Line : constant String := Integer'Image (Integer (Get_Line (N)));
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "line" & Line & ": error: " & Msg);
      TC_Error_Count := TC_Error_Count + 1;
   end Err;

   procedure Warn (N : Node_Addr; Msg : String) is
      Line : constant String := Integer'Image (Integer (Get_Line (N)));
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "line" & Line & ": warning: " & Msg);
   end Warn;

   --  Shorthand: convert a C chars_ptr to Ada String (empty if null)
   function S (P : Interfaces.C.Strings.chars_ptr) return String is
      use Interfaces.C.Strings;
   begin
      if P = Null_Ptr then return ""; end if;
      return Value (P);
   end S;

   --  Build a plain rtype handle
   function RT (Kind : Integer) return RType_Addr is
   begin
      return RT_Make (Interfaces.C.int (Kind));
   end RT;

   --  Build a named rtype (e.g. for records/enums)
   function RT_Named (Kind : Integer; Name : String) return RType_Addr is
      use Interfaces.C.Strings;
      C_Name : chars_ptr := New_String (Name);
      Result : constant RType_Addr := RT_Make_Named (int (Kind), C_Name);
   begin
      Free (C_Name);
      return Result;
   end RT_Named;

   -- ----------------------------------------------------------------
   -- Convert an AST type-node to a ResolvedType handle
   -- ----------------------------------------------------------------
   function Type_Node_To_RT (T : Node_Addr) return RType_Addr is
      Kind : Integer;
   begin
      if T = Null_Node then
         return RT (TY_UNKNOWN);
      end if;
      Kind := Integer (Get_Kind (T));
      if    Kind = ND_TYPE_INT    then return RT (TY_INT);
      elsif Kind = ND_TYPE_REAL   then return RT (TY_REAL);
      elsif Kind = ND_TYPE_BOOL   then return RT (TY_BOOL);
      elsif Kind = ND_TYPE_CHAR   then return RT (TY_CHAR);
      elsif Kind = ND_TYPE_FILE   then return RT (TY_FILE);
      elsif Kind = ND_TYPE_FUNCPTR then return RT (TY_FUNCPTR);
      elsif Kind = ND_TYPE_STRING then
         if Integer (Get_Ival (T)) > 0 then
            declare
               R : constant RType_Addr := RT (TY_STRING_FIXED);
               N : constant Interfaces.C.int := Get_Ival (T);
            begin
               RT_Set_Array_Bounds (R, 0, N);  --  hi = N = declared capacity
               return R;
            end;
         end if;
         return RT (TY_STRING);
      elsif Kind = ND_TYPE_PTR then
         declare
            R : constant RType_Addr := RT (TY_PTR);
         begin
            if int (Child_Count (T)) > 0 then
               RT_Set_Elem (R, Type_Node_To_RT (Get_Child (T, 0)));
            end if;
            return R;
         end;
      elsif Kind = ND_TYPE_ARRAY then
         declare
            R  : constant RType_Addr := RT (TY_ARRAY);
            Lo : constant int := Get_Arr_Lo (T);
            Hi : constant int := Get_Arr_Hi (T);
         begin
            RT_Set_Array_Bounds (R, Lo, Hi);
            if int (Child_Count (T)) > 0 then
               RT_Set_Elem (R, Type_Node_To_RT (Get_Child (T, 0)));
            end if;
            return R;
         end;
      elsif Kind = ND_TYPE_NAMED then
         return RT_Named (TY_RECORD, S (Get_Sval (T)));
      elsif Kind = ND_TYPE_SET then
         declare
            R : constant RType_Addr := RT (TY_SET);
         begin
            if int (Child_Count (T)) > 0 then
               RT_Set_Elem (R, Type_Node_To_RT (Get_Child (T, 0)));
            end if;
            return R;
         end;
      elsif Kind = ND_TYPE_SUBRANGE then
         return RT (TY_INT);   --  integer subrange is ordinal; emits as int
      elsif Kind = ND_TYPE_ENUM_SUBRANGE then
         return RT (TY_INT);   --  enum subrange: treat as ordinal int
      else
         return RT (TY_UNKNOWN);
      end if;
   end Type_Node_To_RT;

   -- ----------------------------------------------------------------
   -- Built-in function return types
   -- ----------------------------------------------------------------
   function Builtin_Return_RT (Name : String) return RType_Addr is
      Lo : constant String := To_Lower (Name);
   begin
      if    Lo = "abs"        then return RT (TY_REAL);
      elsif Lo = "sqr"        then return RT (TY_REAL);
      elsif Lo = "sqrt"       then return RT (TY_REAL);
      elsif Lo = "sin"        then return RT (TY_REAL);
      elsif Lo = "cos"        then return RT (TY_REAL);
      elsif Lo = "ln"         then return RT (TY_REAL);
      elsif Lo = "exp"        then return RT (TY_REAL);
      elsif Lo = "frac"       then return RT (TY_REAL);
      elsif Lo = "float"      then return RT (TY_REAL);
      elsif Lo = "strtofloat" then return RT (TY_REAL);
      elsif Lo = "round"      then return RT (TY_INT);
      elsif Lo = "trunc"      then return RT (TY_INT);
      elsif Lo = "ord"        then return RT (TY_INT);
      elsif Lo = "succ"       then return RT (TY_INT);
      elsif Lo = "pred"       then return RT (TY_INT);
      elsif Lo = "odd"        then return RT (TY_INT);
      elsif Lo = "integer"    then return RT (TY_INT);
      elsif Lo = "length"     then return RT (TY_INT);
      elsif Lo = "pos"        then return RT (TY_INT);
      elsif Lo = "strtoint"   then return RT (TY_INT);
      elsif Lo = "random"     then return RT (TY_REAL);  -- random(n)->int or random->real
      elsif Lo = "chr"        then return RT (TY_CHAR);
      elsif Lo = "upcase"     then return RT (TY_CHAR);
      elsif Lo = "copy"       then return RT (TY_STRING);
      elsif Lo = "concat"     then return RT (TY_STRING);
      elsif Lo = "inttostr"   then return RT (TY_STRING);
      elsif Lo = "floattostr" then return RT (TY_STRING);
      elsif Lo = "formatfloat" then return RT (TY_STRING);
      elsif Lo = "trim"       then return RT (TY_STRING);
      elsif Lo = "lowercase"  then return RT (TY_STRING);
      elsif Lo = "uppercase"  then return RT (TY_STRING);
      --  Procedures that return void but appear as calls
      elsif Lo = "delete" or else Lo = "insert" or else
            Lo = "str"    or else Lo = "val"
                              then return RT (TY_VOID);
      elsif Lo = "eof" or else Lo = "eoln"
                              then return RT (TY_BOOL);
      --  Terminal / ANSI helpers
      elsif Lo = "keypressed"   then return RT (TY_BOOL);
      elsif Lo = "readkey"      then return RT (TY_CHAR);
      elsif Lo = "clrscr"    or else Lo = "gotoxy"      or else
            Lo = "delay"     or else Lo = "textcolor"   or else
            Lo = "hidecursor" or else Lo = "showcursor" or else
            Lo = "rawmode"   or else Lo = "normalmode" or else
            Lo = "randomize"
                               then return RT (TY_VOID);
      else                         return Null_RType;
      end if;
   end Builtin_Return_RT;

   -- ----------------------------------------------------------------
   -- Forward declarations
   -- ----------------------------------------------------------------
   procedure TC_Node (N : Node_Addr; ST : in out Symtab.Table);
   procedure TC_Expr (N : Node_Addr; ST : in out Symtab.Table);

   -- ----------------------------------------------------------------
   -- Expression type annotation
   -- ----------------------------------------------------------------
   procedure TC_Expr (N : Node_Addr; ST : in out Symtab.Table) is
      Kind : Integer;
   begin
      if N = Null_Node then return; end if;
      Kind := Integer (Get_Kind (N));

      --  Recurse into children first
      for I in 0 .. Integer (Child_Count (N)) - 1 loop
         TC_Expr (Get_Child (N, int (I)), ST);
      end loop;

      case Kind is
         when ND_INT_LIT  => Set_RType (N, RT (TY_INT));
         when ND_REAL_LIT => Set_RType (N, RT (TY_REAL));
         when ND_STR_LIT  =>
            --  Single-character string literal behaves as TY_CHAR
            if S (Get_Sval (N))'Length = 1 then
               Set_RType (N, RT (TY_CHAR));
            else
               Set_RType (N, RT (TY_STRING));
            end if;
         when ND_BOOL_LIT => Set_RType (N, RT (TY_BOOL));
         when ND_NIL      => Set_RType (N, RT (TY_PTR));

         when ND_IDENT =>
            declare
               Name : constant String    := S (Get_Sval (N));
               R    : RType_Addr         := Symtab.Lookup_Var (ST, Name);
               Idx  : Integer;
            begin
               if R /= Null_RType then
                  Set_RType (N, R);
               else
                  --  Check if it's a function name used as return variable
                  Idx := Symtab.Lookup_Subr_Index (ST, Name);
                  if Idx >= 0 then
                     R := ST.Subrs.Constant_Reference (Idx).Ret_RT;
                     Set_RType (N, (if R /= Null_RType then R
                                    else RT (TY_UNKNOWN)));
                  else
                     --  Check if it is a zero-arg builtin (e.g. clrscr, keypressed)
                     declare
                        BR : constant RType_Addr :=
                               Builtin_Return_RT (To_Lower (Name));
                     begin
                        if BR /= Null_RType then
                           Set_RType (N, BR);
                        else
                           if TC_Has_Uses then
                              Warn (N, "undeclared identifier '" & Name & "'");
                           else
                              Err (N, "undeclared identifier '" & Name & "'");
                           end if;
                           Set_RType (N, RT (TY_UNKNOWN));
                        end if;
                     end;
                  end if;
               end if;
            end;

         when ND_FUNC_CALL =>
            declare
               Name : constant String := To_Lower (S (Get_Sval (N)));
               R    : RType_Addr := Builtin_Return_RT (Name);
               Idx  : Integer;
            begin
               --  For abs/sqr, result type follows the argument
               if R /= Null_RType
                  and then (Name = "abs" or Name = "sqr")
               then
                  --  Override with argument type if known
                  if int (Child_Count (N)) > 0 then
                     declare
                        Arg0 : constant Node_Addr := Get_Child (N, 0);
                        AK   : constant Integer := Integer (RType_Kind (Arg0));
                     begin
                        if AK = TY_INT then
                           R := RT (TY_INT);
                        end if;
                     end;
                  end if;
               end if;

               --  random(n) -> TY_INT; random -> TY_REAL
               if R /= Null_RType and then Name = "random" then
                  if int (Child_Count (N)) > 0 then
                     R := RT (TY_INT);
                  end if;
               end if;

               if R = Null_RType then
                  Idx := Symtab.Lookup_Subr_Index (ST, Name);
                  if Idx >= 0 then
                     R := ST.Subrs.Constant_Reference (Idx).Ret_RT;
                  else
                     --  Check if it's a procedural-type variable
                     declare
                        VR   : constant RType_Addr := Symtab.Lookup_Var (ST, Name);
                        VKind : Integer := TY_UNKNOWN;
                     begin
                        if VR /= Null_RType then
                           VKind := Integer (RT_Get_Kind (VR));
                           --  If named type, check if it resolves to funcptr
                           if VKind /= TY_FUNCPTR then
                              declare
                                 TN : constant String := S (RT_Get_Name (VR));
                                 TD : constant access constant Symtab.Type_Def :=
                                   Symtab.Lookup_Type (ST, TN);
                              begin
                                 if TD /= null and then TD.RT /= Null_RType and then
                                    Integer (RT_Get_Kind (TD.RT)) = TY_FUNCPTR
                                 then
                                    VKind := TY_FUNCPTR;
                                 end if;
                              end;
                           end if;
                        end if;
                        if VKind = TY_FUNCPTR then
                           R := RT (TY_INT);  -- return type unknown; treat as int
                        else
                           Warn (N, "undeclared function '" & Name & "'");
                        end if;
                     end;
                  end if;
               end if;

               if R /= Null_RType then
                  Set_RType (N, R);
               else
                  Set_RType (N, RT (TY_UNKNOWN));
               end if;
            end;

         when ND_BINOP =>
            declare
               Op  : constant Integer := Integer (Get_Op (N));
               LK  : Integer := TY_INT;
               RK  : Integer := TY_INT;
               Res : RType_Addr;
            begin
               if int (Child_Count (N)) > 0 then
                  LK := Integer (RType_Kind (Get_Child (N, 0)));
               end if;
               if int (Child_Count (N)) > 1 then
                  RK := Integer (RType_Kind (Get_Child (N, 1)));
               end if;
               --  Comparison / logical operators -> bool
               if Op = Character'Pos ('<')
                  or Op = Character'Pos ('>')
                  or Op = Character'Pos ('=')
                  or Op = Character'Pos ('L')  -- LE
                  or Op = Character'Pos ('G')  -- GE
                  or Op = Character'Pos ('N')  -- NE
                  or Op = Character'Pos ('&')  -- AND
                  or Op = Character'Pos ('|')  -- OR
                  or Op = Character'Pos ('i')  -- IN
               then
                  Res := RT (TY_BOOL);
               else
                  --  Arithmetic: sets keep set type; strings stay string;
                  --  otherwise promote to real
                  if LK = TY_SET or RK = TY_SET then
                     Res := RT (TY_SET);
                  elsif LK = TY_STRING or LK = TY_STRING_FIXED
                     or RK = TY_STRING or RK = TY_STRING_FIXED
                  then
                     Res := RT (TY_STRING);
                  elsif LK = TY_REAL or RK = TY_REAL
                     or Op = Character'Pos ('/')
                  then
                     Res := RT (TY_REAL);
                  else
                     Res := RT (TY_INT);
                  end if;
               end if;
               Set_RType (N, Res);
            end;

         when ND_UNOP =>
            declare
               Op : constant Integer := Integer (Get_Op (N));
               CK : Integer := TY_INT;
            begin
               if int (Child_Count (N)) > 0 then
                  CK := Integer (RType_Kind (Get_Child (N, 0)));
               end if;
               if Op = Character'Pos ('!') then  -- NOT
                  Set_RType (N, RT (TY_BOOL));
               else
                  Set_RType (N, RT (CK));
               end if;
            end;

         when ND_INDEX =>
            --  base[idx] -> element type of base's array type
            if int (Child_Count (N)) > 0 then
               declare
                  Base : constant Node_Addr := Get_Child (N, 0);
                  BK   : constant Integer   := Integer (RType_Kind (Base));
               begin
                  if BK = TY_ARRAY then
                     declare
                        Elem : constant RType_Addr := RType_Elem_Of_Node (Base);
                     begin
                        if Elem /= Null_RType then
                           Set_RType (N, Elem);
                        else
                           Set_RType (N, RT (TY_UNKNOWN));
                        end if;
                     end;
                  else
                     Set_RType (N, RT (TY_UNKNOWN));
                  end if;
               end;
            end if;

         when ND_FIELD =>
            --  base.field -> look up field type in record
            if int (Child_Count (N)) > 0 then
               declare
                  Base : constant Node_Addr := Get_Child (N, 0);
                  TN   : constant String := S (RType_Name (Base));
                  FN   : constant String := S (Get_Sval (N));
                  R    : RType_Addr := Null_RType;
               begin
                  if TN /= "" then
                     R := Symtab.Lookup_Field (ST, TN, FN);
                  end if;
                  Set_RType (N, (if R /= Null_RType then R else RT (TY_UNKNOWN)));
               end;
            end if;

         when ND_DEREF =>
            if int (Child_Count (N)) > 0 then
               declare
                  Base : constant Node_Addr := Get_Child (N, 0);
                  BK   : constant Integer   := Integer (RType_Kind (Base));
                  Elem : constant RType_Addr := RType_Elem_Of_Node (Base);
               begin
                  if BK = TY_PTR and Elem /= Null_RType then
                     Set_RType (N, Elem);
                  else
                     Set_RType (N, RT (TY_UNKNOWN));
                  end if;
               end;
            end if;

         when ND_ADDR_OF =>
            Set_RType (N, RT (TY_PTR));

         when ND_SET_LIT =>
            declare
               R       : constant RType_Addr := RT (TY_SET);
               Elem_RT : RType_Addr          := RT (TY_INT);
            begin
               if int (Child_Count (N)) > 0 then
                  declare
                     CK : constant Integer :=
                       Integer (RType_Kind (Get_Child (N, 0)));
                  begin
                     if CK /= TY_UNKNOWN then Elem_RT := RT (CK); end if;
                  end;
               end if;
               RT_Set_Elem (R, Elem_RT);
               Set_RType (N, R);
            end;

         when ND_SET_RANGE =>
            if int (Child_Count (N)) > 0 then
               declare
                  CK : constant Integer :=
                    Integer (RType_Kind (Get_Child (N, 0)));
               begin
                  Set_RType (N, RT (if CK /= TY_UNKNOWN then CK else TY_INT));
               end;
            else
               Set_RType (N, RT (TY_INT));
            end if;

         when others =>
            null;  --  statements / type nodes: no rtype needed
      end case;
   end TC_Expr;

   -- ----------------------------------------------------------------
   -- Register a type declaration (ND_TYPE_DECL)
   -- ----------------------------------------------------------------
   procedure Register_Type_Decl (N : Node_Addr; ST : in out Symtab.Table) is
      TName : constant String := S (Get_Sval (N));
   begin
      if int (Child_Count (N)) = 0 then return; end if;
      declare
         TNode : constant Node_Addr := Get_Child (N, 0);
         TKind : constant Integer   := Integer (Get_Kind (TNode));
      begin
         if TKind = ND_TYPE_RECORD then
            --  Collect fields
            declare
               Fields : Symtab.Field_Vector;

               procedure Add_Fields_From_List (Parent : Node_Addr) is
               begin
                  for I in 0 .. Integer (Child_Count (Parent)) - 1 loop
                     declare
                        FD  : constant Node_Addr := Get_Child (Parent, int (I));
                        FDK : constant Integer   := Integer (Get_Kind (FD));
                        FE  : Symtab.Field_Entry;
                     begin
                        if FDK = ND_VARIANT_PART then
                           --  Skip child 0 (tag field handled below), scan variant items
                           for VI in 1 .. Integer (Child_Count (FD)) - 1 loop
                              declare
                                 Item    : constant Node_Addr := Get_Child (FD, int (VI));
                                 Past_Sep : Boolean := False;
                              begin
                                 for F in 0 .. Integer (Child_Count (Item)) - 1 loop
                                    declare
                                       FC  : constant Node_Addr := Get_Child (Item, int (F));
                                       FCK : constant Integer   := Integer (Get_Kind (FC));
                                    begin
                                       if FCK = ND_EMPTY and then
                                          Integer (Get_Flags (FC)) = -1 then
                                          Past_Sep := True;
                                       elsif Past_Sep and FCK = ND_VAR_DECL then
                                          declare
                                             VFE : Symtab.Field_Entry;
                                          begin
                                             VFE.Name := Ada.Strings.Unbounded.To_Unbounded_String
                                               (S (Get_Sval (FC)));
                                             if int (Child_Count (FC)) > 0 then
                                                VFE.RT := Type_Node_To_RT (Get_Child (FC, 0));
                                             else
                                                VFE.RT := RT (TY_UNKNOWN);
                                             end if;
                                             Fields.Append (VFE);
                                          end;
                                       end if;
                                    end;
                                 end loop;
                              end;
                           end loop;
                           --  Also register the tag field
                           declare
                              Tag  : constant Node_Addr := Get_Child (FD, 0);
                              TagK : constant Integer   := Integer (Get_Kind (Tag));
                              TgE  : Symtab.Field_Entry;
                           begin
                              if TagK = ND_VAR_DECL then
                                 TgE.Name := Ada.Strings.Unbounded.To_Unbounded_String
                                   (S (Get_Sval (Tag)));
                                 if int (Child_Count (Tag)) > 0 then
                                    TgE.RT := Type_Node_To_RT (Get_Child (Tag, 0));
                                 else
                                    TgE.RT := RT (TY_UNKNOWN);
                                 end if;
                                 Fields.Append (TgE);
                              end if;
                           end;
                        elsif FDK = ND_VAR_DECL then
                           FE.Name := Ada.Strings.Unbounded.To_Unbounded_String
                             (S (Get_Sval (FD)));
                           if int (Child_Count (FD)) > 0 then
                              FE.RT := Type_Node_To_RT (Get_Child (FD, 0));
                           else
                              FE.RT := RT (TY_UNKNOWN);
                           end if;
                           Fields.Append (FE);
                        end if;
                     end;
                  end loop;
               end Add_Fields_From_List;

            begin
               Add_Fields_From_List (TNode);
               declare
                  R : constant RType_Addr := RT_Named (TY_RECORD, TName);
               begin
                  Symtab.Add_Type (ST, TName, R, Fields);
               end;
            end;
         elsif TKind = ND_TYPE_ENUM then
            declare
               Empty_Fields : Symtab.Field_Vector;
               R : constant RType_Addr := RT_Named (TY_ENUM, TName);
            begin
               Symtab.Add_Type (ST, TName, R, Empty_Fields);
               --  Register each enum member as an integer constant in symtab
               for I in 0 .. Integer (Child_Count (TNode)) - 1 loop
                  declare
                     Member : constant Node_Addr := Get_Child (TNode, int (I));
                     MName  : constant String    := S (Get_Sval (Member));
                     MRT    : constant RType_Addr := RT (TY_INT);
                  begin
                     Symtab.Add_Var (ST, MName, MRT);
                  end;
               end loop;
            end;
         else
            declare
               R            : constant RType_Addr := Type_Node_To_RT (TNode);
               Empty_Fields : Symtab.Field_Vector;
            begin
               Symtab.Add_Type (ST, TName, R, Empty_Fields);
            end;
         end if;
      end;
   end Register_Type_Decl;

   -- ----------------------------------------------------------------
   -- Register a variable declaration (ND_VAR_DECL)
   -- ----------------------------------------------------------------
   procedure Register_Var_Decl (N : Node_Addr; ST : in out Symtab.Table) is
   begin
      if int (Child_Count (N)) = 0 then return; end if;
      declare
         R : constant RType_Addr := Type_Node_To_RT (Get_Child (N, 0));
      begin
         Symtab.Add_Var (ST, S (Get_Sval (N)), R);
      end;
   end Register_Var_Decl;

   -- ----------------------------------------------------------------
   -- Register a function/procedure declaration
   -- ----------------------------------------------------------------
   procedure Register_Func_Decl (N : Node_Addr; ST : in out Symtab.Table) is
      Kind    : constant Integer := Integer (Get_Kind (N));
      Is_Proc : constant Boolean := (Kind = ND_PROC_DECL);
      FName   : constant String  := S (Get_Sval (N));
      Params  : Symtab.Param_Vectors.Vector;
      Ret_RT  : RType_Addr := RT (TY_VOID);
      Start   : Integer := 0;
   begin
      --  Functions have their return type as children[0]
      if not Is_Proc
         and then int (Child_Count (N)) > 0
      then
         declare
            C0K : constant Integer := Integer (Get_Kind (Get_Child (N, 0)));
         begin
            if C0K /= ND_PARAM and C0K /= ND_VAR_DECL and C0K /= ND_COMPOUND then
               Ret_RT := Type_Node_To_RT (Get_Child (N, 0));
               Start  := 1;
            end if;
         end;
      end if;

      for I in Start .. Integer (Child_Count (N)) - 1 loop
         declare
            C  : constant Node_Addr := Get_Child (N, int (I));
            CK : constant Integer   := Integer (Get_Kind (C));
         begin
            if CK = ND_PARAM then
               declare
                  PE : Symtab.Param_Entry;
               begin
                  PE.Name   := Ada.Strings.Unbounded.To_Unbounded_String
                    (S (Get_Sval (C)));
                  PE.Is_Ref := Integer (Get_Flags (C)) /= 0;
                  if int (Child_Count (C)) > 0 then
                     PE.RT := Type_Node_To_RT (Get_Child (C, 0));
                  else
                     PE.RT := RT (TY_UNKNOWN);
                  end if;
                  Params.Append (PE);
               end;
            end if;
         end;
      end loop;

      Symtab.Add_Subr (ST, FName, Is_Proc, Ret_RT, Params);
   end Register_Func_Decl;

   -- ----------------------------------------------------------------
   -- Main tree walk
   -- ----------------------------------------------------------------
   procedure TC_Node (N : Node_Addr; ST : in out Symtab.Table) is
      Kind : Integer;
   begin
      if N = Null_Node then return; end if;
      Kind := Integer (Get_Kind (N));

      case Kind is
         when ND_PROGRAM | ND_UNIT | ND_INTERFACE_SEC | ND_IMPL_SEC =>
            for I in 0 .. Integer (Child_Count (N)) - 1 loop
               TC_Node (Get_Child (N, int (I)), ST);
            end loop;

         when ND_CONST_DECL =>
            --  Register constant name in symbol table so it resolves as a var
            if int (Child_Count (N)) > 0 then
               declare
                  Val  : constant Node_Addr := Get_Child (N, 0);
                  Name : constant String    := S (Get_Sval (N));
                  VRT  : RType_Addr;
               begin
                  TC_Expr (Val, ST);
                  --  Derive rtype from value kind
                  if Has_RType (Val) /= 0 then
                     VRT := RT (Integer (RType_Kind (Val)));
                  else
                     VRT := RT (TY_INT);
                  end if;
                  Symtab.Add_Var (ST, Name, VRT);
               end;
            end if;

         when ND_TYPED_CONST =>
            --  Typed constant: register as a variable with the declared type
            if int (Child_Count (N)) >= 2 then
               declare
                  T_Node : constant Node_Addr := Get_Child (N, 0);
                  I_Node : constant Node_Addr := Get_Child (N, 1);
                  Name   : constant String    := S (Get_Sval (N));
                  VRT    : constant RType_Addr := Type_Node_To_RT (T_Node);
               begin
                  TC_Expr (I_Node, ST);
                  Symtab.Add_Var (ST, Name, VRT);
               end;
            end if;

         when ND_TYPE_DECL =>
            Register_Type_Decl (N, ST);

         when ND_VAR_DECL =>
            Register_Var_Decl (N, ST);

         when ND_FUNC_DECL | ND_PROC_DECL =>
            Register_Func_Decl (N, ST);
            --  forward declaration: just register the signature, no body to walk
            if Integer (Get_Flags (N)) = 1 then
               null;
               return;
            end if;
            --  Recurse into the body with a new scope
            Symtab.Push_Scope (ST);
            declare
               Is_Proc : constant Boolean := (Kind = ND_PROC_DECL);
               Start   : Integer := 0;
            begin
               if not Is_Proc
                  and then int (Child_Count (N)) > 0
               then
                  declare
                     C0K : constant Integer :=
                       Integer (Get_Kind (Get_Child (N, 0)));
                  begin
                     if C0K /= ND_PARAM
                        and C0K /= ND_VAR_DECL
                        and C0K /= ND_COMPOUND
                     then
                        Start := 1;
                     end if;
                  end;
               end if;

               for I in Start .. Integer (Child_Count (N)) - 1 loop
                  declare
                     C  : constant Node_Addr := Get_Child (N, int (I));
                     CK : constant Integer   := Integer (Get_Kind (C));
                  begin
                     if CK = ND_PARAM then
                        declare
                           PT : RType_Addr := RT (TY_UNKNOWN);
                        begin
                           if int (Child_Count (C)) > 0 then
                              PT := Type_Node_To_RT (Get_Child (C, 0));
                           end if;
                           Symtab.Add_Var (ST, S (Get_Sval (C)), PT);
                        end;
                     elsif CK = ND_VAR_DECL then
                        Register_Var_Decl (C, ST);
                     elsif CK = ND_FUNC_DECL or CK = ND_PROC_DECL then
                        TC_Node (C, ST);   --  recursively handle nested funcs
                     elsif CK = ND_COMPOUND then
                        TC_Node (C, ST);
                     end if;
                  end;
               end loop;
            end;
            Symtab.Pop_Scope (ST);

         when ND_COMPOUND =>
            for I in 0 .. Integer (Child_Count (N)) - 1 loop
               TC_Node (Get_Child (N, int (I)), ST);
            end loop;

         when ND_ASSIGN =>
            if int (Child_Count (N)) > 1 then
               TC_Expr (Get_Child (N, 0), ST);
               TC_Expr (Get_Child (N, 1), ST);
               declare
                  LK : constant Integer := Integer (RType_Kind (Get_Child (N, 0)));
                  RK : constant Integer := Integer (RType_Kind (Get_Child (N, 1)));
               begin
                  if LK /= TY_UNKNOWN and RK /= TY_UNKNOWN
                     and LK /= RK
                     and not (LK = TY_REAL and RK = TY_INT)
                     and LK /= TY_RECORD  --  named/alias type: skip
                     and RK /= TY_RECORD
                     and not (LK = TY_STRING_FIXED and RK = TY_STRING)
                     and not (LK = TY_STRING and RK = TY_STRING_FIXED)
                     and not (LK = TY_CHAR and (RK = TY_STRING or RK = TY_CHAR))
                     and not (LK = TY_STRING and RK = TY_CHAR)
                  then
                     Warn (N, "type mismatch in assignment");
                  end if;
               end;
            end if;

         when ND_IF =>
            for I in 0 .. Integer (Child_Count (N)) - 1 loop
               TC_Node (Get_Child (N, int (I)), ST);
            end loop;
            if int (Child_Count (N)) > 0 then
               TC_Expr (Get_Child (N, 0), ST);
            end if;

         when ND_WHILE =>
            if int (Child_Count (N)) > 0 then
               TC_Expr (Get_Child (N, 0), ST);
            end if;
            for I in 1 .. Integer (Child_Count (N)) - 1 loop
               TC_Node (Get_Child (N, int (I)), ST);
            end loop;

         when ND_FOR =>
            if int (Child_Count (N)) > 2 then
               TC_Expr (Get_Child (N, 0), ST);
               TC_Expr (Get_Child (N, 1), ST);
               TC_Expr (Get_Child (N, 2), ST);
               for I in 3 .. Integer (Child_Count (N)) - 1 loop
                  TC_Node (Get_Child (N, int (I)), ST);
               end loop;
            end if;

         when ND_FOR_IN =>
            if int (Child_Count (N)) = 4 then
               TC_Expr (Get_Child (N, 1), ST);
               TC_Expr (Get_Child (N, 2), ST);
               TC_Node (Get_Child (N, 3), ST);
            end if;

         when ND_REPEAT =>
            for I in 0 .. Integer (Child_Count (N)) - 2 loop
               TC_Node (Get_Child (N, int (I)), ST);
            end loop;
            if int (Child_Count (N)) > 0 then
               TC_Expr (Get_Child (N, int (Child_Count (N) - 1)), ST);
            end if;

         when ND_CASE =>
            if int (Child_Count (N)) > 0 then
               TC_Expr (Get_Child (N, 0), ST);
            end if;
            for I in 1 .. Integer (Child_Count (N)) - 1 loop
               TC_Node (Get_Child (N, int (I)), ST);
            end loop;

         when ND_CASE_ELEM =>
            for I in 0 .. Integer (Child_Count (N)) - 1 loop
               TC_Node (Get_Child (N, int (I)), ST);
            end loop;

         when ND_WITH =>
            if int (Child_Count (N)) > 1 then
               declare
                  Var   : constant Node_Addr := Get_Child (N, 0);
                  VN    : constant String    := S (Get_Sval (Var));
                  VRT   : constant RType_Addr := Symtab.Lookup_Var (ST, VN);
                  TName : String (1 .. 256) := (others => ' ');
                  TLen  : Natural := 0;
               begin
                  if VRT /= Null_RType then
                     declare
                        TN : constant String :=
                          S (RT_Get_Name (VRT));
                     begin
                        TLen := TN'Length;
                        TName (1 .. TLen) := TN;
                     end;
                  end if;
                  Symtab.Push_With (ST, VN, TName (1 .. TLen));
                  TC_Node (Get_Child (N, 1), ST);
                  Symtab.Pop_With (ST, 1);
               end;
            end if;

         when ND_WRITELN | ND_WRITE | ND_READLN | ND_READ |
              ND_INC | ND_DEC | ND_PROC_CALL |
              ND_ASSIGN_FILE | ND_REWRITE | ND_RESET | ND_CLOSE_FILE =>
            for I in 0 .. Integer (Child_Count (N)) - 1 loop
               TC_Expr (Get_Child (N, int (I)), ST);
            end loop;

         when ND_NEW | ND_DISPOSE | ND_HALT | ND_EXIT =>
            if int (Child_Count (N)) > 0 then
               TC_Expr (Get_Child (N, 0), ST);
            end if;

         when ND_EMPTY | ND_USES =>
            null;

         when ND_TRY =>
            --  Walk all children (try body, handler list/finally body)
            for I in 0 .. Integer (Child_Count (N)) - 1 loop
               TC_Node (Get_Child (N, int (I)), ST);
            end loop;

         when ND_EXCEPT_HANDLER =>
            declare
               CC          : constant Integer := Integer (Child_Count (N));
               Is_Catchall : constant Boolean := Integer (Get_Flags (N)) = 1;
               Has_Var     : constant Boolean :=
                  (not Is_Catchall) and then CC >= 2 and then
                  Integer (Get_Kind (Get_Child (N, 0))) = ND_IDENT;
            begin
               if Has_Var then
                  --  Register the exception variable as TY_STRING in local scope
                  declare
                     Var_Name : constant String :=
                       S (Get_Sval (Get_Child (N, 0)));
                  begin
                     Symtab.Add_Var (ST, Var_Name, RT (TY_STRING));
                     TC_Node (Get_Child (N, 1), ST);
                  end;
               else
                  for I in 0 .. CC - 1 loop
                     TC_Node (Get_Child (N, int (I)), ST);
                  end loop;
               end if;
            end;

         when ND_RAISE =>
            if int (Child_Count (N)) > 0 then
               TC_Expr (Get_Child (N, 0), ST);
            end if;

         when ND_BREAK | ND_CONTINUE =>
            null;

         when others =>
            --  Anything else: try as expression
            TC_Expr (N, ST);
      end case;
   end TC_Node;

   -- ----------------------------------------------------------------
   -- Public entry point
   -- ----------------------------------------------------------------
   procedure Check (Root : System.Address; ST : in out Symtab.Table) is
   begin
      TC_Error_Count := 0;
      TC_Has_Uses    := False;
      if Root = System.Null_Address then return; end if;
      if Integer (Get_Kind (Root)) /= ND_PROGRAM
         and Integer (Get_Kind (Root)) /= ND_UNIT
      then return; end if;
      --  Detect a leading ND_USES node - enables tolerance of external symbols
      if int (Child_Count (Root)) > 0
         and then Integer (Get_Kind (Get_Child (Root, 0))) = ND_USES
      then
         TC_Has_Uses := True;
      end if;
      TC_Node (Root, ST);
   end Check;

   function Error_Count return Natural is
   begin
      return TC_Error_Count;
   end Error_Count;

end Type_Checker;
