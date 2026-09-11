# Build the paper locally. `make` builds both versions; see also
# .github/workflows/build-paper.yml, which runs the same two latexmk builds.

SECTIONS := $(wildcard paper/sections/*.tex)
FIGURES  := $(wildcard figures/*.png)
LATEXMK  := latexmk -pdf -interaction=nonstopmode

.PHONY: all paper tas tas-anon tas-title submission clean

all: paper tas

paper: paper/impurity-importance.pdf
tas: paper/tas/impurity-importance-tas.pdf

# The two files TAS actually takes: an anonymized main document (built from
# the same source with \anon predefined to 0, under its own jobname so the
# full build's aux files are untouched) and a separate title page.
tas-anon:  paper/tas/impurity-importance-tas-anon.pdf
tas-title: paper/tas/title-page.pdf
submission: tas-anon tas-title supplement
	cp paper/tas/impurity-importance-tas-anon.pdf dist/main_document_anonymized.pdf
	cp paper/tas/title-page.pdf dist/title_page.pdf
	@ls -la dist

paper/impurity-importance.pdf: paper/impurity-importance.tex $(SECTIONS) paper/bibliography.bib $(FIGURES)
	cd paper && $(LATEXMK) impurity-importance.tex

paper/tas/impurity-importance-tas.pdf: paper/tas/impurity-importance-tas.tex $(SECTIONS) paper/bibliography.bib paper/tas/agsm.bst $(FIGURES)
	cd paper/tas && $(LATEXMK) impurity-importance-tas.tex

paper/tas/impurity-importance-tas-anon.pdf: paper/tas/impurity-importance-tas.tex $(SECTIONS) paper/bibliography.bib paper/tas/agsm.bst $(FIGURES)
	cd paper/tas && $(LATEXMK) -jobname=impurity-importance-tas-anon -usepretex='\def\anon{0}' impurity-importance-tas.tex

paper/tas/title-page.pdf: paper/tas/title-page.tex
	cd paper/tas && $(LATEXMK) title-page.tex

clean:
	cd paper && latexmk -C impurity-importance.tex
	cd paper/tas && latexmk -C impurity-importance-tas.tex
	cd paper/tas && latexmk -C -jobname=impurity-importance-tas-anon impurity-importance-tas.tex
	cd paper/tas && latexmk -C title-page.tex

# Supplementary-material archive for journal submission. Built from the
# committed tree with `git archive`, so it carries no revision history and no
# untracked scratch files. corpus/fulltext is left out on purpose: those are
# retrieved third-party papers, and T&F stores every supplementary file under a
# Creative Commons licence. corpus/manifest.csv plus analysis/fetch_corpus.py
# regenerate it. Pass FULLTEXT=1 to include it anyway.

# ScholarOne accepts only alphanumerics and underscores in upload names.
SUPP_NAME    := rf_impurity_supplement
SUPP_ZIP     := dist/$(SUPP_NAME).zip
SUPP_PATHS   := README.md analysis notebook figures \
                corpus/README.md corpus/abstracts corpus/manifest.csv \
                corpus/fingerprint_survivors.txt corpus/fetch_errors.log
ifdef FULLTEXT
SUPP_PATHS   += corpus/fulltext
endif

.PHONY: supplement

supplement: $(SUPP_ZIP)

$(SUPP_ZIP): $(shell git ls-files $(SUPP_PATHS))
	@git diff-index --quiet HEAD -- $(SUPP_PATHS) || \
	  echo "warning: uncommitted changes under the archived paths are NOT in the zip"
	@mkdir -p dist
	@# The archive goes to blinded review: refuse to build if any archived
	@# file names the author, the affiliation, or a home directory.
	@if git grep -l -i -E 'theil|archon|christian\.|/Users/|@archontech' HEAD -- $(SUPP_PATHS) | grep -v '^HEAD:corpus/abstracts/'; then \
	  echo "error: author-identifying strings in the files above; not building $@"; exit 1; fi
	git archive --format=zip -9 --prefix=$(SUPP_NAME)/ -o $@ HEAD -- $(SUPP_PATHS)
	@echo "wrote $@ ($$(du -h $@ | cut -f1), $$(unzip -Z1 $@ | wc -l | tr -d ' ') files)"
