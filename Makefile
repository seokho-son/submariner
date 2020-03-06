status ?= onetime
version ?= 1.14.2
logging ?= false
kubefed ?= false
deploytool ?= helm
armada ?= true
debug ?= false

TARGETS := $(shell ls scripts | grep -v dapper-image)

.dapper:
	@echo Downloading dapper
	@curl -sL https://releases.rancher.com/dapper/latest/dapper-`uname -s`-`uname -m` > .dapper.tmp
	@@chmod +x .dapper.tmp
	@./.dapper.tmp -v
	@mv .dapper.tmp .dapper

dapper-image: .dapper
	./.dapper -m bind dapper-image

shell:
	./.dapper -m bind -s

$(TARGETS): .dapper dapper-image vendor/modules.txt
	DAPPER_ENV="OPERATOR_IMAGE"  ./.dapper -m bind $@ -s $(status) -v $(version) -l $(logging) -k $(kubefed) -d $(deploytool) -a $(armada)

vendor/modules.txt: .dapper go.mod
	./.dapper -m bind vendor

.DEFAULT_GOAL := ci

.PHONY: $(TARGETS)

