
DINCL = -I. -I./deps -I./submodules

SOURCES_deps = $(shell find -L deps/         -type f -name '*.d')
SOURCES_subm = $(shell find -L submodules/   -type f -name '*.d')
EXECS_SRC    = $(shell find -L . -maxdepth 1 -type f -name '*.d')

DCMP  = dmd -debug -color -w -g -wi ${DINCL} -boundscheck=on
DLD   = dmd -debug -color -w -g -wi


# Dlang compiler/linker out option
DOUT      = -of=

strip_bin = true

ifeq ($(BUILD),release)   
	DCMP  = ldc2 -O3 -dw -release -w -boundscheck=off ${DINCL} -fvisibility=hidden

	DLD	  = ldc2 -O3 -dw -release -w \
		-link-defaultlib-shared=false \
		-L-l:libphobos2-ldc.a -L-l:libdruntime-ldc.a -L-l:libz.a

  	# Remove all symbol and relocation information
	strip_bin = strip --strip-all

endif

############################################################
.PHONY: clean release all

EXECS_OBJ := $(patsubst ./%.d,o/%.o,$(EXECS_SRC))
EXECS_BIN := $(patsubst o/%.o,bin/%.bin,$(EXECS_OBJ))

SOURCES   := $(SOURCES_subm) $(SOURCES_deps)
OBJECTS   := $(patsubst %.d,o/%.o,$(SOURCES))

# make dev version
all: $(EXECS_BIN)
	@echo
	@echo "\033[1;36mBuild complite \033[0m"


$(EXECS_OBJ) : o/%.o : ./%.d
	${DCMP} -J. -c $< ${DOUT}$@



$(EXECS_BIN): bin/%.bin : o/%.o $(OBJECTS)
	@echo ""
	${DLD} -w $< ./deps/liblua.a $(OBJECTS) ${DOUT}$@
	$(strip_bin) $@
	@echo ""

$(OBJECTS) : o/%.o : %.d
	${DCMP} -J. -c $< ${DOUT}$@

# make release version
release:
	make "BUILD=release" -j`nproc`

clean:
	find o/ -type f -name '*.o' -delete
	rm -f bin/*.bin bin/*.a


test:
	@/bin/bash $(PWD)/tests.sh $(PWD)/submodules " -I. -I../deps -w -debug"
	@/bin/bash $(PWD)/tests.sh $(PWD)/deps " -w -debug"

test_release:
	#@/bin/bash $(PWD)/tests.sh $(PWD)/submodules " -I. -I../deps -w -release --force"
	@/bin/bash $(PWD)/tests.sh $(PWD)/deps " -w -release --force"

test_fast:
	cd deps && rdmd -unittest -main --force  serft/package

