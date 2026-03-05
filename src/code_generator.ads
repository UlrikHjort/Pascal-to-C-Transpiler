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

with System;
with Ada.Text_IO;
with Symtab;

package Code_Generator is

   --  Emit C to Out_File from the annotated AST rooted at Root.
   procedure Generate (Root     : System.Address;
                       ST       : in out Symtab.Table;
                       Out_File : in out Ada.Text_IO.File_Type);

   --  Unit mode: emit header (interface) to Hdr_File, implementation to Impl_File.
   procedure Generate_Unit (Root      : System.Address;
                             ST        : in out Symtab.Table;
                             Hdr_File  : in out Ada.Text_IO.File_Type;
                             Impl_File : in out Ada.Text_IO.File_Type;
                             Unit_Name : String);

end Code_Generator;
