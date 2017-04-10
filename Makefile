CMD := ./script/
DAT := data/
OBJ := obj/
PDF := pdf/

MAKEFLAGS += --no-print-directory   \
             --no-builtin-rules     \
             --no-builtin-variables


V ?= 1
ifeq ($(V),1)
  define cmd-print
    @echo '$(1)'
  endef
endif
ifneq ($(V),2)
  Q := @
endif


ifeq ($(filter clean $(OBJ)config.mk, $(MAKECMDGOALS)),)
  MODE := build
else
  ifneq ($(filter-out clean $(OBJ)config.mk, $(MAKECMDGOALS)),)
    MODE := mixed
  else
    MODE := config
  endif
endif

ifeq ($(MODE),mixed)

  %:
	$(call cmd-print,  MAKE    $(strip $@))
	+$(Q)$(MAKE) $@

  .NOTPARALLEL:

else


ifeq ($(MODE),build)
  -include $(OBJ).gen-params.txt
endif
ifneq ($(filter $(OBJ).gen-params.txt, $(MAKEFILE_LIST)),)
  PARAMS := $(shell cat $(OBJ)params.txt)
endif

BASE   := $(OBJ)throughput.csv
PLOTS  := $(patsubst %, $(PDF)throughput-%.pdf, $(PARAMS))



all: $(PLOTS)

view: $(PLOTS)
	$(call cmd-print,  VIEW    $(strip $(PLOTS)))
	$(Q)evince $^

clean:
	$(call cmd-print,  CLEAN)
	$(Q)rm -rf $(OBJ) $(PDF)


$(OBJ)throughput.csv: $(CMD)gencsv $(OBJ).extract | $(OBJ)
	$(call cmd-print,  CSV     $(strip $@))
	$(Q)$< $(OBJ)memaslap-2017* $@

$(OBJ).gen-params.txt: $(OBJ)params.txt | $(OBJ)
	$(call cmd-print,  FLAG    $(strip $@))
	$(Q)touch $@

$(OBJ)params.txt: $(CMD)gendats $(BASE) | $(OBJ)
	$(call cmd-print,  TXT     $(strip $@))
	$(Q)$^ > $@

$(PDF)%.pdf: $(CMD)genplots $(OBJ)%.dat | $(PDF)
	$(call cmd-print,  PLOT    $(strip $@))
	$(Q)$^ $@

$(OBJ)throughput-%.dat: $(CMD)gendats $(BASE) | $(OBJ)
	$(call cmd-print,  DAT     $(strip $@))
	$(Q)$^ $(patsubst $(OBJ)throughput-%.dat, %, $@) $@

$(OBJ)results.tgz: $(DAT)results.tgz | $(OBJ)
	$(call cmd-print,  CP      $(strip $@))
	$(Q)cp $< $@

$(OBJ).extract: $(OBJ)results.tgz | $(OBJ)
	$(call cmd-print,  TAR     $(strip $@))
	$(Q)cd $(if $(OBJ), $(OBJ), .) ; tar -xzf results.tgz
	$(Q)touch $@


$(OBJ) $(PDF):
	$(call cmd-print,  MKDIR   $(strip $@))
	$(Q)mkdir $@


.SECONDARY:

endif
