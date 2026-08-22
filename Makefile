# Build the paper locally. `make` builds both versions; see also
# .github/workflows/build-paper.yml, which runs the same two latexmk builds.

SECTIONS := $(wildcard paper/sections/*.tex)
FIGURES  := $(wildcard figures/*.png)
LATEXMK  := latexmk -pdf -interaction=nonstopmode

.PHONY: all paper tas clean

all: paper tas

paper: paper/impurity-importance.pdf
tas: paper/tas/impurity-importance-tas.pdf

paper/impurity-importance.pdf: paper/impurity-importance.tex $(SECTIONS) paper/bibliography.bib $(FIGURES)
	cd paper && $(LATEXMK) impurity-importance.tex

paper/tas/impurity-importance-tas.pdf: paper/tas/impurity-importance-tas.tex $(SECTIONS) paper/bibliography.bib paper/tas/agsm.bst $(FIGURES)
	cd paper/tas && $(LATEXMK) impurity-importance-tas.tex

clean:
	cd paper && latexmk -C impurity-importance.tex
	cd paper/tas && latexmk -C impurity-importance-tas.tex
