-module(server).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).
-define(TIMEOUT,1000).
-define(P,1000000).

tostring(S)->tostring(S,[]).
tostring(S,L)-> lists:flatten(io_lib:format(S,L)).

init(Puerto)->
	io:format("Iniciando nodo ~p~n",[node()]),
	spawn(pstat,monitor,[]),
	Pdir=spawn(?MODULE,directory,[ordsets:new()]),
	Pbal=spawn(pbalance,nodeList,[[]]),
	register(dir,Pdir),
	register(balance,Pbal),
	dispacher:init(Puerto).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%Mutex%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dirlock() -> dirlock(random:uniform(?P)).

dirunlock()->lists:foreach(fun(X)-> {dir,X}!unlock end,nodes()).

dirlock(N)->
	Pid=spawn(?MODULE,dirlock,[N,self()]),
	receive
		{lock,P,T} -> Pid!{lock,P,T};
		ok    -> ok;
		error -> waitunlock(),dirlock(max(random:uniform(?P),N))%%con max hay mayor probabilidad mientras mas tiempo pasa
	end.

waitunlock()->
	receive 
		unlock     -> ok;
		{lock,P,T} -> P!locked,waitunlock()
	end.

dirlock(N,Pid)->
	lists:foreach(fun(X)-> {dir,X}!{lock,self(),N} end,nodes()),
	case cath(0,N) of
		ok    -> Pid!ok;
		error -> Pid!error
	end.
		
cath(M,N)->
	A = length(nodes()) < M + 1,
	if A      -> ok;
	   true   -> 
			receive 
				locked       -> cath(M+1,N);
				{lock,Pid,T} ->	if T<N  -> 
										cath(M+1,N);
								   true ->
										Pid!locked,
										error
								end
			end
	end.
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%DIRECTORIO DE NOMBRES%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%Formato de comunicacion%%%%

%~ {add,self(),Nombre}    -> Agrega el nombre(responde ok o error).
%~ {remove,self(),Nombre} -> Borra el nombre del servidor(no responde).
%~ {show,self(),Nombre}   -> Muestra todos los nombres del servidor(responde con una lista de nombres).
%~ {is,Pid,Nombre}        -> Verifica si el nombre ya esta en uso(responde con true o false).

directory(List)->%%Problema concurrencia(Si dos nodos agregan el mismo nombre al mismo tiempo(Ver ejercicio 6 de la practica de erlang, tiene locks)).
	receive
		{lock,Pid,_N} ->
			L=List,
			Pid!locked,
			waitunlock(),
		{remove,_Pid,Nombre}  ->
			L=ordsets:del_element(Nombre,List),
			spawn(lists,foreach,[fun(V)-> {dir,V}!{removehere,self(),Nombre} end,nodes()]);
		{show,Pid}            ->
			L=List,
			spawn(?MODULE,getuserlist,[Pid]);
		{is,Pid,Nombre}       ->
			L=List,
			case ordsets:is_element(Nombre,List) of
				true   -> Pid!true;
				_False -> spawn(?MODULE,isavailiable,[Pid,Nombre])
			end;
		{ishere,Pid,Nombre}   ->
			L=List,
			R=ordsets:is_element(Nombre,List),
			Pid!R;
		{showhere,Pid}        ->
			L=List,
			Pid!L;
		{removehere,_Pid,Nombre} ->
			L=ordsets:del_element(Nombre,List);
		{add,Pid,Nombre}     ->
			case ordsets:is_element(Nombre,List) of
				true   -> 
					L=List,Pid!error;
				_False -> 
					dirlock(),%%Duerme hasta que pueda escribir
					case isavailiable(Nombre) of
					   false -> L=List,Pid!error;
					   true  -> L=lists:add_element(Nombre,List),Pid!ok					  
					end,
					dirunlock()
			end
	end,
	directory(L).

isavailiable(Nombre)->
	lists:any(fun(Node)->{dir,Node}!{ishere,self(),Nombre},receive true->true;false->false after ?TIMEOUT -> false end end,nodes()).

isavailiable(Pid,Nombre)->
	R=lists:any(fun(Node)->{dir,Node}!{ishere,self(),Nombre},receive true->true;false->false after ?TIMEOUT -> false end end,nodes()),
	Pid!R.

reduce(F,Z,X)->
	{_A,B}=lists:mapfoldl(fun(Y,Sum)->{0,F(Y,Sum)} end,Z,X),
	B.

getuserlist(Pid)->
	Lw = lists:map(fun(Node)->spawn(Node,server,getuserlistaux,[self()]),
	                          receive {lu,X} -> X after ?TIMEOUT -> ordsets:new() end end,
	                          [node()|nodes()]),
	La = reduce(fun(A,B) -> ordsets:union(A,B) end,ordsets:new(),Lw),
	Ls = lists:sort(La),
	Pid!Ls.

getuserlistaux(Pid)->
	dir!{showhere,self()},
	receive X -> Pid!{lu,X} end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%DIRECTORIO DE JUEGOS%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%Formato de comunicacion%%%%
%~ {add,self(),Piduser}               -> 
%~ {con,self(),Gid,Piduser}           -> 
%~ {obs,self(),Piduser}               -> 
%~ {removeobs,self(),Gid,Piduser}     -> 
%~ {removeplayes,self(),Gid,Piduser}  ->
%~ {show,self()}                      ->

%%Existe la funcion play(Jug1,Jug2,[]) o play({Jug1,Cid},[]).

getNextid()->1.

games(List)->%%Problamas de concurrencia
	receive%%Nextid unica en todos los nodos!!!!!
		{add,Pid,User}->%%Agrega una partida en el nodo
			Pgm=spawn(?MODULE,play,[{User,Pid},[]]),%%Creo la partida
			L=maps:put(getNextid(),{Pgm,User,ordsets:new()},List);%%La almaceno
		{con,Pid,Gid,User}->%%Conecta un usuario a una partida
			case maps:find(Gid,List) of
				{ok,{P1,N1,L1}} ->
					L = maps:put(Gid,{P1,N1,User,L1},maps:remove(Gid,List)),
					P1!{new,User},
					Pid!ok;
				_Error ->
					L=List,
					Pid!error
			end;
		{obs,Pid,Gid,User}->%%Agrega observador a un juego
			L = addObs(Pid,Gid,User,List);
		{removeobs,Pid,Gid,User}->%%Saca un observador del juego
			L = removeObs(Pid,Gid,User,List);
		{removeplayer,Pid,Gid,User} ->%%Borra un jugador(si debe)
			L = leavePlayer(Pid,Gid,User,List);
		{showhere,Pid}->%%Muestra las partidas internas
			Pid!maps:to_list(List),
			L = List;
		{show,Pid}->
			L = List,
			spawn(?MODULE,showall,[Pid])
	end,
	games(L).

showall(Pid)->
	Lm = lists:map(fun(V) -> {game,V}!{showhere,self()},receive X -> X after ?TIMEOUT -> [] end end,[node()|nodes()]),
	Ls = lists:sort(lists:append(Lm)),
	Pid!Ls.

addObs(Pid,Gid,User,List)->
	case maps:find(Gid,List) of
				{ok,{P1,N1,L1}} ->
					L = maps:put(Gid,{P1,N1,ordsets:add_element(User,L1)},maps:remove(Gid,List)),
					P1!{obs,User},
					Pid!ok;
				{ok,{P1,N1,N2,L1}} ->
					L = maps:put(Gid,{P1,N1,N2,ordsets:add_element(User,L1)},maps:remove(Gid,List)),
					P1!{obs,User},
					Pid!ok;
				_Error ->
					L=List,
					Pid!error
	end,
	L.

removeObs(Pid,Gid,User,List)->
	case maps:find(Gid,List) of
			{ok,{P1,N1,L1}} ->
				L = maps:put(Gid,{P1,N1,ordsets:del_element(User,L1)},maps:remove(Gid,List)),
				P1!{obs,User},
				Pid!ok;
			{ok,{P1,N1,N2,L1}} ->
				L = maps:put(Gid,{P1,N1,N2,ordsets:del_element(User,L1)},maps:remove(Gid,List)),
				P1!{obs,User},
				Pid!ok;
			_Error ->
				L=List,
				Pid!error
	end,
	L.

leavePlayer(Pid,Gid,User,List)->
	case maps:find(Gid,List) of
		{ok,{_P1,User,_L1}}->
			L=maps:remove(Gid,List),
			Pid!ok;
		{ok,{_P1,User,_N1,_L1}}->
			L=maps:remove(Gid,List),
			Pid!ok;
		{ok,{_P1,_N1,User,_L1}}->
			L=maps:remove(Gid,List),
			Pid!ok;
		_Error              ->
			L=List,
			Pid!error
	end,
	L.
