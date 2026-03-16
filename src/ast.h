/***************************************************************************
--          Pascal to C Transpiler - AST node definitions
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
-- ***************************************************************************/

#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* Node kind                                                           */
/* ------------------------------------------------------------------ */
typedef enum {
    /* Declarations */
    ND_PROGRAM, ND_CONST_DECL, ND_TYPE_DECL, ND_VAR_DECL,
    ND_FUNC_DECL, ND_PROC_DECL, ND_PARAM,
    /* Type nodes */
    ND_TYPE_INT, ND_TYPE_REAL, ND_TYPE_BOOL, ND_TYPE_CHAR, ND_TYPE_STRING,
    ND_TYPE_ARRAY, ND_TYPE_RECORD, ND_TYPE_PTR, ND_TYPE_ENUM, ND_TYPE_NAMED,
    /* Statements */
    ND_COMPOUND, ND_ASSIGN, ND_IF, ND_WHILE, ND_FOR, ND_REPEAT,
    ND_CASE, ND_CASE_ELEM, ND_WITH,
    ND_WRITELN, ND_WRITE, ND_READLN, ND_READ,
    ND_INC, ND_DEC, ND_NEW, ND_DISPOSE, ND_HALT, ND_EXIT,
    ND_PROC_CALL, ND_EMPTY,
    /* Expressions */
    ND_INT_LIT, ND_REAL_LIT, ND_STR_LIT, ND_BOOL_LIT, ND_NIL,
    ND_IDENT, ND_FUNC_CALL,
    ND_INDEX, ND_FIELD, ND_DEREF, ND_ADDR_OF,
    ND_BINOP, ND_UNOP,
    /* Set types */
    ND_TYPE_SET,      /* set of T */
    ND_SET_LIT,       /* [ elem, ... ] - set literal */
    ND_SET_RANGE,     /* lo..hi inside a set literal */
    /* Subrange type */
    ND_TYPE_SUBRANGE, /* lo..hi as a type (e.g. 1..7) */
    /* Enum subrange as type (e.g. Mon..Fri) - children are ND_IDENT nodes */
    ND_TYPE_ENUM_SUBRANGE,
    /* Case range label */
    ND_CASE_RANGE,    /* lo..hi inside a case arm */
    /* Write format specifier */
    ND_WRITE_FMT,     /* expr:width or expr:width:prec */
    /* Unit / separate compilation */
    ND_UNIT,          /* unit Foo; interface ... implementation ... end. */
    ND_INTERFACE_SEC, /* interface section */
    ND_IMPL_SEC,      /* implementation section */
    ND_USES,          /* uses Foo, Bar; */
    /* Exception handling */
    ND_TRY,           /* try stmt except handler [finally stmt] end */
    ND_EXCEPT_HANDLER,/* on E: ExcClass do stmt | else stmt */
    ND_RAISE,         /* raise [expr] */
    /* Loop control */
    ND_BREAK,         /* break  (exit innermost loop) */
    ND_CONTINUE,      /* continue (next iteration) */
    ND_FOR_IN,        /* for i in lo..hi do  (range-for) */
    ND_ASSIGN_FILE,   /* assign(f, 'name')  - store filename in file var */
    ND_REWRITE,       /* rewrite(f)  - open for writing */
    ND_RESET,         /* reset(f)    - open for reading */
    ND_CLOSE_FILE,    /* close(f)    - close file */
    ND_TYPE_FILE,     /* 'text' type -> pascal_file_t */
    /* goto / label */
    ND_GOTO,          /* goto lbl  - sval = label name */
    ND_LABELED_STMT,  /* lbl: stmt - sval = label name, child 0 = stmt */
    /* Variant record */
    ND_VARIANT_PART,  /* case tag of variants - child 0 = tag decl (or nil), rest = ND_VARIANT_ITEM */
    ND_VARIANT_ITEM,  /* one variant arm - children: case_labels..., then field_list nodes */
    /* Procedural type */
    ND_TYPE_FUNCPTR,  /* function(params):rettype as a type - sval = name (for typedef) */
    ND_TYPED_CONST,   /* typed constant: const N: type = value - sval=name, ch0=type, ch1=init */
    ND_CONST_INIT,    /* structured init list for typed constants: children = values */
} NodeKind;

/* ------------------------------------------------------------------ */
/* Resolved type (filled in by typechk)                               */
/* ------------------------------------------------------------------ */
typedef enum {
    TY_UNKNOWN, TY_INT, TY_REAL, TY_BOOL, TY_CHAR, TY_STRING,
    TY_ARRAY, TY_RECORD, TY_PTR, TY_ENUM, TY_VOID,
    TY_SET,           /* set type (uint64_t bitmask) */
    TY_STRING_FIXED,  /* fixed-length string: string[N] -> char[N+1] */
    TY_FILE,          /* Pascal 'text' file type -> pascal_file_t */
    TY_FUNCPTR        /* procedural type (function/procedure pointer) */
} ResolvedKind;

typedef struct ResolvedType {
    ResolvedKind         kind;
    char                *name;       /* for named/record/enum */
    int                  array_lo;   /* for arrays */
    int                  array_hi;
    struct ResolvedType *elem;       /* for arrays and pointers */
} ResolvedType;

/* ------------------------------------------------------------------ */
/* Variable-length child list                                          */
/* ------------------------------------------------------------------ */
typedef struct NodeList {
    struct Node **items;
    int           count;
    int           cap;
} NodeList;

/* ------------------------------------------------------------------ */
/* AST Node                                                            */
/* ------------------------------------------------------------------ */
typedef struct Node {
    NodeKind      kind;
    int           line;
    int           flags;    /* ND_PARAM: is_ref; ND_FOR: is_downto */
    ResolvedType *rtype;    /* NULL until typechk fills it */

    NodeList      children;

    union {
        int    ival;        /* ND_INT_LIT, ND_BOOL_LIT */
        double rval;        /* ND_REAL_LIT */
        char  *sval;        /* ND_STR_LIT, ND_IDENT, ND_FUNC_CALL, ND_FIELD,
                               ND_TYPE_NAMED, ND_CONST_DECL, ND_VAR_DECL,
                               ND_TYPE_DECL, ND_FUNC_DECL, ND_PROC_DECL,
                               ND_PARAM, ND_PROGRAM */
        int    op;          /* ND_BINOP, ND_UNOP - ASCII or enum */
        struct { int lo, hi; } arr;  /* ND_TYPE_ARRAY bounds */
    } u;
} Node;

/* ------------------------------------------------------------------ */
/* Functions                                                           */
/* ------------------------------------------------------------------ */
Node *node_new(NodeKind kind, int line);
void  node_add_child(Node *parent, Node *child);
void  node_free(Node *n);
Node *node_clone(Node *n);      /* deep clone (for types shared across vars) */

void  nodelist_init(NodeList *nl);
void  nodelist_append(NodeList *nl, Node *n);
void  nodelist_free_items(NodeList *nl); /* free only the array, not the nodes */

/* Resolved-type helpers */
ResolvedType *rtype_new(ResolvedKind kind);
ResolvedType *rtype_free(ResolvedType *rt);

#endif /* AST_H */
