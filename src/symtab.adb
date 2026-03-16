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


with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Containers;          use Ada.Containers;

package body Symtab is

   procedure Create (ST : out Table) is
      Global : Scope_Type;
   begin
      ST.Scopes.Clear;
      ST.Subrs.Clear;
      ST.With_Depth := 0;
      ST.Scopes.Append (Global);
   end Create;

   procedure Destroy (ST : in out Table) is
   begin
      ST.Scopes.Clear;
      ST.Subrs.Clear;
      ST.With_Depth := 0;
   end Destroy;

   procedure Push_Scope (ST : in out Table) is
      New_Scope : Scope_Type;
   begin
      ST.Scopes.Append (New_Scope);
   end Push_Scope;

   procedure Pop_Scope (ST : in out Table) is
   begin
      if ST.Scopes.Length > Ada.Containers.Count_Type (1) then
         ST.Scopes.Delete_Last;
      end if;
   end Pop_Scope;

   procedure Add_Var (ST   : in out Table;
                      Name : String;
                      RT   : RType_Addr) is
   begin
      if ST.Scopes.Is_Empty then return; end if;
      ST.Scopes.Reference (ST.Scopes.Last_Index).Vars.Include
        (To_Lower (Name), RT);
   end Add_Var;

   procedure Add_Type (ST     : in out Table;
                       Name   : String;
                       RT     : RType_Addr;
                       Fields : Field_Vector) is
      TD : Type_Def;
   begin
      if ST.Scopes.Is_Empty then return; end if;
      TD.Name   := To_Unbounded_String (Name);
      TD.RT     := RT;
      TD.Fields := Fields;
      ST.Scopes.Reference (ST.Scopes.Last_Index).Types.Include
        (To_Lower (Name), TD);
   end Add_Type;

   procedure Add_Subr (ST      : in out Table;
                       Name    : String;
                       Is_Proc : Boolean;
                       Ret_RT  : RType_Addr;
                       Params  : Param_Vectors.Vector) is
      Lo  : constant String  := To_Lower (Name);
      Idx : constant Integer := Lookup_Subr_Index (ST, Lo);
   begin
      if Idx >= 0 then
         declare
            SD : Subr_Def renames ST.Subrs.Reference (Idx);
         begin
            SD.Is_Proc := Is_Proc;
            SD.Ret_RT  := Ret_RT;
            SD.Params  := Params;
         end;
      else
         declare
            SD : Subr_Def;
         begin
            SD.Name    := To_Unbounded_String (Name);
            SD.Is_Proc := Is_Proc;
            SD.Ret_RT  := Ret_RT;
            SD.Params  := Params;
            ST.Subrs.Append (SD);
         end;
      end if;
   end Add_Subr;

   function Lookup_Var (ST : Table; Name : String) return RType_Addr is
      Lo : constant String := To_Lower (Name);
   begin
      for Idx in reverse ST.Scopes.First_Index .. ST.Scopes.Last_Index loop
         declare
            Cur : constant Var_Maps.Cursor :=
              ST.Scopes.Constant_Reference (Idx).Vars.Find (Lo);
         begin
            if Var_Maps.Has_Element (Cur) then
               return Var_Maps.Element (Cur);
            end if;
         end;
      end loop;
      return Null_RType;
   end Lookup_Var;

   function Lookup_Type (ST   : Table;
                         Name : String) return access constant Type_Def is
      Lo : constant String := To_Lower (Name);
   begin
      for Idx in reverse ST.Scopes.First_Index .. ST.Scopes.Last_Index loop
         declare
            Cur : constant Type_Maps.Cursor :=
              ST.Scopes.Constant_Reference (Idx).Types.Find (Lo);
         begin
            if Type_Maps.Has_Element (Cur) then
               return ST.Scopes.Constant_Reference (Idx).Types
                        .Constant_Reference (Cur).Element;
            end if;
         end;
      end loop;
      return null;
   end Lookup_Type;

   function Lookup_Subr_Index (ST : Table; Name : String) return Integer is
      Lo : constant String := To_Lower (Name);
   begin
      for I in ST.Subrs.First_Index .. ST.Subrs.Last_Index loop
         if To_Lower (To_String
              (ST.Subrs.Constant_Reference (I).Name)) = Lo
         then
            return I;
         end if;
      end loop;
      return -1;
   end Lookup_Subr_Index;

   function Lookup_Field (ST         : Table;
                          Type_Name  : String;
                          Field_Name : String) return RType_Addr is
      Lo_F  : constant String := To_Lower (Field_Name);
      TD    : constant access constant Type_Def := Lookup_Type (ST, Type_Name);
   begin
      if TD = null then return Null_RType; end if;
      for I in TD.Fields.First_Index .. TD.Fields.Last_Index loop
         declare
            F : Field_Entry renames TD.Fields.Constant_Reference (I);
         begin
            if To_Lower (To_String (F.Name)) = Lo_F then
               return F.RT;
            end if;
         end;
      end loop;
      return Null_RType;
   end Lookup_Field;

   procedure Push_With (ST        : in out Table;
                        Var_Name  : String;
                        Type_Name : String) is
   begin
      if ST.With_Depth < Max_With then
         ST.With_Stack (ST.With_Depth).Var_Name  :=
           To_Unbounded_String (Var_Name);
         ST.With_Stack (ST.With_Depth).Type_Name :=
           To_Unbounded_String (Type_Name);
         ST.With_Depth := ST.With_Depth + 1;
      end if;
   end Push_With;

   procedure Pop_With (ST    : in out Table;
                       Count : Natural) is
   begin
      if ST.With_Depth >= Count then
         ST.With_Depth := ST.With_Depth - Count;
      else
         ST.With_Depth := 0;
      end if;
   end Pop_With;

   function Resolve_With_Field (ST      : Table;
                                Name    : String;
                                Var_Out : out Unbounded_String) return Boolean is
      Lo : constant String := To_Lower (Name);
   begin
      for D in reverse 0 .. ST.With_Depth - 1 loop
         declare
            Frame : With_Frame renames ST.With_Stack (D);
            TN    : constant String := To_String (Frame.Type_Name);
            TD    : constant access constant Type_Def := Lookup_Type (ST, TN);
         begin
            if TD /= null then
               for F in TD.Fields.First_Index .. TD.Fields.Last_Index loop
                  declare
                     FE : Field_Entry renames TD.Fields.Constant_Reference (F);
                  begin
                     if To_Lower (To_String (FE.Name)) = Lo then
                        Var_Out := Frame.Var_Name;
                        return True;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
      Var_Out := Null_Unbounded_String;
      return False;
   end Resolve_With_Field;

end Symtab;
