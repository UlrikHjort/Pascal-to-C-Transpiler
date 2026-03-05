-- ***************************************************************************
--              Pascal to C Transpiler - C Bindings
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
   
--  Ada thin binding to the C functions exported by glue.c.
--
--  After the Ada migration, glue.c only exposes two functions:
--    pascal_parse()               – lex+parse, return AST root (opaque System.Address)
--    pascal_get_parse_errors()    – number of parse errors from last parse
--    pascal_free_ast()            – free the AST

with System;
with Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;

package C_Bindings is

   --  Parse the Pascal source file; return AST root as an opaque address,
   --  or System.Null_Address on parse error / file-not-found.
   function Pascal_Parse (Input_File : chars_ptr) return System.Address;
   pragma Import (C, Pascal_Parse, "pascal_parse");

   --  Number of parse errors encountered in the last pascal_parse() call.
   function Pascal_Get_Parse_Errors return Interfaces.C.int;
   pragma Import (C, Pascal_Get_Parse_Errors, "pascal_get_parse_errors");

   --  Release the memory held by the AST.
   procedure Pascal_Free_Ast (Root : System.Address);
   pragma Import (C, Pascal_Free_Ast, "pascal_free_ast");

end C_Bindings;
