include $(dir $(lastword $(MAKEFILE_LIST)))common.mk

VERSION := 0.6-$(shell date +%Y%m%d)

OBJS := const.o alloc.o util.o opt.o \
        libm.o cephes.o lapack.o conmin.o conmax.o nlopt.o
INCLUDES := alloc.h util.h opt.h wrap.h conmin.h conmax.h nlopt.h

CFLAGS += -std=gnu99 -Wall -Wextra -Wno-missing-field-initializers
DEFINES = -DQML_VERSION=$(VERSION) -DKXARCH=$(KXARCH) -DKXVER=$(KXVER)

all: build

build: qml.$(DLLEXT)

%.o: %.c $(INCLUDES)
	$(CC) $(FLAGS) \
	    $(CFLAGS) \
	    $(DEFINES) \
	    -I../include -c -o $@ $<

# Don't use -L../lib -lprob etc. to avoid unintentionally linking to possibly
# incompatible system libraries if the libraries we built are missing.
qml.$(DLLEXT): $(OBJS) qml.symlist qml.mapfile
	$(CC) $(FLAGS) $(LD_SHARED) -o $@ $(OBJS) \
	    ../lib/libprob.a ../lib/libconmax.a ../lib/libnlopt.a \
	    $(LDFLAGS) \
	    $(if $(BUILD_LAPACK),../lib/liblapack.a,$(LIBS_LAPACK)) \
	    $(if $(BUILD_BLAS),../lib/librefblas.a,$(LIBS_BLAS)) \
	    $(call ld_static,$(LIBS_FORTRAN)) \
	    -lm \
	    $(if $(WINDOWS),-lq) \
	    $(call ld_export,qml)

qml.symlist: $(OBJS)
	$(call nm_exports,$(OBJS)) | sed -n 's/^qml_/_&/p' >$@.tmp
	$(if $(and $(BUILD_BLAS),$(BUILD_LAPACK)),,echo _xerbla_ >>$@.tmp)
	mv $@.tmp $@

qml.mapfile: qml.symlist
	echo "{ global:"             >$@.tmp
	sed 's/^_/    /;s/$$/;/' $< >>$@.tmp
	echo "  local: *; };"       >>$@.tmp
	mv $@.tmp $@


ifneq ($(QHOME),)
# don't export QHOME because q below should get it from the general environment
install: build
	install qml.$(DLLEXT) '$(QHOME)'/$(KXARCH)/
	install qml.q         '$(QHOME)'/
	
uninstall:
	rm -f -- '$(QHOME)'/$(KXARCH)/qml.$(DLLEXT)
	rm -f -- '$(QHOME)'/qml.q
endif

# can override on make command-line
TEST_OPTS=
test: build
	q test.q -cd -s 16 $(TEST_OPTS) </dev/null

BENCH_OPTS=
bench: build
	q bench.q -cd $(BENCH_OPTS) </dev/null

.PHONY: clean_src clean_misc
clean_src:
clean_misc:
clean: clean_src clean_misc
	rm -f qml.so qml.dll qml.symlist qml.mapfile
	rm -f $(OBJS)


SRC = $(patsubst %.o,%.c,$(OBJS)) $(INCLUDES)

define rule_cp
$(1): $(2)
	cp -- $(2) $(1)
endef

define rule_clean_src
clean_src:
	rm -f -- $$(SRC)
endef

define copy_src
$(foreach src,$(SRC),$(eval $(call rule_cp,$(src),$(addprefix $(1)/,$(src)))))\
$(eval $(rule_clean_src))
endef
