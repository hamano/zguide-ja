include meta.mk

#LATEX=platex
LATEX=uplatex
PANDOC=pandoc
#PANDOC=~/.cabal/bin/pandoc
PANDOC_OPT=--toc --toc-depth=3 --listings --chapters
DVIPDFMX=dvipdfmx
DVIPDFMX_OPT=-f uptex-hiragino

NAME=zguide-ja
TEMPLATE=template.tex

SRCS=macro.m4 meta.yaml preface.md chapter1.md chapter2.md chapter3.md chapter4.md postface.md
MD=$(NAME).md
TEX=$(NAME).tex
DVI=$(NAME).dvi
PDF=$(NAME).pdf
EPUB=$(NAME).epub
HTML=$(NAME).html

EXAMPLE_LANG=C
EXAMPLE_EXT=c
#EXAMPLE_LANG=Perl
#EXAMPLE_EXT=pl

# filter original text
ORIGINAL_FILTER=sed -e 's/^;.*//'
#ORIGINAL_FILTER=sed -e 's/^;\(.*\)/\1/'

%.dvi: %.tex
	$(LATEX) $<
	$(LATEX) $<

%.pdf: %.dvi
	$(DVIPDFMX) $(DVIPDFMX_OPT) $^

all: $(PDF)

clean:
	rm -rf *.log *.out *.aux *.toc $(MD) $(TEX) $(DVI) $(PDF) $(EPUB) $(HTML)

$(MD): $(SRCS)
	m4 -DEXAMPLE_LANG=$(EXAMPLE_LANG) -DEXAMPLE_EXT=$(EXAMPLE_EXT) $^ | ${ORIGINAL_FILTER} > $@

$(EPUB): $(MD)
	$(PANDOC) -o $@ $<

$(HTML): $(MD)
	$(PANDOC) -o $@ $<

$(TEX): $(MD) $(TEMPLATE)
	$(PANDOC) -f markdown -t latex $(PANDOC_OPT) -V pdf_title="$(PDF_TITLE)" -V pdf_subject="$(PDF_SUBJECT)" -V pdf_author="$(PDF_AUTHOR)"  -V pdf_keywords="$(PDF_KEYWORDS)" --template=$(TEMPLATE) $< | sed -e 's/\[htbp\]/\[H\]/g' > $@

$(DVI): $(TEX)

$(PDF): $(DVI)
