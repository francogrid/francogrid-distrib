repo ?= git://github.com/francogrid/sim.git
branch ?= master
d ?=
u ?= $(shell id -nu)
g ?= $(u)

dirpath := $(shell echo $(d) | grep -E '^/.*' || echo $(PWD)/$(d))
bindir := $(dirpath)/bin
etcdir := $(dirpath)/etc
NANT = $(strip $(shell which nant 2>/dev/null))

all: update build

init:
	@echo "### OpenSim sources tree initialization ###"
	@git remote add -f opensim $(repo)
	@git merge -s ours --no-commit opensim/$(branch)
	@git read-tree --prefix=sources -u opensim/$(branch)
	@git commit -m "Merge branch $(branch) of $(repo) in sources/ directory."

update:
	@if ! test -d "sources"; then make init; \
	else git pull -s subtree opensim $(branch); fi

prebuild:
	@if ! test -d "sources"; then make init; \
	else make clean > /dev/null; fi
	@cd sources; ./runprebuild.sh

build: prebuild
	@cd sources; ${NANT}

clean:
	@cd sources; ${NANT} clean;

archive:
	@if ! test -r "sources/bin/.version"; then \
		echo ".version file is missing, aborting..."; exit 1; \
	fi
	@rev=$(shell cat sources/bin/.version | awk '{print $$NF}'); \
	distrib=francogrid-$${rev}; zip=$${distrib}.zip; \
	if test -f "$${zip}"; then \
		echo "$${zip} already exists, aborting..."; exit 1; \
	fi; \
	rsync -a --exclude-from=.exclude sources/bin sources/*.txt tools/* etc $${distrib}/; \
	zip -r $${zip} $${distrib} && rm -rf $${distrib} && \
	echo "Archive created: $${zip}"

install: test-param-dir
	@if ! test -d "$(dirpath)"; then mkdir -p $(dirpath); fi
	@if ! test -w "$(dirpath)"; then \
		echo "Can't write to $(dirpath), permission denied."; exit 1; \
	fi
	@if ! test -d "$(etcdir)"; then mkdir $(etcdir); fi
	@cd sources; tar cf - bin | tar xf - -C $(dirpath)
	@tar cf - etc | tar xf - -C $(dirpath)
	@cp -a tools/* $(dirpath)/
ifneq ("$(u)", "$(shell id -nu)")
	@chown -R $(u):$(g) $(dirpath)/*
endif
	@echo "### INSTALLATION COMPLETE ###"
	@echo "installation path: $(dirpath)"
	@echo "user: $(u)"
	@echo "group: $(g)"

test-param-dir:
ifeq ($(d),)
	@echo "You must provide a destination: d=<path>"
	@exit 1
endif

