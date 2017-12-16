CP          := cp
CHMOD       := chmod +x
BIN         := bin
TARGET_DIRS := $(wildcard *Porn)
PRINTF      := printf

install:
	@for dir in $(TARGET_DIRS);do \
		$(CP) $(BIN)/clean.sh $$dir ; \
		$(CP) $(BIN)/link.sh $$dir ; \
		$(CP) $(BIN)/sync.sh $$dir ; \
		$(CP) $(BIN)/view.sh $$dir ; \
		$(CHMOD) $$dir/clean.sh ; \
		$(CHMOD) $$dir/link.sh ; \
		$(CHMOD) $$dir/sync.sh ; \
		$(CHMOD) $$dir/view.sh ; \
	done
	@$(CP) $(BIN)/sfwporn.sh .
	@$(CHMOD) sfwporn.sh
	@$(CP) $(BIN)/topview.sh .
	@$(CHMOD) topview.sh
