-module(pcomando).
-compile(export_all).
-define(TIMEOUT,10000).
-import(server,[tostring/1,tostring/2,getNode/1,getName/1,getAtom/1]).

reverser(S)->reverser(S,[]).
reverser([H|T],L)->reverser(T,[H|L]);
reverser([],SS)->SS.

reverse(Psocket)->
  io:format("En pcomando en ~p~n",[node()]),
  receive
    Msg ->
      io:format("Llego ~p~n",[Msg]),
      Nmsg=reverser(Msg),
      Psocket!Nmsg
  end,
  reverse(Psocket).

inbox() -> receive X -> X end.

%%Las partidas se llavaran a cabo en un unico pcomando(tener en cuenta que cada cliente tendra su propio pcomando y sera necesario cerrar uno).
comand(User)->
	Atom=getAtom(tostring(User)++"_"++tostring(node())),
	register(Atom,self()),
	comand(User,Atom).
	
comand(User,Atom)->
	case string:tokens(inbox()," ") of
		["LSG"]      ->%%Lista los juegos disponibles
			At=getAtom(tostring(Atom)++"_"++tostring(self())++"LSG"),
			Pid=spawn(?MODULE,sendit,[User,At]),
			register(At,Pid),
			wait!{all,{At,node()}},
			comand(User,Atom);
		["LBS"]      ->%%Observa un juego,cierra el pcomando actual
			At=getAtom(tostring(Atom)++"_"++tostring(self())++"LBS"),
			Pid=spawn(?MODULE,sendit,[User,At]),
			register(At,Pid),
			game!{all,{At,node()}},
			comand(User,Atom)
		%~ ["NEW"]      ->%%Crea un nuevo juego y espera
			%~ wait!{add,tostring(Atom)++"_"++(getName(User)++"_"++getNode(User))};
			%~ %%Esperar a que alguien se conecte
		%~ ["OBS"]      ->%%Observa un juego,cierra el pcomando actual
		%~ ["BYE"]      ->%%Cierrra la conexion
		%~ ["ACC"]      ->%%Acepta un juego
		%~ ["PLA"]      ->%%Realiza una jugada en un juego(En otra funcion) 
		%~ ["LEA"]      ->%%Abandona una partida que esta obserando(En otra funcion)			
	end.

sendit(User,Atom)->
	receive
		X -> User!X
		after ?TIMEOUT -> ok
	end,
	unregister(Atom).
