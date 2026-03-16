-- ***************************************************************************
--              Pascal to C Transpiler - Symbol Table
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

with System;
with AST_Binding; use AST_Binding;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash_Case_Insensitive;
with Ada.Strings.Equal_Case_Insensitive;

package Symtab is

   --  Make "=" for System.Address (= RType_Addr / Node_Addr) visible
   --  so container instantiations below can find the operator.
   use type System.Address;

   Max_With : constant := 16;

   -- ----------------------------------------------------------------
   -- Field entry for record types
   -- ----------------------------------------------------------------
   type Field_Entry is record
      Name : Unbounded_String;
      RT   : RType_Addr;
   end record;

   package Field_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Field_Entry);
   subtype Field_Vector is Field_Vectors.Vector;

   --  Make "=" for Field_Vector visible for the Type_Maps instantiation.
   use type Field_Vector;

   -- ----------------------------------------------------------------
   -- Type definition stored in the type table
   -- ----------------------------------------------------------------
   type Type_Def is record
      Name   : Unbounded_String;
      RT     : RType_Addr;
      Fields : Field_Vector;
   end record;

   -- ----------------------------------------------------------------
   -- Parameter entry for subroutines
   -- ----------------------------------------------------------------
   type Param_Entry is record
      Name   : Unbounded_String;
      RT     : RType_Addr;
      Is_Ref : Boolean := False;
   end record;

   package Param_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Param_Entry);

   --  Make "=" for Param_Vectors.Vector visible.
   use type Param_Vectors.Vector;

   -- ----------------------------------------------------------------
   -- Subroutine definition
   -- ----------------------------------------------------------------
   type Subr_Def is record
      Name    : Unbounded_String;
      Is_Proc : Boolean := True;
      Ret_RT  : RType_Addr := Null_RType;
      Params  : Param_Vectors.Vector;
   end record;

   package Subr_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Subr_Def);

   -- ----------------------------------------------------------------
   -- Hash maps: string key -> value (case-insensitive)
   -- ----------------------------------------------------------------
   package Var_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => RType_Addr,
      Hash            => Ada.Strings.Hash_Case_Insensitive,
      Equivalent_Keys => Ada.Strings.Equal_Case_Insensitive);

   package Type_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Type_Def,
      Hash            => Ada.Strings.Hash_Case_Insensitive,
      Equivalent_Keys => Ada.Strings.Equal_Case_Insensitive);

   -- ----------------------------------------------------------------
   -- A single scope level
   -- ----------------------------------------------------------------
   type Scope_Type is record
      Vars  : Var_Maps.Map;
      Types : Type_Maps.Map;
   end record;

   package Scope_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Scope_Type);

   -- ----------------------------------------------------------------
   -- With-frame
   -- ----------------------------------------------------------------
   type With_Frame is record
      Var_Name  : Unbounded_String;
      Type_Name : Unbounded_String;
   end record;

   type With_Stack_Array is array (0 .. Max_With - 1) of With_Frame;

   -- ----------------------------------------------------------------
   -- The symbol table
   -- ----------------------------------------------------------------
   type Table is record
      Scopes     : Scope_Vectors.Vector;
      Subrs      : Subr_Vectors.Vector;
      With_Stack : With_Stack_Array;
      With_Depth : Natural := 0;
   end record;

   -- ----------------------------------------------------------------
   -- Lifecycle
   -- ----------------------------------------------------------------
   procedure Create  (ST : out Table);
   procedure Destroy (ST : in out Table);

   -- ----------------------------------------------------------------
   -- Scope management
   -- ----------------------------------------------------------------
   procedure Push_Scope (ST : in out Table);
   procedure Pop_Scope  (ST : in out Table);

   -- ----------------------------------------------------------------
   -- Add symbols
   -- ----------------------------------------------------------------
   procedure Add_Var (ST   : in out Table;
                      Name : String;
                      RT   : RType_Addr);

   procedure Add_Type (ST     : in out Table;
                       Name   : String;
                       RT     : RType_Addr;
                       Fields : Field_Vector);

   procedure Add_Subr (ST      : in out Table;
                       Name    : String;
                       Is_Proc : Boolean;
                       Ret_RT  : RType_Addr;
                       Params  : Param_Vectors.Vector);

   -- ----------------------------------------------------------------
   -- Lookup
   -- ----------------------------------------------------------------
   function Lookup_Var  (ST : Table; Name : String) return RType_Addr;

   function Lookup_Type (ST   : Table;
                         Name : String) return access constant Type_Def;

   function Lookup_Subr_Index (ST : Table; Name : String) return Integer;

   function Lookup_Field (ST         : Table;
                          Type_Name  : String;
                          Field_Name : String) return RType_Addr;

   -- ----------------------------------------------------------------
   -- With-stack
   -- ----------------------------------------------------------------
   procedure Push_With (ST        : in out Table;
                        Var_Name  : String;
                        Type_Name : String);

   procedure Pop_With  (ST    : in out Table;
                        Count : Natural);

   function Resolve_With_Field (ST      : Table;
                                Name    : String;
                                Var_Out : out Unbounded_String) return Boolean;

end Symtab;
