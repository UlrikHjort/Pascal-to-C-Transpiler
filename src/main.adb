-- ***************************************************************************
--              Pascal to C Transpiler - Main
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

--  Entry point for pascal2c.
--
--  Usage:
--    pascal2c <source.pas> [output.c]
--
--  If no output file is given, the input basename with .c extension is used.

with Ada.Command_Line;  use Ada.Command_Line;
with Ada.Text_IO;       use Ada.Text_IO;
with Pascal_Transpiler;

procedure Main is

   function Default_Output (Source : String) return String is
   begin
      if Source'Length > 4
        and then Source (Source'Last - 3 .. Source'Last) = ".pas"
      then
         return Source (Source'First .. Source'Last - 4) & ".c";
      else
         return Source & ".c";
      end if;
   end Default_Output;

   Result : Pascal_Transpiler.Status;

begin
   if Argument_Count < 1 then
      Put_Line ("pascal2c – Pascal to C transpiler");
      Put_Line ("Usage: pascal2c <source.pas> [output.c]");
      Set_Exit_Status (Failure);
      return;
   end if;

   declare
      Source : constant String := Argument (1);
      Output : constant String :=
        (if Argument_Count >= 2 then Argument (2)
         else Default_Output (Source));
   begin
      Put_Line ("pascal2c: " & Source & "  ->  " & Output);
      Result := Pascal_Transpiler.Transpile (Source, Output);

      case Result is
         when Pascal_Transpiler.Success =>
            Put_Line ("OK");
         when Pascal_Transpiler.File_Error =>
            Put_Line ("Error: could not open/create file.");
            Set_Exit_Status (Failure);
         when Pascal_Transpiler.Parse_Error =>
            Put_Line ("Error: parse error in Pascal source.");
            Set_Exit_Status (Failure);
         when Pascal_Transpiler.Semantic_Error =>
            Put_Line ("Error: semantic errors in Pascal source.");
            Set_Exit_Status (Failure);
      end case;
   end;
end Main;
