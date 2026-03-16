/***************************************************************************
--    Pascal to C Transpiler - Bison parser for extended Pascal subset
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
%{
/*
 * AST-build strategy: grammar actions build Node* trees.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <strings.h>
#include "ast.h"

extern int  yylex(void);
extern int  yylineno;
void yyerror(const char *msg);

int  g_parse_errors = 0;   /* incremented by yyerror; reset by caller */
Node *pascal_ast = NULL;

/* ================================================================ */
/*  Helpers                                                          */
/* ================================================================ */

static char *aprintf(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int len = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    char *buf = malloc(len + 1);
    va_start(ap, fmt);
    vsnprintf(buf, len + 1, fmt, ap);
    va_end(ap);
    return buf;
}
#pragma GCC diagnostic ignored "-Wunused-function"

static char *type_pascal_name_node(Node *t)
{
    if (!t) return NULL;
    if (t->kind == ND_TYPE_NAMED && t->u.sval) return strdup(t->u.sval);
    return NULL;
}

/* ================================================================ */
/*  Parse-time constant table  (for const-named array bounds etc.)  */
/* ================================================================ */

#define MAX_CONSTS 128
typedef struct { char *name; int ival; } ConstEntry;
static ConstEntry g_consts[MAX_CONSTS];
static int        g_nconst = 0;

static void register_const_int(const char *name, int val)
{
    if (g_nconst >= MAX_CONSTS) return;
    g_consts[g_nconst].name = strdup(name);
    g_consts[g_nconst].ival = val;
    g_nconst++;
}

/* Returns val of named constant, or defval if not found */
static int lookup_const_int(const char *name, int defval)
{
    for (int i = 0; i < g_nconst; i++)
        if (g_consts[i].name && strcasecmp(g_consts[i].name, name) == 0)
            return g_consts[i].ival;
    return defval;
}

/* ================================================================ */
/*  Parse-time symbol tables (for with-stack + zero-arg call detect)*/
/* ================================================================ */

#define MAX_FIELDS  64
#define MAX_TYPES   64

typedef struct { char *name; } FieldEntry2;
typedef struct {
    char        *pascal_name;
    FieldEntry2  fields[MAX_FIELDS];
    int          nfields;
} TypeEntry2;

static TypeEntry2 g_types[MAX_TYPES];
static int        g_ntype = 0;

static TypeEntry2 *find_type2(const char *name)
{
    for (int i = 0; i < g_ntype; i++)
        if (g_types[i].pascal_name && strcasecmp(g_types[i].pascal_name, name) == 0)
            return &g_types[i];
    return NULL;
}

#define MAX_SUBRS2 64
typedef struct { char *name; int is_proc; } SubrEntry2;
static SubrEntry2 g_subrs2[MAX_SUBRS2];
static int        g_nsubr2 = 0;

static SubrEntry2 *find_subr2(const char *name)
{
    for (int i = 0; i < g_nsubr2; i++)
        if (g_subrs2[i].name && strcasecmp(g_subrs2[i].name, name) == 0)
            return &g_subrs2[i];
    return NULL;
}

static void register_subr2(const char *name, int is_proc)
{
    if (g_nsubr2 >= MAX_SUBRS2) return;
    g_subrs2[g_nsubr2].name    = strdup(name);
    g_subrs2[g_nsubr2].is_proc = is_proc;
    g_nsubr2++;
}

#define MAX_VARS2 256
typedef struct { char *name; char *type_name; } VarEntry2;
static VarEntry2 g_vars2[MAX_VARS2];
static int       g_nvar2 = 0;

static void register_var2(const char *name, const char *type_name)
{
    if (g_nvar2 >= MAX_VARS2) return;
    g_vars2[g_nvar2].name      = strdup(name);
    g_vars2[g_nvar2].type_name = type_name ? strdup(type_name) : NULL;
    g_nvar2++;
}

static VarEntry2 *find_var2(const char *name)
{
    for (int i = 0; i < g_nvar2; i++)
        if (g_vars2[i].name && strcasecmp(g_vars2[i].name, name) == 0)
            return &g_vars2[i];
    return NULL;
}

#define MAX_WITH 8
typedef struct { char *varname; TypeEntry2 *type_entry; } WithFrame;
static WithFrame with_stack[MAX_WITH];
static int       with_depth = 0;

static void push_with(const char *varname)
{
    if (with_depth >= MAX_WITH) return;
    VarEntry2  *ve = find_var2(varname);
    TypeEntry2 *te = ve && ve->type_name ? find_type2(ve->type_name) : NULL;
    with_stack[with_depth].varname    = strdup(varname);
    with_stack[with_depth].type_entry = te;
    with_depth++;
}

static const char *resolve_with_field(const char *name, const char **out_varname)
{
    for (int d = with_depth - 1; d >= 0; d--) {
        TypeEntry2 *te = with_stack[d].type_entry;
        if (!te) continue;
        for (int f = 0; f < te->nfields; f++)
            if (te->fields[f].name && strcasecmp(te->fields[f].name, name) == 0) {
                if (out_varname) *out_varname = with_stack[d].varname;
                return te->fields[f].name;
            }
    }
    return NULL;
}

/* ================================================================ */
/*  Accumulators                                                     */
/* ================================================================ */

static char *var_ids[256];
static int   var_id_count = 0;

static void push_var_id(const char *id) { var_ids[var_id_count++] = strdup(id); }
static void clear_var_ids(void)
{
    for (int i = 0; i < var_id_count; i++) free(var_ids[i]);
    var_id_count = 0;
}

static char *cur_type_name  = NULL;
static char *cur_field_names[MAX_FIELDS];
static int   cur_nfields    = 0;

static void clear_cur_fields(void)
{
    for (int i = 0; i < cur_nfields; i++) free(cur_field_names[i]);
    cur_nfields = 0;
}

static char *cur_func_name = NULL;
static int   cur_is_proc   = 0;

/* Function-name stack for nested function support */
#define MAX_FUNC_DEPTH 16
static char *func_name_stack[MAX_FUNC_DEPTH];
static int   func_is_proc_stack[MAX_FUNC_DEPTH];
static int   func_name_depth = 0;

static void push_func(const char *name, int is_proc)
{
    if (func_name_depth < MAX_FUNC_DEPTH) {
        func_name_stack[func_name_depth] = strdup(name);
        func_is_proc_stack[func_name_depth] = is_proc;
        func_name_depth++;
    }
    free(cur_func_name);
    cur_func_name = strdup(name);
    cur_is_proc   = is_proc;
}

static void pop_func(void)
{
    if (func_name_depth > 0) {
        free(func_name_stack[func_name_depth - 1]);
        func_name_depth--;
    }
    free(cur_func_name);
    if (func_name_depth > 0) {
        cur_func_name = strdup(func_name_stack[func_name_depth - 1]);
        cur_is_proc   = func_is_proc_stack[func_name_depth - 1];
    } else {
        cur_func_name = NULL;
        cur_is_proc   = 0;
    }
}

%}

%code requires {
#include "ast.h"
}

%define parse.error verbose

%union {
    int        ival;
    double     rval;
    char      *sval;
    Node      *node;
    NodeList  *nlist;
}

%token PROGRAM VAR TBEGIN TEND
%token TINTEGER TREAL TBOOLEAN TCHAR TSTRING
%token TIF TTHEN TELSE TWHILE TDO TFOR TTO TDOWNTO TREPEAT TUNTIL
%token TCASE TWITH TRECORD TTYPE TCONST TARRAY TOF
%token TSET TIN
%token TNIL TNEW TDISPOSE TINC TDEC THALT TEXIT TFORWARD
%token TUNIT TUSES TINTERFACE TIMPLEMENTATION
%token TTRY TEXCEPT TFINALLY TRAISE TON
%token TBREAK TCONTINUE
%token TGOTO TLABEL
%token TWRITELN TWRITE TREADLN TREAD
%token TDIV TMOD TAND TOR TNOT TXOR TSHL TSHR
%token TFUNCTION TPROCEDURE
%token TASSIGN TLE TGE TNE TDOTDOT
%token TTEXT TASSIGN_F TREWRITE TRESET TCLOSE_F

%token <ival> TINT_LIT TBOOL_LIT
%token <rval> TREAL_LIT
%token <sval> TSTR_LIT TIDENT

%type <node>  program
%type <node>  func_decl proc_decl func_forward proc_forward func_proto proc_proto
%type <node>  type_def type_spec
%type <node>  statement compound_stmt if_stmt while_stmt for_stmt
%type <node>  repeat_stmt case_stmt case_element
%type <node>  with_stmt
%type <node>  writeln_stmt write_stmt readln_stmt read_stmt
%type <node>  inc_dec_stmt new_dispose_stmt halt_stmt exit_stmt file_io_stmt
%type <node>  expr simple_expr term factor designator
%type <node>  set_elem set_elem_list
%type <node>  opt_else opt_case_else case_label enum_id_list_node
%type <node>  opt_uses try_stmt except_handler_list except_handler
%type <node>  typed_const_value
%type <nlist> typed_const_items

%type <nlist> decl_sections iface_decl_sections
%type <nlist> const_decl_list type_decl_list
%type <nlist> var_section var_decl_list var_decl
%type <nlist> field_list field_decl
%type <nlist> variant_list
%type <node>  variant_part variant_item
%type <nlist> opt_formal_params param_list param_group
%type <nlist> stmt_list case_list case_label_list
%type <nlist> write_arg_list read_arg_list arg_list
%type <nlist> ident_list
%type <nlist> dim_range_list comma_expr_tail
%type <ival>  bound_int const_int_atom const_int_expr_op
%type <node>  write_arg

%type <sval>  with_var_list opt_call

%nonassoc TTHEN
%nonassoc TELSE
%left  TOR TXOR
%left  TAND
%right TNOT
%nonassoc '<' '>' TLE TGE '=' TNE TIN
%left  '+' '-'
%left  '*' '/' TDIV TMOD TSHL TSHR
%right UMINUS

%%

program
    : PROGRAM TIDENT ';'
      opt_uses
      decl_sections
      TBEGIN stmt_list TEND '.'
        {
            Node *prog = node_new(ND_PROGRAM, yylineno);
            prog->u.sval = $2;
            if ($4) node_add_child(prog, $4);
            for (int i = 0; i < $5->count; i++)
                node_add_child(prog, $5->items[i]);
            nodelist_free_items($5); free($5);
            Node *body = node_new(ND_COMPOUND, yylineno);
            for (int i = 0; i < $7->count; i++)
                node_add_child(body, $7->items[i]);
            nodelist_free_items($7); free($7);
            node_add_child(prog, body);
            pascal_ast = prog;
            $$ = prog;
        }
    | TUNIT TIDENT ';'
      TINTERFACE
      opt_uses
      iface_decl_sections
      TIMPLEMENTATION
      decl_sections
      TEND '.'
        {
            Node *unit = node_new(ND_UNIT, yylineno);
            unit->u.sval = $2;
            /* interface section */
            Node *iface = node_new(ND_INTERFACE_SEC, yylineno);
            if ($5) node_add_child(iface, $5);
            for (int i = 0; i < $6->count; i++)
                node_add_child(iface, $6->items[i]);
            nodelist_free_items($6); free($6);
            node_add_child(unit, iface);
            /* implementation section */
            Node *impl = node_new(ND_IMPL_SEC, yylineno);
            for (int i = 0; i < $8->count; i++)
                node_add_child(impl, $8->items[i]);
            nodelist_free_items($8); free($8);
            node_add_child(unit, impl);
            pascal_ast = unit;
            $$ = unit;
        }
    ;

opt_uses
    : TUSES ident_list ';'
        {
            Node *u = node_new(ND_USES, yylineno);
            for (int i = 0; i < $2->count; i++)
                node_add_child(u, $2->items[i]);
            nodelist_free_items($2); free($2);
            $$ = u;
        }
    | /* empty */ { $$ = NULL; }
    ;

ident_list
    : TIDENT
        {
            $$ = malloc(sizeof(NodeList)); nodelist_init($$);
            Node *n = node_new(ND_IDENT, yylineno); n->u.sval = $1;
            nodelist_append($$, n);
        }
    | ident_list ',' TIDENT
        {
            $$ = $1;
            Node *n = node_new(ND_IDENT, yylineno); n->u.sval = $3;
            nodelist_append($$, n);
        }
    ;

decl_sections
    : decl_sections TCONST const_decl_list
        {
            $$ = $1;
            for (int i = 0; i < $3->count; i++) nodelist_append($$, $3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | decl_sections TTYPE type_decl_list
        {
            $$ = $1;
            for (int i = 0; i < $3->count; i++) nodelist_append($$, $3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | decl_sections VAR var_decl_list
        {
            $$ = $1;
            for (int i = 0; i < $3->count; i++) nodelist_append($$, $3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | decl_sections func_decl  { $$ = $1; nodelist_append($$, $2); }
    | decl_sections proc_decl  { $$ = $1; nodelist_append($$, $2); }
    | decl_sections func_forward { $$ = $1; nodelist_append($$, $2); }
    | decl_sections proc_forward { $$ = $1; nodelist_append($$, $2); }
    | decl_sections TFORWARD ';' { $$ = $1; }
    | decl_sections TLABEL label_decl_list ';' { $$ = $1; }  /* label decls - just consume */
    | /* empty */
        { $$ = malloc(sizeof(NodeList)); nodelist_init($$); }
    ;

/* Interface section declarations: like decl_sections but functions/procedures
   are just prototypes (no body), without needing the 'forward' keyword. */
iface_decl_sections
    : iface_decl_sections TCONST const_decl_list
        {
            $$ = $1;
            for (int i = 0; i < $3->count; i++) nodelist_append($$, $3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | iface_decl_sections TTYPE type_decl_list
        {
            $$ = $1;
            for (int i = 0; i < $3->count; i++) nodelist_append($$, $3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | iface_decl_sections VAR var_decl_list
        {
            $$ = $1;
            for (int i = 0; i < $3->count; i++) nodelist_append($$, $3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | iface_decl_sections func_proto  { $$ = $1; nodelist_append($$, $2); }
    | iface_decl_sections proc_proto  { $$ = $1; nodelist_append($$, $2); }
    | /* empty */
        { $$ = malloc(sizeof(NodeList)); nodelist_init($$); }
    ;

/* ------------------------------------------------------------------ */
/*  Constant-expression arithmetic (evaluated at parse time)          */
/*  const_int_atom  = a single integer value (literal or named const) */
/*  const_int_expr_op = REQUIRES at least one binary operator         */
/* ------------------------------------------------------------------ */
const_int_atom
    : TINT_LIT          { $$ = $1; }
    | TIDENT            { $$ = lookup_const_int($1, 0); free($1); }
    ;

const_int_expr_op
    : const_int_atom '+' const_int_atom  { $$ = $1 + $3; }
    | const_int_atom '-' const_int_atom  { $$ = $1 - $3; }
    | const_int_atom '*' const_int_atom  { $$ = $1 * $3; }
    | const_int_atom TDIV const_int_atom { $$ = ($3 != 0) ? ($1 / $3) : 0; }
    | const_int_atom TMOD const_int_atom { $$ = ($3 != 0) ? ($1 % $3) : 0; }
    | const_int_expr_op '+' const_int_atom  { $$ = $1 + $3; }
    | const_int_expr_op '-' const_int_atom  { $$ = $1 - $3; }
    | const_int_expr_op '*' const_int_atom  { $$ = $1 * $3; }
    | const_int_expr_op TDIV const_int_atom { $$ = ($3 != 0) ? ($1 / $3) : 0; }
    | const_int_expr_op TMOD const_int_atom { $$ = ($3 != 0) ? ($1 % $3) : 0; }
    ;

const_decl_list
    : const_decl_list TIDENT '=' TINT_LIT ';'
        {
            register_const_int($2, $4);
            Node *n = node_new(ND_CONST_DECL, yylineno); n->u.sval = $2;
            Node *v = node_new(ND_INT_LIT, yylineno);    v->u.ival = $4;
            node_add_child(n, v); $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list TIDENT '=' '-' TINT_LIT ';'
        {
            register_const_int($2, -$5);
            Node *n = node_new(ND_CONST_DECL, yylineno); n->u.sval = $2;
            Node *v = node_new(ND_INT_LIT, yylineno);    v->u.ival = -$5;
            node_add_child(n, v); $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list TIDENT '=' TREAL_LIT ';'
        {
            Node *n = node_new(ND_CONST_DECL, yylineno); n->u.sval = $2;
            Node *v = node_new(ND_REAL_LIT, yylineno);   v->u.rval = $4;
            node_add_child(n, v); $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list TIDENT '=' '-' TREAL_LIT ';'
        {
            Node *n = node_new(ND_CONST_DECL, yylineno); n->u.sval = $2;
            Node *v = node_new(ND_REAL_LIT, yylineno);   v->u.rval = -$5;
            node_add_child(n, v); $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list TIDENT '=' TBOOL_LIT ';'
        {
            Node *n = node_new(ND_CONST_DECL, yylineno); n->u.sval = $2;
            Node *v = node_new(ND_BOOL_LIT, yylineno);   v->u.ival = $4;
            node_add_child(n, v); $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list TIDENT '=' TSTR_LIT ';'
        {
            Node *n = node_new(ND_CONST_DECL, yylineno); n->u.sval = $2;
            Node *v = node_new(ND_STR_LIT, yylineno);    v->u.sval = $4;
            node_add_child(n, v); $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list TIDENT '=' TIDENT ';'
        {
            Node *n = node_new(ND_CONST_DECL, yylineno); n->u.sval = $2;
            Node *v = node_new(ND_IDENT, yylineno);      v->u.sval = $4;
            node_add_child(n, v); $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list TIDENT '=' const_int_expr_op ';'
        {
            register_const_int($2, $4);
            Node *n = node_new(ND_CONST_DECL, yylineno); n->u.sval = $2;
            Node *v = node_new(ND_INT_LIT, yylineno);    v->u.ival = $4;
            node_add_child(n, v); $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list TIDENT ':' type_spec '=' typed_const_value ';'
        {
            Node *n = node_new(ND_TYPED_CONST, yylineno); n->u.sval = $2;
            node_add_child(n, $4); /* type_spec */
            node_add_child(n, $6); /* init value */
            $$ = $1; nodelist_append($$, n);
        }
    | const_decl_list error ';'
        { $$ = $1; yyerrok; }   /* skip bad const declaration */
    | /* empty */
        { $$ = malloc(sizeof(NodeList)); nodelist_init($$); }
    ;

typed_const_value
    : expr          { $$ = $1; }
    | '(' typed_const_items ')'
        {
            Node *n = node_new(ND_CONST_INIT, yylineno);
            for (int i = 0; i < $2->count; i++)
                node_add_child(n, $2->items[i]);
            free($2);
            $$ = n;
        }
    ;

typed_const_items
    : typed_const_items ',' expr
        { nodelist_append($1, $3); $$ = $1; }
    | expr
        { $$ = malloc(sizeof(NodeList)); nodelist_init($$); nodelist_append($$, $1); }
    ;

type_decl_list
    : type_decl_list TIDENT '='
        { free(cur_type_name); cur_type_name = strdup($2); free($2); }
      type_def
        {
            Node *n = node_new(ND_TYPE_DECL, yylineno);
            n->u.sval = strdup(cur_type_name);
            node_add_child(n, $5);
            $$ = $1; nodelist_append($$, n);
        }
    | /* empty */
        { $$ = malloc(sizeof(NodeList)); nodelist_init($$); }
    ;

type_def
    : type_spec ';'  { $$ = $1; }
    | TRECORD
        { clear_cur_fields(); }
      field_list opt_semi TEND ';'
        {
            Node *n = node_new(ND_TYPE_RECORD, yylineno);
            for (int i = 0; i < $3->count; i++) node_add_child(n, $3->items[i]);
            nodelist_free_items($3); free($3);
            if (g_ntype < MAX_TYPES) {
                TypeEntry2 *te = &g_types[g_ntype++];
                te->pascal_name = strdup(cur_type_name);
                for (int i = 0; i < cur_nfields && i < MAX_FIELDS; i++) {
                    te->fields[i].name = cur_field_names[i];
                    cur_field_names[i] = NULL;
                }
                te->nfields = cur_nfields;
                cur_nfields = 0;
            } else {
                clear_cur_fields();
            }
            $$ = n;
        }
    | '(' enum_id_list_node ')' ';'  { $$ = $2; }
    ;

enum_id_list_node
    : enum_id_list_node ',' TIDENT
        {
            Node *id = node_new(ND_IDENT, yylineno); id->u.sval = $3;
            node_add_child($1, id); $$ = $1;
        }
    | TIDENT
        {
            Node *n  = node_new(ND_TYPE_ENUM, yylineno);
            Node *id = node_new(ND_IDENT, yylineno); id->u.sval = $1;
            node_add_child(n, id); $$ = n;
        }
    ;

field_list
    : field_list ';' field_decl
        {
            $$ = $1;
            for (int i = 0; i < $3->count; i++) nodelist_append($$, $3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | field_list ';' variant_part
        {
            $$ = $1;
            nodelist_append($$, $3);
        }
    | field_decl  { $$ = $1; }
    | variant_part
        {
            $$ = malloc(sizeof(NodeList)); nodelist_init($$);
            nodelist_append($$, $1);
        }
    ;

variant_part
    : TCASE TIDENT ':' type_spec TOF variant_list
        {
            Node *n = node_new(ND_VARIANT_PART, yylineno);
            /* tag field as first child */
            Node *tag = node_new(ND_VAR_DECL, yylineno);
            tag->u.sval = $2;
            node_add_child(tag, $4);
            node_add_child(n, tag);
            for (int i = 0; i < $6->count; i++) node_add_child(n, $6->items[i]);
            nodelist_free_items($6); free($6);
            $$ = n;
        }
    | TCASE type_spec TOF variant_list
        {
            /* untagged variant */
            Node *vp = node_new(ND_VARIANT_PART, yylineno);
            node_add_child(vp, node_new(ND_EMPTY, yylineno));
            for (int i = 0; i < $4->count; i++) node_add_child(vp, $4->items[i]);
            nodelist_free_items($4); free($4);
            $$ = vp;
        }
    ;

variant_list
    : variant_item
        { NodeList *nl=malloc(sizeof(NodeList)); nodelist_init(nl); nodelist_append(nl,$1); $$=nl; }
    | variant_list ';' variant_item
        { nodelist_append($1,$3); $$=$1; }
    | variant_list ';'
        { $$=$1; }
    ;

variant_item
    : case_label_list ':' '(' field_list opt_semi ')'
        {
            Node *n = node_new(ND_VARIANT_ITEM, yylineno);
            /* case labels as first children, then field nodes */
            for (int i = 0; i < $1->count; i++) node_add_child(n, $1->items[i]);
            nodelist_free_items($1); free($1);
            /* mark boundary: add a sentinel with op=-1 */
            Node *sep = node_new(ND_EMPTY, yylineno); sep->flags = -1;
            node_add_child(n, sep);
            for (int i = 0; i < $4->count; i++) node_add_child(n, $4->items[i]);
            nodelist_free_items($4); free($4);
            $$ = n;
        }
    | case_label_list ':' '(' ')'
        {
            Node *n = node_new(ND_VARIANT_ITEM, yylineno);
            for (int i = 0; i < $1->count; i++) node_add_child(n, $1->items[i]);
            nodelist_free_items($1); free($1);
            Node *sep = node_new(ND_EMPTY, yylineno); sep->flags = -1;
            node_add_child(n, sep);
            $$ = n;
        }
    ;

field_decl
    : field_id_list ':' type_spec
        {
            NodeList *nl = malloc(sizeof(NodeList)); nodelist_init(nl);
            for (int i = 0; i < var_id_count; i++) {
                Node *fd = node_new(ND_VAR_DECL, yylineno);
                fd->u.sval = strdup(var_ids[i]);
                node_add_child(fd, (i == 0) ? $3 : node_clone($3));
                nodelist_append(nl, fd);
                if (cur_nfields < MAX_FIELDS)
                    cur_field_names[cur_nfields++] = strdup(var_ids[i]);
            }
            clear_var_ids();
            $$ = nl;
        }
    | /* empty */
        { $$ = malloc(sizeof(NodeList)); nodelist_init($$); }
    ;

field_id_list
    : TIDENT                   { push_var_id($1); free($1); }
    | field_id_list ',' TIDENT { push_var_id($3); free($3); }
    ;

var_section
    : /* empty */
        { $$ = malloc(sizeof(NodeList)); nodelist_init($$); }
    | var_section VAR var_decl_list
        {
            $$ = $1;
            for (int i = 0; i < $3->count; i++) nodelist_append($$, $3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | var_section func_decl  { $$ = $1; nodelist_append($$, $2); }
    | var_section proc_decl  { $$ = $1; nodelist_append($$, $2); }
    ;

var_decl_list
    : var_decl_list var_decl
        {
            $$ = $1;
            for (int i = 0; i < $2->count; i++) nodelist_append($$, $2->items[i]);
            nodelist_free_items($2); free($2);
        }
    | var_decl_list error ';'
        { $$ = $1; yyerrok; }   /* skip bad var declaration */
    | var_decl  { $$ = $1; }
    ;

var_decl
    : var_id_list ':' type_spec ';'
        {
            NodeList *nl = malloc(sizeof(NodeList)); nodelist_init(nl);
            char *tn = type_pascal_name_node($3);
            for (int i = 0; i < var_id_count; i++) {
                Node *n = node_new(ND_VAR_DECL, yylineno);
                n->u.sval = strdup(var_ids[i]);
                node_add_child(n, (i == 0) ? $3 : node_clone($3));
                nodelist_append(nl, n);
                register_var2(var_ids[i], tn);
            }
            free(tn); clear_var_ids();
            $$ = nl;
        }
    ;

var_id_list
    : TIDENT                 { push_var_id($1); free($1); }
    | var_id_list ',' TIDENT { push_var_id($3); free($3); }
    ;


/* bound_int: integer bound in array/subrange/string types - allows named consts
   and simple arithmetic (IDENT +/- LIT).  Bison's default shift preference
   resolves the harmless shift/reduce conflict on '+'/'-' lookahead. */
bound_int
    : TINT_LIT         { $$ = $1; }
    | TIDENT           { $$ = lookup_const_int($1, 0); free($1); }
    | '-' TINT_LIT     { $$ = -$2; }
    | '-' TIDENT       { $$ = -lookup_const_int($2, 0); free($2); }
    | TIDENT '+' TINT_LIT { $$ = lookup_const_int($1, 0) + $3; free($1); }
    | TIDENT '-' TINT_LIT { $$ = lookup_const_int($1, 0) - $3; free($1); }
    | TIDENT '*' TINT_LIT { $$ = lookup_const_int($1, 0) * $3; free($1); }
    | TINT_LIT '+' TIDENT { $$ = $1 + lookup_const_int($3, 0); free($3); }
    | TINT_LIT '-' TIDENT { $$ = $1 - lookup_const_int($3, 0); free($3); }
    ;

/* One or more dimension ranges for multi-dim arrays */
dim_range_list
    : bound_int TDOTDOT bound_int
        {
            NodeList *nl = malloc(sizeof(NodeList));
            nodelist_init(nl);
            Node *r = node_new(ND_TYPE_SUBRANGE, yylineno);
            r->u.arr.lo = $1; r->u.arr.hi = $3;
            nodelist_append(nl, r);
            $$ = nl;
        }
    | dim_range_list ',' bound_int TDOTDOT bound_int
        {
            Node *r = node_new(ND_TYPE_SUBRANGE, yylineno);
            r->u.arr.lo = $3; r->u.arr.hi = $5;
            nodelist_append($1, r);
            $$ = $1;
        }
    ;

/* Tail of a comma-separated expression list (second element onward) */
comma_expr_tail
    : expr
        {
            NodeList *nl = malloc(sizeof(NodeList));
            nodelist_init(nl);
            nodelist_append(nl, $1);
            $$ = nl;
        }
    | comma_expr_tail ',' expr
        {
            nodelist_append($1, $3);
            $$ = $1;
        }
    ;

type_spec
    : TINTEGER { $$ = node_new(ND_TYPE_INT,    yylineno); }
    | TREAL    { $$ = node_new(ND_TYPE_REAL,   yylineno); }
    | TBOOLEAN { $$ = node_new(ND_TYPE_BOOL,   yylineno); }
    | TCHAR    { $$ = node_new(ND_TYPE_CHAR,   yylineno); }
    | TSTRING  { $$ = node_new(ND_TYPE_STRING, yylineno); }
    | TTEXT    { $$ = node_new(ND_TYPE_FILE, yylineno); }  /* file type */
    | TSTRING '[' bound_int ']'
        {
            Node *n = node_new(ND_TYPE_STRING, yylineno);
            n->u.ival = $3;  /* fixed length N; C type becomes char[N+1] */
            $$ = n;
        }
    | TARRAY '[' dim_range_list ']' TOF type_spec
        {
            /* Build nested ND_TYPE_ARRAY from innermost out.
               dim_range_list items are ND_TYPE_SUBRANGE nodes. */
            Node *elem = $6;
            for (int i = $3->count - 1; i >= 0; i--) {
                Node *dim = $3->items[i];
                Node *arr = node_new(ND_TYPE_ARRAY, yylineno);
                arr->u.arr.lo = (int)dim->u.arr.lo;
                arr->u.arr.hi = (int)dim->u.arr.hi;
                node_add_child(arr, elem);
                elem = arr;
            }
            nodelist_free_items($3); free($3);
            $$ = elem;
        }
    | TSET TOF type_spec
        {
            Node *n = node_new(ND_TYPE_SET, yylineno);
            node_add_child(n, $3); $$ = n;
        }
    | TINT_LIT TDOTDOT TINT_LIT
        {
            Node *n = node_new(ND_TYPE_SUBRANGE, yylineno);
            n->u.arr.lo = $1; n->u.arr.hi = $3; $$ = n;
        }
    | '^' TIDENT
        {
            Node *n = node_new(ND_TYPE_PTR, yylineno);
            Node *b = node_new(ND_TYPE_NAMED, yylineno); b->u.sval = $2;
            node_add_child(n, b); $$ = n;
        }
    | '^' TINTEGER
        { Node *n=node_new(ND_TYPE_PTR,yylineno); node_add_child(n,node_new(ND_TYPE_INT,yylineno));    $$=n; }
    | '^' TREAL
        { Node *n=node_new(ND_TYPE_PTR,yylineno); node_add_child(n,node_new(ND_TYPE_REAL,yylineno));   $$=n; }
    | '^' TCHAR
        { Node *n=node_new(ND_TYPE_PTR,yylineno); node_add_child(n,node_new(ND_TYPE_CHAR,yylineno));   $$=n; }
    | '^' TBOOLEAN
        { Node *n=node_new(ND_TYPE_PTR,yylineno); node_add_child(n,node_new(ND_TYPE_BOOL,yylineno));   $$=n; }
    | TIDENT
        { Node *n=node_new(ND_TYPE_NAMED,yylineno); n->u.sval=$1; $$=n; }
    | TIDENT TDOTDOT TIDENT
        {
            /* enum subrange: e.g. Mon..Fri */
            Node *n = node_new(ND_TYPE_ENUM_SUBRANGE, yylineno);
            Node *lo = node_new(ND_IDENT, yylineno); lo->u.sval = $1;
            Node *hi = node_new(ND_IDENT, yylineno); hi->u.sval = $3;
            node_add_child(n, lo);
            node_add_child(n, hi);
            $$=n;
        }
    | TFUNCTION opt_formal_params ':' type_spec
        {
            /* procedural type: function(params):rettype */
            Node *n = node_new(ND_TYPE_FUNCPTR, yylineno);
            n->flags = 0; /* 0 = function */
            node_add_child(n, $4);  /* return type */
            if ($2) { for(int i=0;i<$2->count;i++) node_add_child(n,$2->items[i]);
                      nodelist_free_items($2); free($2); }
            $$ = n;
        }
    | TPROCEDURE opt_formal_params
        {
            /* procedural type: procedure(params) */
            Node *n = node_new(ND_TYPE_FUNCPTR, yylineno);
            n->flags = 1; /* 1 = procedure */
            node_add_child(n, node_new(ND_TYPE_NAMED, yylineno));  /* void placeholder */
            if ($2) { for(int i=0;i<$2->count;i++) node_add_child(n,$2->items[i]);
                      nodelist_free_items($2); free($2); }
            $$ = n;
        }
    ;

func_decl
    : TFUNCTION TIDENT opt_formal_params ':' type_spec ';'
        {
            push_func($2, 0); register_subr2($2, 0);
        }
      var_section TBEGIN stmt_list TEND ';'
        {
            Node *n = node_new(ND_FUNC_DECL, yylineno); n->u.sval = $2;
            node_add_child(n, $5);
            if ($3) { for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]); nodelist_free_items($3); free($3); }
            if ($8) { for(int i=0;i<$8->count;i++) node_add_child(n,$8->items[i]); nodelist_free_items($8); free($8); }
            Node *body = node_new(ND_COMPOUND, yylineno);
            for(int i=0;i<$10->count;i++) node_add_child(body,$10->items[i]);
            nodelist_free_items($10); free($10);
            node_add_child(n, body);
            pop_func();
            $$ = n;
        }
    ;

proc_decl
    : TPROCEDURE TIDENT opt_formal_params ';'
        {
            push_func($2, 1); register_subr2($2, 1);
        }
      var_section TBEGIN stmt_list TEND ';'
        {
            Node *n = node_new(ND_PROC_DECL, yylineno); n->u.sval = $2;
            if ($3) { for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]); nodelist_free_items($3); free($3); }
            if ($6) { for(int i=0;i<$6->count;i++) node_add_child(n,$6->items[i]); nodelist_free_items($6); free($6); }
            Node *body = node_new(ND_COMPOUND, yylineno);
            for(int i=0;i<$8->count;i++) node_add_child(body,$8->items[i]);
            nodelist_free_items($8); free($8);
            node_add_child(n, body);
            pop_func();
            $$ = n;
        }
    ;

/* forward-declared function: emits a C prototype only */
func_forward
    : TFUNCTION TIDENT opt_formal_params ':' type_spec ';' TFORWARD ';'
        {
            register_subr2($2, 0);
            Node *n = node_new(ND_FUNC_DECL, yylineno); n->u.sval = $2;
            n->flags = 1;  /* FLAG_FORWARD: prototype only */
            node_add_child(n, $5);
            if ($3) { for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]); nodelist_free_items($3); free($3); }
            $$ = n;
        }
    ;

/* forward-declared procedure: emits a C prototype only */
proc_forward
    : TPROCEDURE TIDENT opt_formal_params ';' TFORWARD ';'
        {
            register_subr2($2, 1);
            Node *n = node_new(ND_PROC_DECL, yylineno); n->u.sval = $2;
            n->flags = 1;  /* FLAG_FORWARD: prototype only */
            if ($3) { for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]); nodelist_free_items($3); free($3); }
            $$ = n;
        }
    ;

/* unit interface prototypes (no 'forward' keyword needed) */
func_proto
    : TFUNCTION TIDENT opt_formal_params ':' type_spec ';'
        {
            register_subr2($2, 0);
            Node *n = node_new(ND_FUNC_DECL, yylineno); n->u.sval = $2;
            n->flags = 1;  /* prototype only */
            node_add_child(n, $5);
            if ($3) { for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]); nodelist_free_items($3); free($3); }
            $$ = n;
        }
    ;

proc_proto
    : TPROCEDURE TIDENT opt_formal_params ';'
        {
            register_subr2($2, 1);
            Node *n = node_new(ND_PROC_DECL, yylineno); n->u.sval = $2;
            n->flags = 1;  /* prototype only */
            if ($3) { for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]); nodelist_free_items($3); free($3); }
            $$ = n;
        }
    ;

opt_formal_params
    : '(' param_list ')'  { $$ = $2; }
    | /* empty */         { $$ = NULL; }
    ;

param_list
    : param_list ';' param_group
        {
            $$ = $1;
            for(int i=0;i<$3->count;i++) nodelist_append($$,$3->items[i]);
            nodelist_free_items($3); free($3);
        }
    | param_group  { $$ = $1; }
    | /* empty */  { $$ = malloc(sizeof(NodeList)); nodelist_init($$); }
    ;

param_group
    : param_id_list ':' type_spec
        {
            NodeList *nl = malloc(sizeof(NodeList)); nodelist_init(nl);
            for(int i=0;i<var_id_count;i++) {
                Node *p = node_new(ND_PARAM,yylineno); p->u.sval=strdup(var_ids[i]); p->flags=0;
                node_add_child(p,(i==0)?$3:node_clone($3)); nodelist_append(nl,p);
            }
            clear_var_ids(); $$=nl;
        }
    | VAR param_id_list ':' type_spec
        {
            NodeList *nl = malloc(sizeof(NodeList)); nodelist_init(nl);
            for(int i=0;i<var_id_count;i++) {
                Node *p = node_new(ND_PARAM,yylineno); p->u.sval=strdup(var_ids[i]); p->flags=1;
                node_add_child(p,(i==0)?$4:node_clone($4)); nodelist_append(nl,p);
            }
            clear_var_ids(); $$=nl;
        }
    ;

param_id_list
    : TIDENT                   { push_var_id($1); free($1); }
    | param_id_list ',' TIDENT { push_var_id($3); free($3); }
    ;

stmt_list
    : stmt_list ';' statement  { $$ = $1; if($3) nodelist_append($$,$3); }
    | stmt_list error ';'
        {
            /* skip unrecognised statement, insert ND_EMPTY as placeholder */
            $$ = $1;
            Node *e = node_new(ND_EMPTY, yylineno);
            nodelist_append($$, e);
            yyerrok;
        }
    | statement
        {
            $$ = malloc(sizeof(NodeList)); nodelist_init($$);
            if($1) nodelist_append($$,$1);
        }
    ;

opt_semi : ';' | /* empty */ ;

statement
    : compound_stmt    { $$ = $1; }
    | if_stmt          { $$ = $1; }
    | while_stmt       { $$ = $1; }
    | for_stmt         { $$ = $1; }
    | repeat_stmt      { $$ = $1; }
    | case_stmt        { $$ = $1; }
    | with_stmt        { $$ = $1; }
    | writeln_stmt     { $$ = $1; }
    | write_stmt       { $$ = $1; }
    | readln_stmt      { $$ = $1; }
    | read_stmt        { $$ = $1; }
    | inc_dec_stmt     { $$ = $1; }
    | new_dispose_stmt { $$ = $1; }
    | halt_stmt        { $$ = $1; }
    | exit_stmt        { $$ = $1; }
    | file_io_stmt     { $$ = $1; }
    | TBREAK    { $$ = node_new(ND_BREAK,    yylineno); }
    | TCONTINUE { $$ = node_new(ND_CONTINUE, yylineno); }
    | TGOTO TIDENT
        {
            Node *n = node_new(ND_GOTO, yylineno);
            n->u.sval = $2; $$ = n;
        }
    | TGOTO TINT_LIT
        {
            Node *n = node_new(ND_GOTO, yylineno);
            char buf[32]; snprintf(buf, sizeof(buf), "%d", $2);
            n->u.sval = strdup(buf); $$ = n;
        }
    | TIDENT ':'  statement
        {
            Node *n = node_new(ND_LABELED_STMT, yylineno);
            n->u.sval = $1; node_add_child(n, $3); $$ = n;
        }
    | TINT_LIT ':' statement
        {
            Node *n = node_new(ND_LABELED_STMT, yylineno);
            char buf[32]; snprintf(buf, sizeof(buf), "%d", $1);
            n->u.sval = strdup(buf); node_add_child(n, $3); $$ = n;
        }
    | try_stmt         { $$ = $1; }
    | TRAISE expr
        {
            Node *n = node_new(ND_RAISE, yylineno);
            node_add_child(n, $2); $$ = n;
        }
    | TRAISE
        {
            /* re-raise current exception */
            Node *n = node_new(ND_RAISE, yylineno); $$ = n;
        }
    | designator TASSIGN expr
        {
            Node *n = node_new(ND_ASSIGN,yylineno);
            node_add_child(n,$1); node_add_child(n,$3); $$=n;
        }
    | designator  { $$ = $1; }
    | /* empty */ { $$ = node_new(ND_EMPTY,yylineno); }
    ;

compound_stmt
    : TBEGIN stmt_list TEND
        {
            Node *n = node_new(ND_COMPOUND,yylineno);
            for(int i=0;i<$2->count;i++) node_add_child(n,$2->items[i]);
            nodelist_free_items($2); free($2); $$=n;
        }
    ;

/* try stmt except handler... [finally stmt] end */
try_stmt
    : TTRY stmt_list TEXCEPT except_handler_list TEND
        {
            Node *n = node_new(ND_TRY, yylineno);
            Node *body = node_new(ND_COMPOUND, yylineno);
            for (int i = 0; i < $2->count; i++) node_add_child(body, $2->items[i]);
            nodelist_free_items($2); free($2);
            node_add_child(n, body);       /* child 0: try body */
            node_add_child(n, $4);         /* child 1: handler list */
            $$ = n;
        }
    | TTRY stmt_list TFINALLY stmt_list TEND
        {
            Node *n = node_new(ND_TRY, yylineno);
            n->flags = 2; /* FLAG_FINALLY */
            Node *body = node_new(ND_COMPOUND, yylineno);
            for (int i = 0; i < $2->count; i++) node_add_child(body, $2->items[i]);
            nodelist_free_items($2); free($2);
            node_add_child(n, body);       /* child 0: try body */
            Node *fin = node_new(ND_COMPOUND, yylineno);
            for (int i = 0; i < $4->count; i++) node_add_child(fin, $4->items[i]);
            nodelist_free_items($4); free($4);
            node_add_child(n, fin);        /* child 1: finally body */
            $$ = n;
        }
    ;

/* List of except handlers: on E: Type do stmt; ... [else stmt;] */
except_handler_list
    : except_handler_list except_handler
        {
            Node *list = $1;
            node_add_child(list, $2);
            $$ = list;
        }
    | except_handler
        {
            Node *list = node_new(ND_EXCEPT_HANDLER, yylineno);
            node_add_child(list, $1);
            $$ = list;
        }
    | /* else catch-all */
      TELSE stmt_list
        {
            Node *list = node_new(ND_EXCEPT_HANDLER, yylineno);
            Node *body = node_new(ND_COMPOUND, yylineno);
            for (int i = 0; i < $2->count; i++) node_add_child(body, $2->items[i]);
            nodelist_free_items($2); free($2);
            list->flags = 1; /* catch-all */
            node_add_child(list, body);
            $$ = list;
        }
    ;

except_handler
    : TON TIDENT ':' TIDENT TDO statement ';'
        {
            /* on VarName: ExcType do stmt */
            Node *h = node_new(ND_EXCEPT_HANDLER, yylineno);
            h->u.sval = $4;  /* exception type name */
            /* store var name as ND_IDENT child[0], stmt as child[1] */
            Node *vn = node_new(ND_IDENT, yylineno);
            vn->u.sval = $2;
            node_add_child(h, vn);
            node_add_child(h, $6);
            $$ = h;
        }
    | TON TIDENT TDO statement ';'
        {
            /* on ExcType do stmt */
            Node *h = node_new(ND_EXCEPT_HANDLER, yylineno);
            h->u.sval = $2;
            node_add_child(h, $4);
            $$ = h;
        }
    ;

if_stmt
    : TIF expr TTHEN statement opt_else
        {
            Node *n = node_new(ND_IF,yylineno);
            node_add_child(n,$2); node_add_child(n,$4);
            if($5) node_add_child(n,$5); $$=n;
        }
    ;

opt_else
    : TELSE statement  { $$ = $2; }
    | /* empty */      { $$ = NULL; }
    ;

while_stmt
    : TWHILE expr TDO statement
        {
            Node *n = node_new(ND_WHILE,yylineno);
            node_add_child(n,$2); node_add_child(n,$4); $$=n;
        }
    ;

for_stmt
    : TFOR TIDENT TASSIGN expr TTO expr TDO statement
        {
            Node *n = node_new(ND_FOR,yylineno); n->flags=0;
            Node *v = node_new(ND_IDENT,yylineno); v->u.sval=$2;
            node_add_child(n,v); node_add_child(n,$4); node_add_child(n,$6); node_add_child(n,$8); $$=n;
        }
    | TFOR TIDENT TASSIGN expr TDOWNTO expr TDO statement
        {
            Node *n = node_new(ND_FOR,yylineno); n->flags=1;
            Node *v = node_new(ND_IDENT,yylineno); v->u.sval=$2;
            node_add_child(n,v); node_add_child(n,$4); node_add_child(n,$6); node_add_child(n,$8); $$=n;
        }
    | TFOR TIDENT TIN expr TDOTDOT expr TDO statement
        {
            Node *n = node_new(ND_FOR_IN,yylineno);
            Node *v = node_new(ND_IDENT,yylineno); v->u.sval=$2;
            node_add_child(n,v); node_add_child(n,$4); node_add_child(n,$6); node_add_child(n,$8); $$=n;
        }
    ;

repeat_stmt
    : TREPEAT stmt_list TUNTIL expr
        {
            Node *n = node_new(ND_REPEAT,yylineno);
            for(int i=0;i<$2->count;i++) node_add_child(n,$2->items[i]);
            nodelist_free_items($2); free($2);
            node_add_child(n,$4); $$=n;
        }
    ;

case_stmt
    : TCASE expr TOF case_list opt_case_else TEND
        {
            Node *n = node_new(ND_CASE,yylineno);
            node_add_child(n,$2);
            for(int i=0;i<$4->count;i++) node_add_child(n,$4->items[i]);
            nodelist_free_items($4); free($4);
            if($5) node_add_child(n,$5); $$=n;
        }
    ;

case_list
    : case_list case_element  { $$=$1; nodelist_append($$,$2); }
    | /* empty */  { $$=malloc(sizeof(NodeList)); nodelist_init($$); }
    ;

case_element
    : case_label_list ':' statement opt_semi
        {
            Node *n = node_new(ND_CASE_ELEM,yylineno);
            for(int i=0;i<$1->count;i++) node_add_child(n,$1->items[i]);
            nodelist_free_items($1); free($1);
            node_add_child(n,$3); $$=n;
        }
    ;

case_label_list
    : case_label
        { $$=malloc(sizeof(NodeList)); nodelist_init($$); nodelist_append($$,$1); }
    | case_label_list ',' case_label
        { $$=$1; nodelist_append($$,$3); }
    ;

case_label
    : TINT_LIT  { Node *n=node_new(ND_INT_LIT,yylineno); n->u.ival=$1; $$=n; }
    | TIDENT    { Node *n=node_new(ND_IDENT,yylineno);   n->u.sval=$1; $$=n; }
    | TSTR_LIT  /* single-char label, e.g. 'a' */
        {
            Node *n = node_new(ND_INT_LIT, yylineno);
            n->u.ival = (unsigned char)$1[0];
            free($1); $$ = n;
        }
    | TINT_LIT TDOTDOT TINT_LIT  /* integer range */
        {
            Node *n = node_new(ND_CASE_RANGE, yylineno);
            n->u.arr.lo = $1; n->u.arr.hi = $3; $$ = n;
        }
    | TSTR_LIT TDOTDOT TSTR_LIT  /* char range, e.g. 'a'..'z' */
        {
            Node *n = node_new(ND_CASE_RANGE, yylineno);
            n->u.arr.lo = (unsigned char)$1[0];
            n->u.arr.hi = (unsigned char)$3[0];
            free($1); free($3); $$ = n;
        }
    | TSTR_LIT TDOTDOT TINT_LIT  /* mixed: char..int */
        {
            Node *n = node_new(ND_CASE_RANGE, yylineno);
            n->u.arr.lo = (unsigned char)$1[0]; n->u.arr.hi = $3;
            free($1); $$ = n;
        }
    | TINT_LIT TDOTDOT TSTR_LIT  /* mixed: int..char */
        {
            Node *n = node_new(ND_CASE_RANGE, yylineno);
            n->u.arr.lo = $1; n->u.arr.hi = (unsigned char)$3[0];
            free($3); $$ = n;
        }
    ;

opt_case_else
    : TELSE statement opt_semi
        {
            Node *n   = node_new(ND_CASE_ELEM,yylineno);
            Node *def = node_new(ND_INT_LIT,yylineno); def->u.ival=-1;
            node_add_child(n,def); node_add_child(n,$2); $$=n;
        }
    | /* empty */  { $$=NULL; }
    ;

with_stmt
    : TWITH with_var_list TDO statement
        {
            Node *n = node_new(ND_WITH,yylineno);
            Node *v = node_new(ND_IDENT,yylineno); v->u.sval=$2;
            node_add_child(n,v); node_add_child(n,$4);
            while(with_depth>0) { with_depth--; free(with_stack[with_depth].varname); }
            $$=n;
        }
    ;

with_var_list
    : TIDENT              { push_with($1); $$=$1; }
    | with_var_list ',' TIDENT { push_with($3); free($1); $$=$3; }
    ;

writeln_stmt
    : TWRITELN '(' write_arg_list ')'
        {
            Node *n=node_new(ND_WRITELN,yylineno);
            for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]);
            nodelist_free_items($3); free($3); $$=n;
        }
    | TWRITELN '(' ')'  { $$=node_new(ND_WRITELN,yylineno); }
    | TWRITELN          { $$=node_new(ND_WRITELN,yylineno); }
    ;

write_stmt
    : TWRITE '(' write_arg_list ')'
        {
            Node *n=node_new(ND_WRITE,yylineno);
            for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]);
            nodelist_free_items($3); free($3); $$=n;
        }
    | TWRITE '(' ')'  { $$=node_new(ND_WRITE,yylineno); }
    ;

write_arg_list
    : write_arg_list ',' write_arg  { $$=$1; nodelist_append($$,$3); }
    | write_arg
        { $$=malloc(sizeof(NodeList)); nodelist_init($$); nodelist_append($$,$1); }
    ;

write_arg
    : expr                              { $$ = $1; }
    | expr ':' TINT_LIT                 /* width specifier: expr:N */
        {
            Node *n = node_new(ND_WRITE_FMT, yylineno);
            n->u.arr.lo = $3; n->u.arr.hi = -1;
            node_add_child(n, $1); $$ = n;
        }
    | expr ':' TINT_LIT ':' TINT_LIT   /* width.prec: expr:N:M */
        {
            Node *n = node_new(ND_WRITE_FMT, yylineno);
            n->u.arr.lo = $3; n->u.arr.hi = $5;
            node_add_child(n, $1); $$ = n;
        }
    ;

readln_stmt
    : TREADLN '(' read_arg_list ')'
        {
            Node *n=node_new(ND_READLN,yylineno);
            for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]);
            nodelist_free_items($3); free($3); $$=n;
        }
    | TREADLN '(' ')' { $$=node_new(ND_READLN,yylineno); }
    | TREADLN         { $$=node_new(ND_READLN,yylineno); }
    ;

read_stmt
    : TREAD '(' read_arg_list ')'
        {
            Node *n=node_new(ND_READ,yylineno);
            for(int i=0;i<$3->count;i++) node_add_child(n,$3->items[i]);
            nodelist_free_items($3); free($3); $$=n;
        }
    | TREAD '(' ')' { $$=node_new(ND_READ,yylineno); }
    ;

read_arg_list
    : read_arg_list ',' designator  { $$=$1; nodelist_append($$,$3); }
    | designator
        { $$=malloc(sizeof(NodeList)); nodelist_init($$); nodelist_append($$,$1); }
    ;

inc_dec_stmt
    : TINC '(' designator ')'
        { Node *n=node_new(ND_INC,yylineno); node_add_child(n,$3); $$=n; }
    | TINC '(' designator ',' expr ')'
        { Node *n=node_new(ND_INC,yylineno); node_add_child(n,$3); node_add_child(n,$5); $$=n; }
    | TDEC '(' designator ')'
        { Node *n=node_new(ND_DEC,yylineno); node_add_child(n,$3); $$=n; }
    | TDEC '(' designator ',' expr ')'
        { Node *n=node_new(ND_DEC,yylineno); node_add_child(n,$3); node_add_child(n,$5); $$=n; }
    ;

new_dispose_stmt
    : TNEW '(' designator ')'
        { Node *n=node_new(ND_NEW,yylineno); node_add_child(n,$3); $$=n; }
    | TDISPOSE '(' designator ')'
        { Node *n=node_new(ND_DISPOSE,yylineno); node_add_child(n,$3); $$=n; }
    ;

halt_stmt
    : THALT              { $$=node_new(ND_HALT,yylineno); }
    | THALT '(' expr ')' { Node *n=node_new(ND_HALT,yylineno); node_add_child(n,$3); $$=n; }
    ;

exit_stmt
    : TEXIT              { $$=node_new(ND_EXIT,yylineno); }
    | TEXIT '(' expr ')' { Node *n=node_new(ND_EXIT,yylineno); node_add_child(n,$3); $$=n; }
    ;

file_io_stmt
    : TASSIGN_F '(' expr ',' expr ')'
        {
            Node *n = node_new(ND_ASSIGN_FILE, yylineno);
            node_add_child(n, $3); node_add_child(n, $5); $$ = n;
        }
    | TREWRITE '(' expr ')'
        {
            Node *n = node_new(ND_REWRITE, yylineno);
            node_add_child(n, $3); $$ = n;
        }
    | TRESET '(' expr ')'
        {
            Node *n = node_new(ND_RESET, yylineno);
            node_add_child(n, $3); $$ = n;
        }
    | TCLOSE_F '(' expr ')'
        {
            Node *n = node_new(ND_CLOSE_FILE, yylineno);
            node_add_child(n, $3); $$ = n;
        }
    ;

expr
    : simple_expr  { $$=$1; }
    | simple_expr '<'  simple_expr { Node *n=node_new(ND_BINOP,yylineno); n->u.op='<'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr '>'  simple_expr { Node *n=node_new(ND_BINOP,yylineno); n->u.op='>'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr TLE  simple_expr { Node *n=node_new(ND_BINOP,yylineno); n->u.op='L'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr TGE  simple_expr { Node *n=node_new(ND_BINOP,yylineno); n->u.op='G'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr '='  simple_expr { Node *n=node_new(ND_BINOP,yylineno); n->u.op='='; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr TNE  simple_expr { Node *n=node_new(ND_BINOP,yylineno); n->u.op='N'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr TIN  simple_expr { Node *n=node_new(ND_BINOP,yylineno); n->u.op='i'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    ;

simple_expr
    : term  { $$=$1; }
    | simple_expr '+' term { Node *n=node_new(ND_BINOP,yylineno); n->u.op='+'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr '-' term { Node *n=node_new(ND_BINOP,yylineno); n->u.op='-'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr TOR  term { Node *n=node_new(ND_BINOP,yylineno); n->u.op='|'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | simple_expr TXOR term { Node *n=node_new(ND_BINOP,yylineno); n->u.op='X'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    ;

term
    : factor  { $$=$1; }
    | term '*'   factor { Node *n=node_new(ND_BINOP,yylineno); n->u.op='*'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | term '/'   factor { Node *n=node_new(ND_BINOP,yylineno); n->u.op='/'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | term TDIV  factor { Node *n=node_new(ND_BINOP,yylineno); n->u.op='D'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | term TMOD  factor { Node *n=node_new(ND_BINOP,yylineno); n->u.op='M'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | term TAND  factor { Node *n=node_new(ND_BINOP,yylineno); n->u.op='&'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | term TSHL  factor { Node *n=node_new(ND_BINOP,yylineno); n->u.op='K'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    | term TSHR  factor { Node *n=node_new(ND_BINOP,yylineno); n->u.op='R'; node_add_child(n,$1); node_add_child(n,$3); $$=n; }
    ;

factor
    : designator              { $$=$1; }
    | TINT_LIT    { Node *n=node_new(ND_INT_LIT,yylineno);  n->u.ival=$1; $$=n; }
    | TREAL_LIT   { Node *n=node_new(ND_REAL_LIT,yylineno); n->u.rval=$1; $$=n; }
    | TBOOL_LIT   { Node *n=node_new(ND_BOOL_LIT,yylineno); n->u.ival=$1; $$=n; }
    | TNIL        { $$=node_new(ND_NIL,yylineno); }
    | TSTR_LIT    { Node *n=node_new(ND_STR_LIT,yylineno); n->u.sval=$1; $$=n; }
    | '(' expr ')'            { $$=$2; }
    | TNOT factor             { Node *n=node_new(ND_UNOP,yylineno); n->u.op='!'; node_add_child(n,$2); $$=n; }
    | '-' factor %prec UMINUS { Node *n=node_new(ND_UNOP,yylineno); n->u.op='-'; node_add_child(n,$2); $$=n; }
    | '@' designator          { Node *n=node_new(ND_ADDR_OF,yylineno); node_add_child(n,$2); $$=n; }
    | '[' ']'
        { $$=node_new(ND_SET_LIT,yylineno); }
    | '[' set_elem_list ']'
        { $$=$2; }
    ;

designator
    : TIDENT opt_call
        {
            if ($2 == NULL) {
                const char *wvar = NULL;
                const char *wfield = resolve_with_field($1, &wvar);
                if (wfield) {
                    Node *base = node_new(ND_IDENT,yylineno); base->u.sval=strdup(wvar);
                    Node *fd   = node_new(ND_FIELD,yylineno); fd->u.sval=strdup(wfield);
                    node_add_child(fd, base); free($1); $$=fd;
                } else {
                    int is_ret = cur_func_name && strcasecmp($1,cur_func_name)==0;
                    SubrEntry2 *se = is_ret ? NULL : find_subr2($1);
                    if (se) {
                        Node *n=node_new(ND_FUNC_CALL,yylineno); n->u.sval=$1; $$=n;
                    } else {
                        Node *n=node_new(ND_IDENT,yylineno); n->u.sval=$1; $$=n;
                    }
                }
            } else {
                Node *n=node_new(ND_FUNC_CALL,yylineno); n->u.sval=$1;
                NodeList *args=(NodeList*)$2;
                if(args) {
                    for(int i=0;i<args->count;i++) node_add_child(n,args->items[i]);
                    nodelist_free_items(args); free(args);
                }
                $$=n;
            }
        }
    | designator '[' expr ']'
        {
            Node *n=node_new(ND_INDEX,yylineno);
            node_add_child(n,$1); node_add_child(n,$3); $$=n;
        }
    | designator '[' expr ',' comma_expr_tail ']'
        {
            /* Multi-dim index: build nested ND_INDEX chain */
            Node *base = node_new(ND_INDEX, yylineno);
            node_add_child(base, $1); node_add_child(base, $3);
            Node *cur = base;
            for (int i = 0; i < $5->count; i++) {
                Node *idx = node_new(ND_INDEX, yylineno);
                node_add_child(idx, cur);
                node_add_child(idx, $5->items[i]);
                cur = idx;
            }
            nodelist_free_items($5); free($5);
            $$ = cur;
        }
    | designator '.' TIDENT
        {
            Node *n=node_new(ND_FIELD,yylineno); n->u.sval=$3;
            node_add_child(n,$1); $$=n;
        }
    | designator '^'
        { Node *n=node_new(ND_DEREF,yylineno); node_add_child(n,$1); $$=n; }
    ;

opt_call
    : /* empty */       { $$=NULL; }
    | '(' ')'
        { NodeList *nl=malloc(sizeof(NodeList)); nodelist_init(nl); $$=(char*)nl; }
    | '(' arg_list ')'  { $$=(char*)$2; }
    ;

arg_list
    : expr
        { $$=malloc(sizeof(NodeList)); nodelist_init($$); nodelist_append($$,$1); }
    | arg_list ',' expr  { $$=$1; nodelist_append($$,$3); }
    ;

/* label declaration list - just parse and discard, labels become C labels at use-site */
label_decl_list
    : TIDENT                        { /* discard */ }
    | TINT_LIT                      { /* discard */ }
    | label_decl_list ',' TIDENT    { /* discard */ }
    | label_decl_list ',' TINT_LIT  { /* discard */ }
    ;

set_elem_list
    : set_elem
        {
            Node *n=node_new(ND_SET_LIT,yylineno);
            node_add_child(n,$1); $$=n;
        }
    | set_elem_list ',' set_elem
        { node_add_child($1,$3); $$=$1; }
    ;

set_elem
    : expr TDOTDOT expr
        {
            Node *n=node_new(ND_SET_RANGE,yylineno);
            node_add_child(n,$1); node_add_child(n,$3); $$=n;
        }
    | expr  { $$=$1; }
    ;

%%

void yyerror(const char *msg)
{
    fprintf(stderr, "parse error at line %d: %s\n", yylineno, msg);
    g_parse_errors++;
}
