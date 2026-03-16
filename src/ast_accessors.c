/***************************************************************************
--            Pascal to C Transpiler - AST Accessors
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

/* Thin C shim exposing the AST to Ada.
 *
 * Ada imports every function here via pragma Import(C,...).
 * The AST (Node/ResolvedType) is still allocated by the C parser;
 * Ada holds opaque System.Address handles and calls these to query/mutate.
 */
#define _POSIX_C_SOURCE 200809L
#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* Node field accessors                                                */
/* ------------------------------------------------------------------ */
int         ast_get_kind    (const Node *n)     { return n ? (int)n->kind : -1; }
int         ast_get_line    (const Node *n)     { return n ? n->line : 0; }
int         ast_get_flags   (const Node *n)     { return n ? n->flags : 0; }
void        ast_set_flags   (Node *n, int v)    { if (n) n->flags = v; }
int         ast_child_count (const Node *n)     { return n ? n->children.count : 0; }

Node *ast_get_child(const Node *n, int i) {
    if (!n || i < 0 || i >= n->children.count) return NULL;
    return n->children.items[i];
}

int         ast_get_ival    (const Node *n)     { return n ? n->u.ival : 0; }
double      ast_get_rval    (const Node *n)     { return n ? n->u.rval : 0.0; }
const char *ast_get_sval    (const Node *n)     { return n ? n->u.sval : NULL; }
int         ast_get_op      (const Node *n)     { return n ? n->u.op : 0; }
int         ast_get_arr_lo  (const Node *n)     { return n ? n->u.arr.lo : 0; }
int         ast_get_arr_hi  (const Node *n)     { return n ? n->u.arr.hi : 0; }

/* ------------------------------------------------------------------ */
/* rtype accessors on a Node                                           */
/* ------------------------------------------------------------------ */
int         ast_rtype_kind  (const Node *n) { return (n && n->rtype) ? (int)n->rtype->kind : 0; }
int         ast_rtype_arr_lo(const Node *n) { return (n && n->rtype) ? n->rtype->array_lo : 0; }
int         ast_rtype_arr_hi(const Node *n) { return (n && n->rtype) ? n->rtype->array_hi : 0; }
const char *ast_rtype_name  (const Node *n) { return (n && n->rtype) ? n->rtype->name : NULL; }
int         ast_has_rtype   (const Node *n) { return (n && n->rtype) ? 1 : 0; }

/* The elem pointer of a node's rtype (itself a ResolvedType*). */
void *ast_rtype_elem(const Node *n) {
    return (n && n->rtype) ? (void *)n->rtype->elem : NULL;
}

/* ------------------------------------------------------------------ */
/* rtype setter                                                        */
/* ------------------------------------------------------------------ */
void ast_set_rtype(Node *n, void *rt) {
    if (n) n->rtype = (ResolvedType *)rt;
}

/* ------------------------------------------------------------------ */
/* ResolvedType accessors (for rtype handles returned by ast_rtype_elem) */
/* ------------------------------------------------------------------ */
int         rtype_get_kind  (const void *rt) { return rt ? (int)((const ResolvedType *)rt)->kind : 0; }
const char *rtype_get_name  (const void *rt) { return rt ? ((const ResolvedType *)rt)->name : NULL; }
int         rtype_get_arr_lo(const void *rt) { return rt ? ((const ResolvedType *)rt)->array_lo : 0; }
int         rtype_get_arr_hi(const void *rt) { return rt ? ((const ResolvedType *)rt)->array_hi : 0; }
void       *rtype_get_elem  (const void *rt) { return rt ? (void *)((const ResolvedType *)rt)->elem : NULL; }

/* ------------------------------------------------------------------ */
/* ResolvedType factory (called from Ada typechk)                     */
/* ------------------------------------------------------------------ */
void *rtype_make(int kind) {
    return rtype_new((ResolvedKind)kind);
}

void *rtype_make_named(int kind, const char *name) {
    ResolvedType *rt = rtype_new((ResolvedKind)kind);
    if (name) rt->name = strdup(name);
    return rt;
}

void rtype_set_elem(void *rt_addr, void *elem_addr) {
    ResolvedType *rt = (ResolvedType *)rt_addr;
    if (rt) rt->elem = (ResolvedType *)elem_addr;
}

void rtype_set_array_bounds(void *rt_addr, int lo, int hi) {
    ResolvedType *rt = (ResolvedType *)rt_addr;
    if (rt) { rt->array_lo = lo; rt->array_hi = hi; }
}

/* ------------------------------------------------------------------ */
/* Formatting helper for real literals (%g style)                     */
/* ------------------------------------------------------------------ */
void format_real(double v, char *buf, int n) {
    snprintf(buf, (size_t)n, "%g", v);
}
