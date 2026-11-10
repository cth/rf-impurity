# Build the paper locally. `make` builds both versions; see also
# .github/workflows/build-paper.yml, which runs the same two latexmk builds.

SECTIONS := $(wildcard paper/sections/*.tex)
FIGURES  := $(wildcard figures/*.png)
LATEXMK  := latexmk -pdf -interaction=nonstopmode
TEXFILES := $(wildcard paper/*.tex paper/sections/*.tex paper/tas/*.tex paper/asa/*.tex)
MAXLEN   := 80

.PHONY: all paper tas tas-anon tas-title asa asa-anon asa-title submission clean check-lines wrap-lines

all: paper tas asa

paper: paper/impurity-importance.pdf
tas: paper/tas/impurity-importance-tas.pdf
asa: paper/asa/impurity-importance-asa.pdf

# The two files TAS actually takes: an anonymized main document (built from
# the same source with \anon predefined to 0, under its own jobname so the
# full build's aux files are untouched) and a separate title page.
tas-anon:  paper/tas/impurity-importance-tas-anon.pdf
tas-title: paper/tas/title-page.pdf
asa-anon:  paper/asa/impurity-importance-asa_anon.pdf
asa-title: paper/asa/title-page.pdf
submission: tas tas-anon tas-title asa asa-anon asa-title supplement
	cp paper/tas/impurity-importance-tas-anon.pdf dist/main_document_anonymized.pdf
	cp paper/tas/impurity-importance-tas.pdf dist/manuscript_with_author_details.pdf
	cp paper/tas/title-page.pdf dist/title_page.pdf
	cp paper/asa/impurity-importance-asa_anon.pdf dist/asa_main_document_anonymized.pdf
	cp paper/asa/impurity-importance-asa.pdf dist/asa_manuscript_with_author_details.pdf
	cp paper/asa/title-page.pdf dist/asa_title_page.pdf
	@ls -la dist

paper/impurity-importance.pdf: paper/impurity-importance.tex $(SECTIONS) paper/bibliography.bib $(FIGURES)
	cd paper && $(LATEXMK) impurity-importance.tex

paper/tas/impurity-importance-tas.pdf: paper/tas/impurity-importance-tas.tex $(SECTIONS) paper/bibliography.bib paper/tas/agsm.bst $(FIGURES)
	cd paper/tas && $(LATEXMK) impurity-importance-tas.tex

paper/tas/impurity-importance-tas-anon.pdf: paper/tas/impurity-importance-tas.tex $(SECTIONS) paper/bibliography.bib paper/tas/agsm.bst $(FIGURES)
	cd paper/tas && $(LATEXMK) -jobname=impurity-importance-tas-anon -usepretex='\def\anon{0}' impurity-importance-tas.tex

paper/tas/title-page.pdf: paper/tas/title-page.tex
	cd paper/tas && $(LATEXMK) title-page.tex

paper/asa/impurity-importance-asa.pdf: paper/asa/impurity-importance-asa.tex $(SECTIONS) paper/bibliography.bib paper/asa/agsm.bst $(FIGURES)
	cd paper/asa && $(LATEXMK) impurity-importance-asa.tex

paper/asa/impurity-importance-asa_anon.pdf: paper/asa/impurity-importance-asa.tex $(SECTIONS) paper/bibliography.bib paper/asa/agsm.bst $(FIGURES)
	cd paper/asa && $(LATEXMK) -jobname=impurity-importance-asa_anon -usepretex='\def\anon{0}' impurity-importance-asa.tex

paper/asa/title-page.pdf: paper/asa/title-page.tex
	cd paper/asa && $(LATEXMK) title-page.tex

clean:
	cd paper && latexmk -C impurity-importance.tex
	cd paper/tas && latexmk -C impurity-importance-tas.tex
	cd paper/tas && latexmk -C -jobname=impurity-importance-tas_anon impurity-importance-tas.tex
	cd paper/tas && latexmk -C title-page.tex
	cd paper/asa && latexmk -C impurity-importance-asa.tex
	cd paper/asa && latexmk -C -jobname=impurity-importance-asa_anon impurity-importance-asa.tex
	cd paper/asa && latexmk -C title-page.tex

# Fail if any .tex line exceeds $(MAXLEN) chars. Override with `make check-lines MAXLEN=100`.
check-lines:
	@awk -v max=$(MAXLEN) 'length > max {printf "%s:%d: %d chars (max %d)\n", FILENAME, FNR, length, max; bad=1} END {if (bad) {print "error: lines exceed " max " chars"; exit 1} else {print "ok: all tex lines <= " max " chars"}}' $(TEXFILES)

# Wrap long .tex lines at word boundaries so they fit in $(MAXLEN) chars.
# A single newline is whitespace in LaTeX, so this is semantics-preserving;
# comment lines keep their "% " prefix on continuations. Lines with no
# breakable space (e.g. pandoc \def\maxheight boilerplate) are reported,
# not wrapped. Run `make check-lines` afterwards to verify.
wrap-lines:
	@python3 tools/wrap_tex.py --maxlen $(MAXLEN) $(TEXFILES)

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
