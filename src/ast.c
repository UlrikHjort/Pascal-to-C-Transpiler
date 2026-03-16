/***************************************************************************
--         Pascal to C Transpiler - AST node implementation
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

#include "ast.h"
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* NodeList                                                            */
/* ------------------------------------------------------------------ */

void nodelist_init(NodeList *nl) {
    nl->items = NULL;
    nl->count = 0;
    nl->cap   = 0;
}

void nodelist_append(NodeList *nl, Node *n) {
    if (nl->count >= nl->cap) {
        int newcap = nl->cap ? nl->cap * 2 : 4;
        nl->items  = realloc(nl->items, newcap * sizeof(Node *));
        nl->cap    = newcap;
    }
    nl->items[nl->count++] = n;
}

void nodelist_free_items(NodeList *nl) {
    free(nl->items);
    nl->items = NULL;
    nl->count = 0;
    nl->cap   = 0;
}

/* ------------------------------------------------------------------ */
/* ResolvedType                                                        */
/* ------------------------------------------------------------------ */

ResolvedType *rtype_new(ResolvedKind kind) {
    ResolvedType *rt = calloc(1, sizeof(ResolvedType));
    rt->kind = kind;
    return rt;
}

ResolvedType *rtype_free(ResolvedType *rt) {
    if (!rt) return NULL;
    free(rt->name);
    rtype_free(rt->elem);
    free(rt);
    return NULL;
}

/* ------------------------------------------------------------------ */
/* Node                                                                */
/* ------------------------------------------------------------------ */

Node *node_new(NodeKind kind, int line) {
    Node *n = calloc(1, sizeof(Node));
    n->kind = kind;
    n->line = line;
    nodelist_init(&n->children);
    return n;
}

void node_add_child(Node *parent, Node *child) {
    nodelist_append(&parent->children, child);
}

/* Returns the sval pointer for kinds that use it, or NULL */
static char **node_sval_ptr(Node *n) {
    switch (n->kind) {
    case ND_STR_LIT: case ND_IDENT:   case ND_FUNC_CALL:
    case ND_FIELD:   case ND_TYPE_NAMED:
    case ND_CONST_DECL: case ND_VAR_DECL: case ND_TYPE_DECL:
    case ND_FUNC_DECL:  case ND_PROC_DECL: case ND_PARAM:
    case ND_PROGRAM:
        return &n->u.sval;
    default:
        return NULL;
    }
}

void node_free(Node *n)
{
    if (!n) return;
    /* free sval if applicable */
    char **sp = node_sval_ptr(n);
    if (sp) free(*sp);
    /* free children */
    for (int i = 0; i < n->children.count; i++)
        node_free(n->children.items[i]);
    nodelist_free_items(&n->children);
    /* rtype is owned externally (symtab), don't free here */
    free(n);
}

Node *node_clone(Node *n) {
    if (!n) return NULL;
    Node *c = node_new(n->kind, n->line);
    c->rtype = n->rtype;  /* shallow */
    c->u     = n->u;      /* shallow copy union */
    /* deep-copy sval if needed */
    char **sp = node_sval_ptr(c);
    if (sp && *sp) *sp = strdup(*sp);
    /* clone children */
    for (int i = 0; i < n->children.count; i++)
        node_add_child(c, node_clone(n->children.items[i]));
    return c;
}
