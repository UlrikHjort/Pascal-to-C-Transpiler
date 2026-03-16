# Makefile - Pascal to C transpiler
#
# Tools:
#   flex      - lexer generator
#   bison     - parser generator
#   gcc       - compile flex/bison/glue C files
#   gnatmake  - compile Ada sources and link everything
#
# Layout:
#   parser/   flex (.l) and bison (.y) sources
#   src/      Ada sources + glue.c
#   include/  pascal_runtime.h (shipped with generated .c files)
#   examples/ sample Pascal programs
#   build/    all intermediate objects (.o, .ali, generated C)
#   bin/      final binary

CC       = gcc
FLEX     = flex
BISON    = bison
GNATMAKE = gnatmake

SRC_DIR      = src
PARSER_DIR   = parser
INCLUDE_DIR  = include
EXAMPLES_DIR = examples
BIN_DIR      = bin
BUILD_DIR    = build
# pascal2c-generated C files
C_SRC_DIR    = c_src
# compiled executables from generated C
OUTPUT_DIR   = output

TARGET = $(BIN_DIR)/pascal2c

CFLAGS    = -I$(BUILD_DIR) -I$(SRC_DIR) -I$(INCLUDE_DIR) -Wall -std=c11 -D_POSIX_C_SOURCE=200809L
# Flags for compiling pascal2c-generated C files:
# -Wno-format silences _Generic non-selected branch format mismatches (harmless).
GENCFLAGS = -I$(INCLUDE_DIR) -Wno-format -std=c11 -D_POSIX_C_SOURCE=200809L

# Discover all Pascal examples automatically
PAS_SOURCES := $(wildcard $(EXAMPLES_DIR)/*.pas)
C_GENERATED := $(patsubst $(EXAMPLES_DIR)/%.pas, $(C_SRC_DIR)/%.c,   $(PAS_SOURCES))
PROGRAMS    := $(patsubst $(EXAMPLES_DIR)/%.pas, $(OUTPUT_DIR)/%, $(PAS_SOURCES))

.PHONY: all clean distclean run-hello run-fibonacci run-factorial \
        transpile compile-c test test-units test-features demos

TESTS_DIR = tests
DEMOS_DIR = demos

# ------------------------------------------------------------------ #
all: $(TARGET) test
	@echo "=== Build and tests complete ==="

$(BUILD_DIR) $(BIN_DIR):
	mkdir -p $@

$(C_SRC_DIR) $(OUTPUT_DIR):
	mkdir -p $@

# ---- flex + bison ------------------------------------------------- #

$(BUILD_DIR)/parser.tab.c $(BUILD_DIR)/parser.tab.h: $(PARSER_DIR)/parser.y | $(BUILD_DIR)
	$(BISON) -d -o $(BUILD_DIR)/parser.tab.c $<

$(BUILD_DIR)/lex.yy.c: $(PARSER_DIR)/lexer.l $(BUILD_DIR)/parser.tab.h | $(BUILD_DIR)
	$(FLEX) -o $@ $<

# ---- compile C objects -------------------------------------------- #

$(BUILD_DIR)/parser.tab.o: $(BUILD_DIR)/parser.tab.c $(SRC_DIR)/ast.h
	$(CC) $(CFLAGS) -I$(SRC_DIR) -c -o $@ $<

$(BUILD_DIR)/lex.yy.o: $(BUILD_DIR)/lex.yy.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILD_DIR)/glue.o: $(SRC_DIR)/glue.c $(BUILD_DIR)/parser.tab.h \
                    $(SRC_DIR)/ast.h
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILD_DIR)/ast.o: $(SRC_DIR)/ast.c $(SRC_DIR)/ast.h
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILD_DIR)/ast_accessors.o: $(SRC_DIR)/ast_accessors.c $(SRC_DIR)/ast.h
	$(CC) $(CFLAGS) -c -o $@ $<

# ---- compile Ada and link ----------------------------------------- #
# gnatmake compiles all Ada units reachable from main.adb, then links.
# The C objects are appended via -largs.

AST_OBJS = $(BUILD_DIR)/ast.o $(BUILD_DIR)/ast_accessors.o

$(TARGET): $(BUILD_DIR)/parser.tab.o $(BUILD_DIR)/lex.yy.o $(BUILD_DIR)/glue.o \
           $(AST_OBJS) | $(BIN_DIR)
	$(GNATMAKE) main              \
	    -I$(SRC_DIR)              \
	    -D $(BUILD_DIR)           \
	    -o $(TARGET)              \
	    -largs                    \
	        $(BUILD_DIR)/parser.tab.o \
	        $(BUILD_DIR)/lex.yy.o     \
	        $(BUILD_DIR)/glue.o       \
	        $(AST_OBJS)               \
	        -lm

# ------------------------------------------------------------------ #
# Convenience targets: transpile an example and compile+run the result
# ------------------------------------------------------------------ #

run-hello: $(TARGET)
	./$(TARGET) examples/hello.pas $(BUILD_DIR)/hello.c
	$(CC) $(GENCFLAGS) $(BUILD_DIR)/hello.c -o $(BUILD_DIR)/hello -lm
	@echo "--- running hello ---"
	$(BUILD_DIR)/hello

run-fibonacci: $(TARGET)
	./$(TARGET) examples/fibonacci.pas $(BUILD_DIR)/fibonacci.c
	$(CC) $(GENCFLAGS) $(BUILD_DIR)/fibonacci.c -o $(BUILD_DIR)/fibonacci -lm
	@echo "--- running fibonacci ---"
	$(BUILD_DIR)/fibonacci

run-factorial: $(TARGET)
	./$(TARGET) examples/factorial.pas $(BUILD_DIR)/factorial.c
	$(CC) $(GENCFLAGS) $(BUILD_DIR)/factorial.c -o $(BUILD_DIR)/factorial -lm
	@echo "--- running factorial ---"
	$(BUILD_DIR)/factorial

# ================================================================== #
#  Full build and test: Pascal -> C -> compile -> verify output          #
#                                                                     #
#  Directories:                                                       #
#    c_src/    pascal2c-generated C source files                      #
#    output/   compiled executables from generated C                  #
#                                                                     #
#  Targets:                                                           #
#    transpile  - run pascal2c on every examples/*.pas                #
#    compile-c  - compile every c_src/*.c into output/               #
#    test       - run each output/* and diff against .expected        #
# ================================================================== #

# ---- Step 1: transpile .pas -> .c --------------------------------- #
$(C_SRC_DIR)/%.c: $(EXAMPLES_DIR)/%.pas $(TARGET) | $(C_SRC_DIR)
	@echo "  transpile  $< -> $@"
	@./$(TARGET) $< $@

transpile: $(C_GENERATED)

# ---- Step 2: compile .c -> executable ----------------------------- #
$(OUTPUT_DIR)/%: $(C_SRC_DIR)/%.c | $(OUTPUT_DIR)
	@echo "  compile-c  $< -> $@"
	@$(CC) $(GENCFLAGS) $< -o $@ -lm

compile-c: $(PROGRAMS)

# ---- Step 3: run each program and compare against .expected ------- #
test: compile-c
	@echo ""
	@echo "=== pascal2c tests ==="
	@echo ""
	@total=0; pass=0; fail=0; \
	for prog in $(PROGRAMS); do \
	    total=$$((total+1)); \
	    base=$$(basename $$prog); \
	    expected=$(EXAMPLES_DIR)/$$base.expected; \
	    tmp=$$(mktemp /tmp/pascal2c_test_XXXXXX); \
	    $$prog > "$$tmp" 2>&1; \
	    if [ ! -f "$$expected" ]; then \
	        echo "  SKIP  $$base  (no .expected file)"; \
	    elif diff -q "$$tmp" "$$expected" > /dev/null 2>&1; then \
	        echo "  PASS  $$base"; \
	        pass=$$((pass+1)); \
	    else \
	        echo "  FAIL  $$base"; \
	        echo "  --- expected ---"; \
	        cat "$$expected" | sed 's/^/    /'; \
	        echo "  --- got --------"; \
	        cat "$$tmp"      | sed 's/^/    /'; \
	        fail=$$((fail+1)); \
	    fi; \
	    rm -f "$$tmp"; \
	done; \
	echo ""; \
	echo "  Results: $$pass/$$total passed"; \
	echo ""; \
	[ $$fail -eq 0 ]

# ---- All-in-one --------------------------------------------------- #
# ---- Feature unit tests (tests/*.pas) ----------------------------- #
test-features: $(TARGET)
	@echo ""
	@echo "=== feature unit tests ==="
	@echo ""
	@mkdir -p c_src output
	@total=0; pass=0; fail=0; \
	for src in $(TESTS_DIR)/*.pas; do \
	    total=$$((total+1)); \
	    base=$$(basename $$src .pas); \
	    expected=$(TESTS_DIR)/$$base.expected; \
	    csrc=c_src/$$base.c; \
	    exe=output/$$base; \
	    ./$(TARGET) $$src $$csrc 2>/dev/null; \
	    $(CC) $(GENCFLAGS) $$csrc -o $$exe -lm 2>/dev/null; \
	    if [ ! -f "$$exe" ]; then \
	        echo "  FAIL  $$base (compile error)"; fail=$$((fail+1)); continue; \
	    fi; \
	    tmp=$$(mktemp /tmp/pascal2c_feat_XXXXXX); \
	    input_file=$(TESTS_DIR)/$$base.input; \
	    if [ -f "$$input_file" ]; then $$exe < "$$input_file" > "$$tmp" 2>&1; \
	    else $$exe > "$$tmp" 2>&1; fi; \
	    if [ ! -f "$$expected" ]; then \
	        echo "  SKIP  $$base  (no .expected file)"; \
	    elif diff -q "$$tmp" "$$expected" > /dev/null 2>&1; then \
	        echo "  PASS  $$base"; pass=$$((pass+1)); \
	    else \
	        echo "  FAIL  $$base"; \
	        echo "  --- expected ---"; \
	        cat "$$expected" | sed 's/^/    /'; \
	        echo "  --- got --------"; \
	        cat "$$tmp"      | sed 's/^/    /'; \
	        fail=$$((fail+1)); \
	    fi; \
	    rm -f "$$tmp"; \
	done; \
	echo ""; \
	echo "  Results: $$pass/$$total passed"; \
	echo ""; \
	[ $$fail -eq 0 ]

# ---- Build (but don't run) interactive demos in demos/ ----------- #
demos: $(TARGET)
	@echo ""
	@echo "=== building demos ==="
	@mkdir -p c_src output
	@for src in $(DEMOS_DIR)/*.pas; do \
	    base=$$(basename $$src .pas); \
	    csrc=c_src/$$base.c; \
	    exe=output/$$base; \
	    ./$(TARGET) $$src $$csrc 2>/dev/null; \
	    $(CC) $(GENCFLAGS) $$csrc -o $$exe -lm 2>/dev/null \
	        && echo "  BUILD OK  $$base" \
	        || echo "  BUILD FAIL  $$base"; \
	done
	@echo ""
	@echo "  Run demos manually from output/ (they need a live terminal)"
	@echo ""

# ---- Units test: compile unit + program together ----------------- #
UNITS_DIR = examples/units
test-units: $(TARGET)
	@echo ""
	@echo "=== unit tests ==="
	@echo ""
	@mkdir -p c_src output
	@total=0; pass=0; fail=0; \
	for prog in $(UNITS_DIR)/*.pas; do \
	    base=$$(basename $$prog .pas); \
	    head -1 $$prog | grep -qi '^unit' && continue; \
	    total=$$((total+1)); \
	    expected=$(UNITS_DIR)/$$base.expected; \
	    unit_src=$$(grep -i '^uses ' $$prog | head -1 | sed 's/[Uu][Ss][Ee][Ss] *//;s/;//' | tr ',' '\n' | tr -d ' ' | head -1); \
	    c_files="c_src/$$base.c"; \
	    if [ -n "$$unit_src" ]; then \
	        unit_lower=$$(echo "$$unit_src" | tr '[:upper:]' '[:lower:]'); \
	        ./$(TARGET) $(UNITS_DIR)/$$unit_lower.pas c_src/$$unit_lower.c 2>/dev/null; \
	        c_files="c_src/$$unit_lower.c $$c_files"; \
	    fi; \
	    ./$(TARGET) $$prog c_src/$$base.c 2>/dev/null; \
	    $(CC) $(GENCFLAGS) $$c_files -o output/$$base -lm 2>/dev/null; \
	    if [ ! -f output/$$base ]; then \
	        echo "  FAIL  $$base (compile error)"; fail=$$((fail+1)); continue; \
	    fi; \
	    tmp=$$(mktemp /tmp/pascal2c_test_XXXXXX); \
	    ./output/$$base > "$$tmp" 2>&1; \
	    if [ ! -f "$$expected" ]; then \
	        echo "  SKIP  $$base  (no .expected file)"; \
	    elif diff -q "$$tmp" "$$expected" > /dev/null 2>&1; then \
	        echo "  PASS  $$base"; pass=$$((pass+1)); \
	    else \
	        echo "  FAIL  $$base"; \
	        diff "$$expected" "$$tmp" | head -10 | sed 's/^/    /'; \
	        fail=$$((fail+1)); \
	    fi; \
	    rm -f "$$tmp"; \
	done; \
	echo ""; \
	echo "  Results: $$pass/$$total passed"; \
	echo ""; \
	[ $$fail -eq 0 ]

# ------------------------------------------------------------------ #
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR) $(C_SRC_DIR) $(OUTPUT_DIR)

distclean: clean
