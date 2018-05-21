all: clean compile clean

compile:
	@echo "Compilando"
	@erl -compile dispacher.erl
	@erl -compile pstat.erl
	@erl -compile pcomando.erl
	@erl -compile pbalance.erl
	@erl -compile client.erl	
	@erl -compile psocket.erl
	@erl -compile server.erl

clean:
	@echo "Preparando escritorio"
	@rm -f *.bea? *.dump

remove:
	@echo "Borrando Archivos"
	@sudo rm -f *.bea? *.dump
