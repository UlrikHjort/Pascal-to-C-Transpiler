-- ***************************************************************************
--              Pascal to C Transpiler - Pascal Transpiler
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

--  Orchestrates the full Pascal -> C translation in Ada:
--    1. Parse        (C: flex/bison, via glue.c)
--    2. Type-check   (Ada: Type_Checker)
--    3. Code-gen     (Ada: Code_Generator)

with C_Bindings;
with Symtab;
with Type_Checker;
with Code_Generator;
with AST_Binding;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Strings.Fixed;     use Ada.Strings.Fixed;
with Ada.Strings;
with Ada.Exceptions;
with System;

package body Pascal_Transpiler is

   function Transpile
     (Source_File : String;
      Output_File : String) return Status
   is
      C_In : chars_ptr := New_String (Source_File);
      Root : System.Address;
   begin
      --  Step 1: parse (C)
      Root := C_Bindings.Pascal_Parse (C_In);
      Free (C_In);

      --  Check for parse errors; glue.c already printed each one
      if Integer (C_Bindings.Pascal_Get_Parse_Errors) > 0 or else
         System."=" (Root, System.Null_Address)
      then
         return Parse_Error;
      end if;

      --  Steps 2 + 3: typechk + codegen (Ada)
      declare
         ST    : Symtab.Table;
         use type System.Address;
      begin
         Symtab.Create (ST);
         Type_Checker.Check (Root, ST);

         if Type_Checker.Error_Count > 0 then
            Symtab.Destroy (ST);
            C_Bindings.Pascal_Free_Ast (Root);
            return Semantic_Error;
         end if;

         if Integer (AST_Binding.Get_Kind (Root)) = AST_Binding.ND_UNIT then
            --  Unit mode: derive header filename from output filename
            declare
               Base      : String := Output_File;
               Dot_Pos   : Natural := Index (Base, ".", Ada.Strings.Backward);
               Unit_Name : constant String :=
                 Value (AST_Binding.Get_Sval (Root));
               Hdr_Name  : constant String :=
                 (if Dot_Pos > 0
                  then Base (Base'First .. Dot_Pos) & "h"
                  else Output_File & ".h");
               Hdr_File  : File_Type;
               Impl_File : File_Type;
            begin
               Create (Hdr_File,  Mode => Out_File, Name => Hdr_Name);
               Create (Impl_File, Mode => Out_File, Name => Output_File);
               Code_Generator.Generate_Unit
                 (Root, ST, Hdr_File, Impl_File, Unit_Name);
               Close (Hdr_File);
               Close (Impl_File);
            exception
               when others =>
                  if Is_Open (Hdr_File)  then Close (Hdr_File);  end if;
                  if Is_Open (Impl_File) then Close (Impl_File); end if;
                  Symtab.Destroy (ST);
                  C_Bindings.Pascal_Free_Ast (Root);
                  return File_Error;
            end;
         else
            declare
               CFile : File_Type;
            begin
               Create (CFile, Mode => Out_File, Name => Output_File);
               Code_Generator.Generate (Root, ST, CFile);
               Close (CFile);
            exception
               when E : others =>
                  if Is_Open (CFile) then Close (CFile); end if;
                  Symtab.Destroy (ST);
                  C_Bindings.Pascal_Free_Ast (Root);
                  Ada.Text_IO.Put_Line
                    (Ada.Text_IO.Standard_Error,
                     "Internal error: " &
                     Ada.Exceptions.Exception_Name (E) & ": " &
                     Ada.Exceptions.Exception_Message (E));
                  return File_Error;
            end;
         end if;

         Symtab.Destroy (ST);
      end;

      C_Bindings.Pascal_Free_Ast (Root);
      return Success;
   end Transpile;

end Pascal_Transpiler;
