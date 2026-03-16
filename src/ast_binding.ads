-- ***************************************************************************
--              Pascal to C Transpiler - AST Binding
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
    
--  Ada thin binding to the C AST accessor functions in ast_accessors.c.

with System;
with Interfaces.C;
with Interfaces.C.Strings;

package AST_Binding is

   subtype Node_Addr  is System.Address;   --  C Node*
   subtype RType_Addr is System.Address;   --  C ResolvedType*

   Null_Node  : constant Node_Addr  := System.Null_Address;
   Null_RType : constant RType_Addr := System.Null_Address;

   -- ----------------------------------------------------------------
   -- NodeKind constants  (must match the enum in ast.h)
   -- ----------------------------------------------------------------
   ND_PROGRAM    : constant := 0;
   ND_CONST_DECL : constant := 1;
   ND_TYPE_DECL  : constant := 2;
   ND_VAR_DECL   : constant := 3;
   ND_FUNC_DECL  : constant := 4;
   ND_PROC_DECL  : constant := 5;
   ND_PARAM      : constant := 6;

   ND_TYPE_INT    : constant := 7;
   ND_TYPE_REAL   : constant := 8;
   ND_TYPE_BOOL   : constant := 9;
   ND_TYPE_CHAR   : constant := 10;
   ND_TYPE_STRING : constant := 11;
   ND_TYPE_ARRAY  : constant := 12;
   ND_TYPE_RECORD : constant := 13;
   ND_TYPE_PTR    : constant := 14;
   ND_TYPE_ENUM   : constant := 15;
   ND_TYPE_NAMED  : constant := 16;

   ND_COMPOUND  : constant := 17;
   ND_ASSIGN    : constant := 18;
   ND_IF        : constant := 19;
   ND_WHILE     : constant := 20;
   ND_FOR       : constant := 21;
   ND_REPEAT    : constant := 22;
   ND_CASE      : constant := 23;
   ND_CASE_ELEM : constant := 24;
   ND_WITH      : constant := 25;
   ND_WRITELN   : constant := 26;
   ND_WRITE     : constant := 27;
   ND_READLN    : constant := 28;
   ND_READ      : constant := 29;
   ND_INC       : constant := 30;
   ND_DEC       : constant := 31;
   ND_NEW       : constant := 32;
   ND_DISPOSE   : constant := 33;
   ND_HALT      : constant := 34;
   ND_EXIT      : constant := 35;
   ND_PROC_CALL : constant := 36;
   ND_EMPTY     : constant := 37;

   ND_INT_LIT   : constant := 38;
   ND_REAL_LIT  : constant := 39;
   ND_STR_LIT   : constant := 40;
   ND_BOOL_LIT  : constant := 41;
   ND_NIL       : constant := 42;
   ND_IDENT     : constant := 43;
   ND_FUNC_CALL : constant := 44;
   ND_INDEX     : constant := 45;
   ND_FIELD     : constant := 46;
   ND_DEREF     : constant := 47;
   ND_ADDR_OF   : constant := 48;
   ND_BINOP     : constant := 49;
   ND_UNOP      : constant := 50;

   ND_TYPE_SET  : constant := 51;   --  set of T
   ND_SET_LIT   : constant := 52;   --  [ elem, ... ]
   ND_SET_RANGE : constant := 53;   --  lo..hi in set literal
   ND_TYPE_SUBRANGE      : constant := 54;  --  integer subrange type lo..hi
   ND_TYPE_ENUM_SUBRANGE : constant := 55;  --  enum subrange type Ident..Ident
   ND_CASE_RANGE         : constant := 56;  --  lo..hi range in case arm
   ND_WRITE_FMT          : constant := 57;  --  expr:width or expr:width:prec
   ND_UNIT               : constant := 58;  --  unit declaration
   ND_INTERFACE_SEC      : constant := 59;  --  interface section
   ND_IMPL_SEC           : constant := 60;  --  implementation section
   ND_USES               : constant := 61;  --  uses clause
   ND_TRY                : constant := 62;  --  try/except/finally
   ND_EXCEPT_HANDLER     : constant := 63;  --  except handler
   ND_RAISE              : constant := 64;  --  raise
   ND_BREAK              : constant := 65;  --  break (exit loop)
   ND_CONTINUE           : constant := 66;  --  continue (next iteration)
   ND_FOR_IN             : constant := 67;  --  for i in lo..hi do
   ND_ASSIGN_FILE        : constant := 68;  --  assign(f, 'name')
   ND_REWRITE            : constant := 69;  --  rewrite(f)
   ND_RESET              : constant := 70;  --  reset(f)
   ND_CLOSE_FILE         : constant := 71;  --  close(f)
   ND_TYPE_FILE          : constant := 72;  --  'text' type -> pascal_file_t
   ND_GOTO               : constant := 73;  --  goto lbl
   ND_LABELED_STMT       : constant := 74;  --  lbl: stmt
   ND_VARIANT_PART       : constant := 75;  --  record variant part
   ND_VARIANT_ITEM       : constant := 76;  --  one variant arm
   ND_TYPE_FUNCPTR       : constant := 77;  --  procedural type
   ND_TYPED_CONST        : constant := 78;  --  typed constant: const N: T = val
   ND_CONST_INIT         : constant := 79;  --  structured init list (array/record)

   -- ----------------------------------------------------------------
   -- ResolvedKind constants  (must match the enum in ast.h)
   -- ----------------------------------------------------------------
   TY_UNKNOWN : constant := 0;
   TY_INT     : constant := 1;
   TY_REAL    : constant := 2;
   TY_BOOL    : constant := 3;
   TY_CHAR    : constant := 4;
   TY_STRING  : constant := 5;
   TY_ARRAY   : constant := 6;
   TY_RECORD  : constant := 7;
   TY_PTR     : constant := 8;
   TY_ENUM    : constant := 9;
   TY_VOID    : constant := 10;
   TY_SET     : constant := 11;   --  set type (uint64_t bitmask)
   TY_STRING_FIXED : constant := 12;  --  string[N] -> char[N+1]
   TY_FILE    : constant := 13;   --  Pascal 'text' file type
   TY_FUNCPTR : constant := 14;   --  procedural type (function/proc pointer)

   -- ----------------------------------------------------------------
   -- Node accessors
   -- ----------------------------------------------------------------
   function Get_Kind      (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Get_Kind, "ast_get_kind");

   function Get_Line      (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Get_Line, "ast_get_line");

   function Get_Flags     (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Get_Flags, "ast_get_flags");

   procedure Set_Flags    (N : Node_Addr; V : Interfaces.C.int);
   pragma Import (C, Set_Flags, "ast_set_flags");

   function Child_Count   (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Child_Count, "ast_child_count");

   function Get_Child     (N : Node_Addr; I : Interfaces.C.int) return Node_Addr;
   pragma Import (C, Get_Child, "ast_get_child");

   function Get_Ival      (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Get_Ival, "ast_get_ival");

   function Get_Rval      (N : Node_Addr) return Interfaces.C.double;
   pragma Import (C, Get_Rval, "ast_get_rval");

   function Get_Sval      (N : Node_Addr) return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, Get_Sval, "ast_get_sval");

   function Get_Op        (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Get_Op, "ast_get_op");

   function Get_Arr_Lo    (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Get_Arr_Lo, "ast_get_arr_lo");

   function Get_Arr_Hi    (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Get_Arr_Hi, "ast_get_arr_hi");

   -- ----------------------------------------------------------------
   -- rtype accessors (via the node's rtype pointer)
   -- ----------------------------------------------------------------
   function RType_Kind    (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, RType_Kind, "ast_rtype_kind");

   function RType_Arr_Lo  (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, RType_Arr_Lo, "ast_rtype_arr_lo");

   function RType_Arr_Hi  (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, RType_Arr_Hi, "ast_rtype_arr_hi");

   function RType_Name    (N : Node_Addr) return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, RType_Name, "ast_rtype_name");

   --  Returns the elem ResolvedType* as an opaque address.
   function RType_Elem_Of_Node (N : Node_Addr) return RType_Addr;
   pragma Import (C, RType_Elem_Of_Node, "ast_rtype_elem");

   function Has_RType     (N : Node_Addr) return Interfaces.C.int;
   pragma Import (C, Has_RType, "ast_has_rtype");

   procedure Set_RType (N : Node_Addr; RT : RType_Addr);
   pragma Import (C, Set_RType, "ast_set_rtype");

   -- ----------------------------------------------------------------
   -- ResolvedType accessors (for an RType_Addr directly)
   -- ----------------------------------------------------------------
   function RT_Get_Kind   (RT : RType_Addr) return Interfaces.C.int;
   pragma Import (C, RT_Get_Kind, "rtype_get_kind");

   function RT_Get_Name   (RT : RType_Addr) return Interfaces.C.Strings.chars_ptr;
   pragma Import (C, RT_Get_Name, "rtype_get_name");

   function RT_Get_Arr_Lo (RT : RType_Addr) return Interfaces.C.int;
   pragma Import (C, RT_Get_Arr_Lo, "rtype_get_arr_lo");

   function RT_Get_Arr_Hi (RT : RType_Addr) return Interfaces.C.int;
   pragma Import (C, RT_Get_Arr_Hi, "rtype_get_arr_hi");

   function RT_Get_Elem   (RT : RType_Addr) return RType_Addr;
   pragma Import (C, RT_Get_Elem, "rtype_get_elem");

   -- ----------------------------------------------------------------
   -- ResolvedType factory / mutators
   -- ----------------------------------------------------------------
   function RT_Make (Kind : Interfaces.C.int) return RType_Addr;
   pragma Import (C, RT_Make, "rtype_make");

   function RT_Make_Named
     (Kind : Interfaces.C.int;
      Name : Interfaces.C.Strings.chars_ptr) return RType_Addr;
   pragma Import (C, RT_Make_Named, "rtype_make_named");

   procedure RT_Set_Elem (RT : RType_Addr; Elem : RType_Addr);
   pragma Import (C, RT_Set_Elem, "rtype_set_elem");

   procedure RT_Set_Array_Bounds (RT : RType_Addr;
                                  Lo : Interfaces.C.int;
                                  Hi : Interfaces.C.int);
   pragma Import (C, RT_Set_Array_Bounds, "rtype_set_array_bounds");

   -- ----------------------------------------------------------------
   -- Formatting helper for real literals  (%g style)
   -- ----------------------------------------------------------------
   type Char64 is array (0 .. 63) of Interfaces.C.char;
   pragma Convention (C, Char64);

   procedure Format_Real (V   : Interfaces.C.double;
                          Buf : out Char64;
                          N   : Interfaces.C.int);
   pragma Import (C, Format_Real, "format_real");

end AST_Binding;
