/***************************************************************************
--    Pascal to C Transpiler - Flex lexer for Pascal subset (extended).
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
#include "parser.tab.h"
#include <stdlib.h>
#include <string.h>
%}

%option noyywrap
%option case-insensitive
%option yylineno
%option nounput
%option noinput

DIGIT   [0-9]
LETTER  [a-zA-Z_]
ID      {LETTER}({LETTER}|{DIGIT})*

%%

 /* ---- keywords ---- */
"program"   { return PROGRAM;    }
"var"       { return VAR;        }
"begin"     { return TBEGIN;     }
"end"       { return TEND;       }
"integer"   { return TINTEGER;   }
"real"      { return TREAL;      }
"boolean"   { return TBOOLEAN;   }
"char"      { return TCHAR;      }
"string"    { return TSTRING;    }
"text"      { return TTEXT;      }
"if"        { return TIF;        }
"then"      { return TTHEN;      }
"else"      { return TELSE;      }
"while"     { return TWHILE;     }
"do"        { return TDO;        }
"for"       { return TFOR;       }
"to"        { return TTO;        }
"downto"    { return TDOWNTO;    }
"repeat"    { return TREPEAT;    }
"until"     { return TUNTIL;     }
"case"      { return TCASE;      }
"of"        { return TOF;        }
"with"      { return TWITH;      }
"record"    { return TRECORD;    }
"type"      { return TTYPE;      }
"const"     { return TCONST;     }
"array"     { return TARRAY;     }
"nil"       { return TNIL;       }
"new"       { return TNEW;       }
"dispose"   { return TDISPOSE;   }
"inc"       { return TINC;       }
"dec"       { return TDEC;       }
"halt"      { return THALT;      }
"exit"      { return TEXIT;      }
"break"     { return TBREAK;     }
"continue"  { return TCONTINUE;  }
"goto"      { return TGOTO;      }
"label"     { return TLABEL;     }
"forward"   { return TFORWARD;   }
"assign"    { return TASSIGN_F;  }
"rewrite"   { return TREWRITE;   }
"reset"     { return TRESET;     }
"close"     { return TCLOSE_F;   }
"unit"      { return TUNIT;      }
"uses"      { return TUSES;      }
"interface" { return TINTERFACE; }
"implementation" { return TIMPLEMENTATION; }
"try"       { return TTRY;       }
"except"    { return TEXCEPT;    }
"finally"   { return TFINALLY;  }
"raise"     { return TRAISE;     }
"on"        { return TON;        }
"writeln"   { return TWRITELN;   }
"write"     { return TWRITE;     }
"readln"    { return TREADLN;    }
"read"      { return TREAD;      }
"div"       { return TDIV;       }
"mod"       { return TMOD;       }
"and"       { return TAND;       }
"or"        { return TOR;        }
"not"       { return TNOT;       }
"xor"       { return TXOR;       }
"shl"       { return TSHL;       }
"shr"       { return TSHR;       }
"set"       { return TSET;       }
"in"        { return TIN;        }
"function"  { return TFUNCTION;  }
"procedure" { return TPROCEDURE; }
"true"      { yylval.ival = 1; return TBOOL_LIT; }
"false"     { yylval.ival = 0; return TBOOL_LIT; }

 /* ---- compound operators ---- */
":="        { return TASSIGN; }
"<="        { return TLE;     }
">="        { return TGE;     }
"<>"        { return TNE;     }
".."        { return TDOTDOT; }

 /* ---- numeric literals ---- */
{DIGIT}+\.{DIGIT}+  { yylval.rval = atof(yytext); return TREAL_LIT; }
{DIGIT}+            { yylval.ival = atoi(yytext); return TINT_LIT;  }

 /* ---- string literal (supports '' as escaped apostrophe) ---- */
'([^'\n]|'')*'  {
    int i, j, len = yyleng - 2;
    char *raw = yytext + 1;
    char *s = malloc(len + 1);
    j = 0;
    for (i = 0; i < len; i++) {
        if (raw[i] == '\'' && raw[i+1] == '\'') {
            s[j++] = '\'';
            i++;           /* skip second quote */
        } else {
            s[j++] = raw[i];
        }
    }
    s[j] = '\0';
    yylval.sval = s;
    return TSTR_LIT;
}

 /* ---- identifiers ---- */
{ID}    { yylval.sval = strdup(yytext); return TIDENT; }

 /* ---- whitespace & comments ---- */
[ \t\r\n]+             { /* skip */ }
"{"[^}]*"}"            { /* block comment { ... } */ }
"(*"([^*]|\*[^)])*"*)" { /* block comment (* ... *) */ }
"//"[^\n]*             { /* line comment */ }

 /* ---- single-character tokens ---- */
.   { return yytext[0]; }

%%

