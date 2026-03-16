/***************************************************************************
--              Pascal to C Transpiler - C Bridge
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

/*
 * C bridge between the Ada driver and the flex/bison parser.
 *
 * Provides two functions callable from Ada:
 *   pascal_parse()     - lex+parse, return AST root (opaque void*)
 *   pascal_free_ast()  - free the AST
 *
 * Typechecking and code generation are handled entirely in Ada.
 */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include "ast.h"

extern FILE *yyin;
extern int   yyparse(void);
extern void  yyrestart(FILE *f);
extern Node *pascal_ast;   /* set by yyparse() via parser.y */
extern int   g_parse_errors; /* incremented by yyerror */

/* Parse the input file; return the AST root (opaque to Ada) or NULL. */
void *pascal_parse(const char *input_file) {
    FILE *fin = fopen(input_file, "r");
    if (!fin) return NULL;
    yyin = fin;
    yyrestart(fin);
    pascal_ast    = NULL;
    g_parse_errors = 0;   /* reset before each parse */
    int rc = yyparse();
    fclose(fin);
    if (rc != 0 || g_parse_errors > 0) {
        node_free(pascal_ast);
        pascal_ast = NULL;
    }
    return (void *)pascal_ast;
}

/* Return the number of parse errors from the last pascal_parse() call. */
int pascal_get_parse_errors(void) {
    return g_parse_errors;
}

/* Free the AST (call after codegen is done). */
void pascal_free_ast(void *root) {
    node_free((Node *)root);
}
