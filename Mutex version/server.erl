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
	Pdir=spawn(?MODULE,directory,[ordsets:new(),unlock]),
	Pbal=spawn(pbalance,nodeList,[[]]),
	register(dir,Pdir),
	register(balance,Pbal),
	dispacher:init(Puerto).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%Mutex%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dirlock(L) -> dirlock(random:uniform(?P),L).

dirunlock()->lists:foreach(fun(X)-> {dir,X}!{unlock} end,nodes()).

dirlock(N,L)->
	Pid=spawn(?MODULE,dirlock,[N,L,self()]),
	receive
		{lock,P,T} -> Pid!{lock,P,T};
		ok    -> ok;
		error -> waitunlock(L),dirlock(random:uniform(?P),L)%%con max hay mayor probabilidad mientras mas tiempo pasa
	end.

waitunlock(List)->
	receive 
		unlock            -> ok;
		{lock,P,_T}       -> P!locked,waitunlock(List);
		{ishere,P,Nombre} -> P!ordsets:is_element(Nombre,List)
	end.

dirlock(N,_L,Pid)->
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
										io:format("Gane lock!~n"),
										cath(M+1,N);
								   true ->
										io:format("Perdi lock!~n"),
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

directory(List,State)->
	receive
		{lock,Pid,_N} ->
			io:format("Llego lock de ~p~n",[Pid]),
			Pid!locked,
			directory(List,lock);
		{unlock}->
			io:format("Llego unlcok~n"),
			directory(List,unlock);
		{remove,_Pid,Nombre}  ->
			spawn(lists,foreach,[fun(V)-> {dir,V}!{removehere,self(),Nombre} end,nodes()]),
			directory(ordsets:del_element(Nombre,List),State);
		{show,Pid}            ->
			spawn(?MODULE,getuserlist,[Pid]),
			directory(List,State);
		{is,Pid,Nombre}       ->
			io:format("Recibi un is~n"),
			case ordsets:is_element(Nombre,List) of
				true   -> Pid!true;
				_False -> spawn(?MODULE,isavailiable,[Pid,Nombre])
			end,
			directory(List,State);
		{ishere,Pid,Nombre}   ->
			R=ordsets:is_element(Nombre,List),
			Pid!R,
			directory(List,State);
		{showhere,Pid}        ->
			Pid!List,
			directory(List,State);
		{removehere,_Pid,Nombre} ->
			directory(ordsets:del_element(Nombre,List),State);
		{add,Pid,Nombre}     ->
			directory(addelement({Pid,Nombre},List,State),unlock)
	end.

addelement({Pid,Nombre},List,State)->
	io:format("En add ~p a ~p ~n",[Nombre,ordsets:to_list(List)]),
	case ordsets:is_element(Nombre,List) of
				true   -> 
					io:format("Descartando elemento~n"),Pid!error,L=List;
				_False -> 
					case State of
						lock -> io:format("Esperando~n"),waitunlock(List);
						unlock -> ok
					end,
					io:format("Estoy en unlcok~n"),
					dirlock(List),%%Duerme hasta que pueda escribir
					%~ receive after 10000-> ok end,
					io:format("Preguntando y escribiendo~n"),
					case isavailiable(Nombre) of
					   false -> io:format("No guarde~n"),Pid!error,L=List;
					   true  -> io:format("Si guarde~n"),Pid!ok,L=ordsets:add_element(Nombre,List)					  
					end,
					io:format("Liberando~n"),
					dirunlock()
	end,
	L.

isavailiable(Nombre)->
	case nodes() of
		[] -> true;                                                        %%Si esta en otro nodo, entonces no esta disponible(true->false)
		_L -> lists:all(fun(Node)->{dir,Node}!{ishere,self(),Nombre},receive true->false;false->true after ?TIMEOUT -> false end end,nodes())
	end.
	
isavailiable(Pid,Nombre)->
	case nodes() of
		[] -> R=true;
		_L -> R=lists:all(fun(Node)->{dir,Node}!{ishere,self(),Nombre},receive true->false;false->true after ?TIMEOUT -> false end end,nodes())
	end,
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
