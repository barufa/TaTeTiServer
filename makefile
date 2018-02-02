all: clean compile parche

#Genera archivos *.bea#, falla
#Sobre todo si se utiliza erl -compile *.erl
compile:
	erl -compile dispacher.erl
	erl -compile pstat.erl
	erl -compile pcomando.erl
	erl -compile pbalance.erl
	erl -compile client.erl	
	erl -compile psocket.erl
	erl -compile server.erl

clean:
	rm -f *.bea? *.dump

parche:
	rm -f *.bea# *.dump

remove:
	sudo rm -f *.bea? *.dump
