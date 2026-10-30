# Build the PDF of the book. See pdf/README.md for details.
#
#   make pdf                  pdf/dist/react-native-new-architecture-book_rn-v<ver>_<commit>_<stamp>.pdf
#   make md                   only pdf/build/book.md (no PDF)
#   make pdf OUT=book.pdf     write to a fixed path
#   make pdf TOC_DEPTH=2      shorter table of contents
#   make pdf MERMAID=0        keep diagrams as code (faster)
#   make pdf MD2PDF=/path/to/markdown-to-pdf.sh
#   make clean                remove pdf/build and pdf/dist

UV        ?= uv
BUILD     := $(UV) run pdf/build_book.py
TOC_DEPTH ?= 3
MERMAID   ?= 1
OUT       ?=
MD2PDF    ?=

ARGS := --toc-depth $(TOC_DEPTH)
ifeq ($(MERMAID),0)
ARGS += --no-mermaid
endif
ifneq ($(OUT),)
ARGS += --out $(OUT)
endif
ifneq ($(MD2PDF),)
ARGS += --md2pdf $(MD2PDF)
endif

.DEFAULT_GOAL := help
.PHONY: help pdf md clean

help:
	@sed -n '1,9p' $(firstword $(MAKEFILE_LIST)) | sed 's/^# \{0,1\}//'

pdf:
	$(BUILD) $(ARGS)

md:
	$(BUILD) --md-only $(ARGS)

clean:
	rm -rf pdf/build pdf/dist
