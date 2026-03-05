/* pascal_runtime.h – C11 runtime helpers for pascal2c generated code */
#ifndef PASCAL_RUNTIME_H
#define PASCAL_RUNTIME_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include <ctype.h>
#include <time.h>

/* ------------------------------------------------------------------ */
/*  Type-generic output (C11 _Generic)                                 */
/*  Non-selected branches may warn but never error (-Wno-format).      */
/* ------------------------------------------------------------------ */
#define PASCAL_WRITE(x) _Generic((x),        \
    int:         printf("%d",  (x)),          \
    long:        printf("%ld", (x)),          \
    float:       printf("%g",  (x)),          \
    double:      printf("%g",  (x)),          \
    char:        printf("%c",  (x)),          \
    char *:      printf("%s",  (x)),          \
    const char*: printf("%s",  (x)),          \
    default:     printf("%d",  (x))           \
)

#define PASCAL_WRITELN(x) do { PASCAL_WRITE(x); printf("\n"); } while (0)
#define PASCAL_NL()       printf("\n")

/* ------------------------------------------------------------------ */
/*  Input helpers                                                       */
/* ------------------------------------------------------------------ */
/* Skip to end of current input line (consume newline) */
#define PASCAL_SKIP_LINE() \
    do { int _pc; while ((_pc = getchar()) != '\n' && _pc != EOF) ; } while (0)

/* Read a whole line into a char buffer, strip trailing newline; uses sizeof(x) */
#define PASCAL_READ_LINE(x) \
    do { \
        if (fgets((x), (int)sizeof(x), stdin)) { \
            int _rl = (int)strlen(x); \
            if (_rl > 0 && (x)[_rl - 1] == '\n') (x)[_rl - 1] = '\0'; \
        } \
    } while (0)

/* Legacy macro kept for file-based reads; stdin reads now use type-specific calls */
#define PASCAL_READLN(x) _Generic((x),         \
    int:    scanf(" %d",   &(x)),              \
    long:   scanf(" %ld",  &(x)),              \
    float:  scanf(" %f",   &(x)),              \
    double: scanf(" %lf",  &(x)),              \
    char:   scanf("%c",    &(x)),              \
    char *: scanf(" %254[^\n]", (x)),          \
    default: scanf(" %d",  &(x))               \
)

/* ------------------------------------------------------------------ */
/*  Pascal boolean constants                                            */
/* ------------------------------------------------------------------ */
#ifndef TRUE
#  define TRUE  1
#endif
#ifndef FALSE
#  define FALSE 0
#endif

/* ------------------------------------------------------------------ */
/*  Random numbers                                                      */
/* ------------------------------------------------------------------ */
#include <time.h>

/* random(n) – returns integer in [0, n-1]; random with no arg → real [0,1) */
static inline int pascal_random_int(int n)
{
    if (n <= 0) return 0;
    return (int)(rand() % (unsigned)n);
}
static inline double pascal_random_real(void)
{
    return (double)rand() / ((double)RAND_MAX + 1.0);
}
/* randomize – seed from wall clock */
static inline void pascal_randomize(void) { srand((unsigned int)time(NULL)); }

/* ------------------------------------------------------------------ */
/*  Pointer helpers                                                     */
/* ------------------------------------------------------------------ */
#define PASCAL_NEW(p)     ((p) = malloc(sizeof(*(p))))
#define PASCAL_DISPOSE(p) (free(p), (p) = NULL)

/* ------------------------------------------------------------------ */
/*  String helpers                                                      */
/* ------------------------------------------------------------------ */

/* pascal_copy(s, pos, len) – 1-based substring, returns static buffer */
static inline char *pascal_copy(const char *s, int pos, int len)
{
    static char _buf[1024];
    int slen = (int)strlen(s);
    int start = pos - 1;  /* convert 1-based to 0-based */
    if (start < 0) start = 0;
    if (start >= slen) { _buf[0] = '\0'; return _buf; }
    if (start + len > slen) len = slen - start;
    if (len < 0) len = 0;
    memcpy(_buf, s + start, (size_t)len);
    _buf[len] = '\0';
    return _buf;
}

/* pascal_concat(a, b) – concatenate two strings, returns static buffer */
static inline char *pascal_concat(const char *a, const char *b)
{
    static char _buf[1024];
    snprintf(_buf, sizeof(_buf), "%s%s", a ? a : "", b ? b : "");
    return _buf;
}

/* pascal_pos(sub, str) – 1-based position of sub in str, 0 if not found */
static inline int pascal_pos(const char *sub, const char *str)
{
    if (!sub || !str) return 0;
    const char *p = strstr(str, sub);
    if (!p) return 0;
    return (int)(p - str) + 1;
}

/* pascal_inttostr(n) – integer to string, returns static buffer */
static inline char *pascal_inttostr(int n)
{
    static char _buf[32];
    snprintf(_buf, sizeof(_buf), "%d", n);
    return _buf;
}

/* pascal_floattostr(x) – real to string, returns static buffer */
static inline char *pascal_floattostr(double x)
{
    static char _buf[64];
    snprintf(_buf, sizeof(_buf), "%g", x);
    return _buf;
}

/* pascal_formatfloat(fmt, x) – format real using printf-style fmt string */
static inline char *pascal_formatfloat(const char *fmt, double x)
{
    static char _buf[128];
    snprintf(_buf, sizeof(_buf), fmt, x);
    return _buf;
}

/* pascal_str(n, s) – write integer n as string into s */
static inline void pascal_str(int n, char *s) { sprintf(s, "%d", n); }

/* pascal_val(s, n, code) – parse integer from string */
static inline void pascal_val(const char *s, int *n, int *code)
{
    char *end;
    *n    = (int)strtol(s, &end, 10);
    *code = (*end != '\0') ? 1 : 0;
}

/* pascal_delete(s, pos, len) – delete len chars at 1-based pos in-place */
static inline void pascal_delete(char *s, int pos, int len)
{
    if (!s || pos < 1 || len <= 0) return;
    int slen = (int)strlen(s);
    int start = pos - 1;
    if (start >= slen) return;
    if (start + len > slen) len = slen - start;
    memmove(s + start, s + start + len, (size_t)(slen - start - len + 1));
}

/* pascal_insert(src, dest, pos) – insert src into dest at 1-based pos in-place */
static inline void pascal_insert(const char *src, char *dest, int pos)
{
    if (!src || !dest) return;
    int slen = (int)strlen(src);
    int dlen = (int)strlen(dest);
    int start = pos - 1;
    if (start < 0) start = 0;
    if (start > dlen) start = dlen;
    /* shift dest right to make room */
    memmove(dest + start + slen, dest + start, (size_t)(dlen - start + 1));
    memcpy(dest + start, src, (size_t)slen);
}

/* pascal_trim(s) – remove leading and trailing whitespace, returns static buf */
static inline char *pascal_trim(const char *s)
{
    static char _buf[1024];
    if (!s) { _buf[0] = '\0'; return _buf; }
    while (*s == ' ' || *s == '\t' || *s == '\r' || *s == '\n') s++;
    int len = (int)strlen(s);
    while (len > 0 && (s[len-1] == ' ' || s[len-1] == '\t' ||
                        s[len-1] == '\r' || s[len-1] == '\n')) len--;
    if (len >= (int)sizeof(_buf)) len = (int)sizeof(_buf) - 1;
    memcpy(_buf, s, (size_t)len);
    _buf[len] = '\0';
    return _buf;
}

/* pascal_lowercase(s) – lowercase copy, returns static buffer */
static inline char *pascal_lowercase(const char *s)
{
    static char _buf[1024];
    if (!s) { _buf[0] = '\0'; return _buf; }
    int i;
    for (i = 0; s[i] && i < (int)sizeof(_buf) - 1; i++)
        _buf[i] = (char)tolower((unsigned char)s[i]);
    _buf[i] = '\0';
    return _buf;
}

/* pascal_uppercase(s) – uppercase copy, returns static buffer */
static inline char *pascal_uppercase(const char *s)
{
    static char _buf[1024];
    if (!s) { _buf[0] = '\0'; return _buf; }
    int i;
    for (i = 0; s[i] && i < (int)sizeof(_buf) - 1; i++)
        _buf[i] = (char)toupper((unsigned char)s[i]);
    _buf[i] = '\0';
    return _buf;
}

/* ------------------------------------------------------------------ */
/*  Set helpers                                                         */
/* ------------------------------------------------------------------ */

/* pascal_set_range(lo, hi) – bitmask for ordinal range [lo..hi] */
static inline uint64_t pascal_set_range(int lo, int hi)
{
    uint64_t mask = 0;
    for (int i = lo; i <= hi && i < 64; i++) mask |= (1ULL << i);
    return mask;
}

/* pascal_strcat_new(a, b) – return concatenation of two strings.
   Uses a static ring buffer (16 slots × 512 bytes) so no heap allocation
   is needed. Strings longer than 511 chars are truncated. */
#define PASCAL_STRCAT_SLOTS  16
#define PASCAL_STRCAT_SLOTSZ 512
static inline char *pascal_strcat_new(const char *a, const char *b)
{
    static char pool[PASCAL_STRCAT_SLOTS][PASCAL_STRCAT_SLOTSZ];
    static int  slot = 0;
    char *r = pool[slot % PASCAL_STRCAT_SLOTS];
    slot++;
    size_t la = strlen(a), lb = strlen(b);
    if (la >= PASCAL_STRCAT_SLOTSZ - 1) la = PASCAL_STRCAT_SLOTSZ - 1;
    if (la + lb >= PASCAL_STRCAT_SLOTSZ) lb = PASCAL_STRCAT_SLOTSZ - 1 - la;
    memcpy(r, a, la);
    memcpy(r + la, b, lb);
    r[la + lb] = '\0';
    return r;
}

/* String comparison helpers – use strcmp so pointer equality is not tested */
#define pascal_seq(a,b)  (strcmp((a),(b)) == 0)
#define pascal_sne(a,b)  (strcmp((a),(b)) != 0)
#define pascal_slt(a,b)  (strcmp((a),(b)) <  0)
#define pascal_sgt(a,b)  (strcmp((a),(b)) >  0)
#define pascal_sle(a,b)  (strcmp((a),(b)) <= 0)
#define pascal_sge(a,b)  (strcmp((a),(b)) >= 0)

/* ------------------------------------------------------------------ */
/*  File I/O (text files)                                              */
/*  Pascal 'text' type maps to pascal_file_t.                         */
/* ------------------------------------------------------------------ */
typedef struct {
    FILE       *fp;
    char        name[512];  /* filename stored by assign() */
} pascal_file_t;

#define pascal_assign(f, s)  do { strncpy((f).name, (s), 511); (f).name[511]='\0'; } while(0)
#define pascal_rewrite(f)    do { (f).fp = fopen((f).name, "w"); } while(0)
#define pascal_reset(f)      do { (f).fp = fopen((f).name, "r"); } while(0)
#define pascal_close(f)      do { if ((f).fp) { fclose((f).fp); (f).fp = NULL; } } while(0)
/* peek-ahead: returns true if the next getc would return EOF */
#define pascal_eof(f)        ((f).fp == NULL || (ungetc(getc((f).fp), (f).fp) == EOF))

/* Generic file write using the same _Generic trick as PASCAL_WRITE */
#define PASCAL_FWRITE(f, x) _Generic((x),         \
    int:         fprintf((f).fp, "%d",  (x)),     \
    long:        fprintf((f).fp, "%ld", (x)),     \
    float:       fprintf((f).fp, "%g",  (x)),     \
    double:      fprintf((f).fp, "%g",  (x)),     \
    char:        fprintf((f).fp, "%c",  (x)),     \
    char *:      fprintf((f).fp, "%s",  (x)),     \
    const char*: fprintf((f).fp, "%s",  (x)),     \
    default:     fprintf((f).fp, "%d",  (x))      \
)
#define PASCAL_FNL(f)        fprintf((f).fp, "\n")
#define PASCAL_FWRITELN(f,x) do { PASCAL_FWRITE(f,x); PASCAL_FNL(f); } while(0)

/* Generic file read – reads value then consumes rest of line (true readln) */
static inline void pascal_freadln_skip(FILE *fp)
{
    int c;
    while ((c = fgetc(fp)) != '\n' && c != EOF) {}
}
#define PASCAL_FREADLN(f, x) do {                           \
    _Generic((x),                                           \
        int:    fscanf((f).fp, "%d",    &(x)),              \
        long:   fscanf((f).fp, "%ld",   &(x)),              \
        float:  fscanf((f).fp, "%f",    &(x)),              \
        double: fscanf((f).fp, "%lf",   &(x)),              \
        char:   fscanf((f).fp, " %c",   &(x)),              \
        char *: fscanf((f).fp, "%255[^\n]", (x)),           \
        default: fscanf((f).fp, "%d",   &(x))               \
    );                                                      \
    pascal_freadln_skip((f).fp);                            \
} while(0)

/* ------------------------------------------------------------------ */
/*  Exception handling (try/except/finally/raise)                      */
/*  Maps to setjmp/longjmp.                                            */
/* ------------------------------------------------------------------ */
#include <setjmp.h>

#define PASCAL_EXC_NONE    0   /* no active exception */
#define PASCAL_EXC_USER    1   /* user raise() */
#define PASCAL_EXC_ANY    -1   /* catch-all */

typedef struct PascalExcFrame {
    jmp_buf jb;
    int     code;
    char   *message;
    struct PascalExcFrame *prev;
} PascalExcFrame;

/* Per-thread (global for single-thread programs) exception stack */
static PascalExcFrame *pascal_exc_top = NULL;
static int  pascal_exc_code = PASCAL_EXC_NONE;
static char *pascal_exc_msg  = NULL;

/* PASCAL_TRY / PASCAL_EXCEPT / PASCAL_FINALLY / PASCAL_END_TRY */
#define PASCAL_TRY \
    do { \
        PascalExcFrame __frame__; \
        __frame__.prev = pascal_exc_top; \
        pascal_exc_top = &__frame__; \
        __frame__.code = setjmp(__frame__.jb); \
        if (__frame__.code == 0) {

#define PASCAL_EXCEPT \
        } \
        pascal_exc_top = __frame__.prev; \
        if (__frame__.code != 0) { \
            pascal_exc_code = __frame__.code; \
            pascal_exc_msg  = __frame__.message;

#define PASCAL_FINALLY \
        } \
        pascal_exc_top = __frame__.prev; \
        {  /* finally block always runs */

#define PASCAL_END_TRY \
        } \
    } while (0)

/* PASCAL_RAISE(code, msg) – raise an exception */
#define PASCAL_RAISE(code, msg) \
    do { \
        if (pascal_exc_top) { \
            pascal_exc_top->message = (char *)(msg); \
            longjmp(pascal_exc_top->jb, (code)); \
        } else { \
            fprintf(stderr, "Unhandled exception %d: %s\n", (code), (msg)); \
            exit(1); \
        } \
    } while (0)

/* PASCAL_RAISE_MSG(msg) – raise exception code 1 with a message */
#define PASCAL_RAISE_MSG(msg) PASCAL_RAISE(1, (msg))

/* ExceptionMessage() – access last exception message in except block */
static inline char *pascal_exc_message(void) { return pascal_exc_msg ? pascal_exc_msg : ""; }
static inline int   pascal_exc_code_val(void) { return pascal_exc_code; }

/* ------------------------------------------------------------------ */
/*  Terminal / ANSI helpers                                             */
/* ------------------------------------------------------------------ */
#include <time.h>      /* nanosleep, struct timespec */
#include <unistd.h>    /* STDIN_FILENO               */

/* ANSI foreground color codes (textcolor argument values 0-15) */
static inline void pascal_textcolor(int c) {
    if (c < 8) printf("\033[%dm", 30 + c);
    else       printf("\033[%dm", 90 + (c - 8));
    fflush(stdout);
}

/* Clear screen and home cursor */
static inline void pascal_clrscr(void) { printf("\033[2J\033[H"); fflush(stdout); }

/* Move cursor to column x, row y (1-based) */
static inline void pascal_gotoxy(int x, int y) { printf("\033[%d;%dH", y, x); fflush(stdout); }

/* Pause for ms milliseconds */
static inline void pascal_delay(int ms) {
    struct timespec ts;
    ts.tv_sec  = (time_t)(ms / 1000);
    ts.tv_nsec = (long)(ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

/* Hide / show the terminal cursor */
static inline void pascal_hide_cursor(void) { printf("\033[?25l"); fflush(stdout); }
static inline void pascal_show_cursor(void) { printf("\033[?25h"); fflush(stdout); }

/* ---- Non-blocking keyboard input (POSIX) ------------------------- */
#include <termios.h>
#include <sys/select.h>

/* Returns 1 if a key is waiting in stdin, 0 otherwise */
static inline int pascal_keypressed(void)
{
    struct timeval tv = {0, 0};
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    return select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv) > 0;
}

/* Read one raw character without echo */
static inline char pascal_readkey(void)
{
    struct termios old, raw;
    tcgetattr(STDIN_FILENO, &old);
    raw = old;
    raw.c_lflag &= (tcflag_t)~(ICANON | ECHO);
    raw.c_cc[VMIN] = 1; raw.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
    int c = getchar();
    tcsetattr(STDIN_FILENO, TCSANOW, &old);
    return (char)c;
}

/* Switch terminal to/from raw mode (use around game loops) */
static struct termios pascal__saved_termios;
static inline void pascal_raw_mode(void) {
    struct termios raw;
    tcgetattr(STDIN_FILENO, &pascal__saved_termios);
    raw = pascal__saved_termios;
    raw.c_lflag &= (tcflag_t)~(ICANON | ECHO);
    raw.c_cc[VMIN] = 0; raw.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &raw);
}
static inline void pascal_normal_mode(void) {
    tcsetattr(STDIN_FILENO, TCSANOW, &pascal__saved_termios);
}

/* ANSI color name constants (for use with write/concat) */
#define ANSI_RESET    "\033[0m"
#define ANSI_BLACK    "\033[30m"
#define ANSI_RED      "\033[31m"
#define ANSI_GREEN    "\033[32m"
#define ANSI_YELLOW   "\033[33m"
#define ANSI_BLUE     "\033[34m"
#define ANSI_MAGENTA  "\033[35m"
#define ANSI_CYAN     "\033[36m"
#define ANSI_WHITE    "\033[37m"
#define ANSI_BRED     "\033[91m"
#define ANSI_BGREEN   "\033[92m"
#define ANSI_BYELLOW  "\033[93m"
#define ANSI_BBLUE    "\033[94m"
#define ANSI_BMAGENTA "\033[95m"
#define ANSI_BCYAN    "\033[96m"
#define ANSI_BWHITE   "\033[97m"

#endif /* PASCAL_RUNTIME_H */
