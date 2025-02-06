# Ontology of Laboratory Animal Science (OLAS) Makefile
# Jie Zheng
#
# This Makefile is used to build artifacts for the Ontology of Laboratory Animal Science.
#

### Configuration
#
# prologue:
# <http://clarkgrubb.com/makefile-style-guide#toc2>

MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

### Definitions

SHELL := /bin/bash
OBO   := http://purl.obolibrary.org/obo
OLAS    := $(OBO)/OLAS_
TODAY := $(shell date +%Y-%m-%d)

### Directories
#
# This is a temporary place to put things.
build:
	mkdir -p $@


### ROBOT
#
# We use the latest official release version of ROBOT
build/robot.jar: | build
	curl -L -o $@ "https://github.com/ontodev/robot/releases/latest/download/robot.jar"

ROBOT := java -jar build/robot.jar

### Imports
#
# Use Ontofox to import various modules.
build/%_imports.owl: src/ontology/Ontofox_input/%_input.txt | build/robot.jar build
	curl -s -F file=@$< -o $@ https://ontofox.hegroup.org/service.php

# Use ROBOT to remove external java axioms
src/ontology/imports/PR_imports.owl: build/PR_imports.owl
	$(ROBOT) remove --input build/PR_imports.owl \
	--base-iri 'http://purl.obolibrary.org/obo/PR_' \
	--axioms external \
        --exclude-term 'http://www.genenames.org/cgi-bin/gene_symbol_report?hgnc_id=1884' \
        --exclude-term 'http://rgd.mcw.edu/rgdweb/report/gene/main.html?id=2332' \
        --exclude-term 'http://www.informatics.jax.org/marker/MGI:88388' \
        --exclude-term 'http://zfin.org/action/marker/view/ZDB-GENE-050517-20' \
        --exclude-term 'http://purl.obolibrary.org/obo/MOD_00046' \
        --exclude-term 'http://purl.obolibrary.org/obo/MOD_00160' \
        --exclude-term MOD:00693 \
        --exclude-term 'http://purl.obolibrary.org/obo/MOD_00696' \
        --exclude-term 'http://purl.obolibrary.org/obo/MOD_01148' \
	--preserve-structure false \
	--trim false \
	--output $@

src/ontology/imports/PR_imports.owl: build/PR_imports.owl
	$(ROBOT) remove --input build/PR_imports.owl \
	--base-iri 'http://purl.obolibrary.org/obo/PR_' \
	--base-iri 'http://purl.obolibrary.org/obo/MOD_' \
	--base-iri 'http://purl.obolibrary.org/obo/CHEBI_' \
	--base-iri 'http://purl.obolibrary.org/obo/SO_' \
	--base-iri 'http://www.genenames.org/cgi-bin/gene_symbol_report?hgnc_id=' \
        --base-iri 'http://rgd.mcw.edu/rgdweb/report/gene/main.html?id=' \
        --base-iri 'http://www.informatics.jax.org/marker/MGI:' \
        --base-iri 'http://zfin.org/action/marker/view/ZDB-GENE-' \
	--axioms external \
	--preserve-structure false \
	--trim false \
	--output $@


src/ontology/imports/RO_imports.owl: build/RO_imports.owl
	$(ROBOT) remove --input build/RO_imports.owl \
	--base-iri 'http://purl.obolibrary.org/obo/RO_' \
	--base-iri 'http://purl.obolibrary.org/obo/BFO_' \
	--axioms external \
	--preserve-structure false \
	--trim false \
	--output $@

src/ontology/imports/%_imports.owl: build/%_imports.owl
	$(ROBOT) remove --input build/$*_imports.owl \
	--base-iri 'http://purl.obolibrary.org/obo/$*_' \
	--axioms external \
	--preserve-structure false \
	--trim false \
	--output $@ 

IMPORT_FILES := $(wildcard src/ontology/imports/*_imports.owl)

.PHONY: imports
imports: $(IMPORT_FILES)

### Templates
#
src/ontology/modules/%.owl: src/ontology/templates/%.csv | build/robot.jar
	echo '' > $@
	$(ROBOT) merge \
	--input src/ontology/olas-edit.owl \
	template \
	--template $< \
	--prefix "OLAS: http://purl.obolibrary.org/obo/OLAS_" \
	--ontology-iri "http://purl.obolibrary.org/obo/olas/dev/$(notdir $@)" \
	--output $@

# Update all modules
MODULE_NAMES := olas_objectProp \
  lab_model

MODULE_FILES := $(foreach x,$(MODULE_NAMES),src/ontology/modules/$(x).owl)

.PHONY: modules
modules: $(MODULE_FILES)


### Build
#
# Here we create a standalone OWL file appropriate for release.
# This involves merging, reasoning, annotating,
# and removing any remaining import declarations.

build/olas-merged.owl: src/ontology/olas-edit.owl | build/robot.jar build
	$(ROBOT) merge \
	--input $< \
	annotate \
	--ontology-iri "$(OBO)/olas/olas-merged.owl" \
	--version-iri "$(OBO)/olas/releases/$(TODAY)/olas-merged.owl" \
	--annotation owl:versionInfo "$(TODAY)" \
	--output build/olas-merged.tmp.owl
	sed '/<owl:imports/d' build/olas-merged.tmp.owl > $@
	rm build/olas-merged.tmp.owl

olas.owl: build/olas-merged.owl
	$(ROBOT) reason \
	--input $< \
	--reasoner ELK \
	annotate \
	--ontology-iri "$(OBO)/olas.owl" \
	--version-iri "$(OBO)/olas/releases/$(TODAY)/olas.owl" \
	--annotation owl:versionInfo "$(TODAY)" \
	--output $@

olas-base.owl: olas.owl
	$(ROBOT) remove \
	--input $< \
 	--base-iri http://purl.obolibrary.org/obo/OLAS_ \
 	--axioms external \
 	--preserve-structure false \
	--trim false \
 	--output $@

robot_report.tsv: olas-base.owl
	$(ROBOT) report \
	--input $< \
        --fail-on none \
	--output $@

olas_terms.tsv: olas-base.owl
	$(ROBOT) query \
	--input $< \
        --query SPARQL/get_olas_terms.rq $@


### 
#
# Full build
.PHONY: all
all: olas.owl robot_report.tsv olas_terms.tsv

# Remove generated files
.PHONY: clean
clean:
	rm -rf build



