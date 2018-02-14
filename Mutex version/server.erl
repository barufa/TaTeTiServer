-module(server).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).
-define(TIMEOUT,1000).
-define(P,1000000).

tostring(S)->tostring("~p",[S]).
tostring(S,L)-> lists:flatten(io_lib:format(S,L)).

init(Puerto)->
	io:format("Iniciando nodo ~p~n",[node()]),
	spawn(pstat,monitor,[]),
	Pdir=spawn(?MODULE,directory,[ordsets:new(),unlock]),
	Pgam=spawn(?MODULE,games,[maps:new()]),
	Pbal=spawn(pbalance,nodeList,[[]]),
	register(game,Pgam),
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
		error -> waitunlock(L),dirlock(random:uniform(?P),L)
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
										cath(M+1,N);
								   T==N -> %%Si los numeros son iguales desempatan por el nombre del nodo
										Bool = node()<node(Pid),
										if Bool ->
											cath(M+1,N);
										   true ->
										    Pid!locked,
										    error
										end;								    
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
%~ {show,self()}          -> Muestra todos los nombres del servidor(responde con una lista de nombres).
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
	case ordsets:is_element(Nombre,List) of
				true   -> 
					Pid!error,L=List;
				_False -> 
					case State of
						lock -> waitunlock(List);
						unlock -> ok
					end,
					dirlock(List),%%Duerme hasta que pueda escribir
					case isavailiable(Nombre) of
					   false -> Pid!error,L=List;
					   true  -> Pid!ok,L=ordsets:add_element(Nombre,List)					  
					end,
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
	Pid!{dir,Ls}.

getuserlistaux(Pid)->
	dir!{showhere,self()},
	receive X -> Pid!{lu,X} end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%DIRECTORIO DE JUEGOS%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%Formato de comunicacion%%%%
%~ {add,self(),Piduser}               -> Crea una partida(responde con start cuando alguien se conecta)
%~ {con,self(),Gid,Piduser}           -> Se conecta a una partida(responde ok o error)
%~ {obs,self(),Gid,Piduser}           -> Observa una partida(responde ok o error)
%~ {removeobs,self(),Gid,Piduser}     -> Remueve a un observador de la partida(no responde)
%~ {remove,Gid}                       -> Borra una partida(no responde)
%~ {show,self()}                      -> Muestra una lista con todas la partidas(responde con una lista de partidas)
%~ {mov,self(),Gid,User,Game}         -> Realiza un cambio en la partida(responde con ok o error)

getNextid()->"1".%%Debe ser una string

games(List)->
	receive
		{add,Pid,User}->%%Agrega una partida en el nodo
			Gid=getNextid(),
			Pgm=spawn(?MODULE,play,[Gid,User,Pid,[]]),
			L=maps:put(Gid,{Pgm,User,ordsets:new()},List),
			Pid!{ok,Gid};
		{con,Pid,Gid,User}->%%Se conecta a una partida
			case maps:find(Gid,List) of
				{ok,{P1,N1,L1}} ->
					L = maps:put(Gid,{P1,N1,User,L1},maps:remove(Gid,List)),
					P1!{new,User},
					Pid!ok;
				_Error ->
					L=List,
					Pid!error
			end;
		{obs,Pid,Gid,User}->%%Agrega un observador a un juego
			L = addObs(Pid,Gid,User,List);
		{removeobs,_Pid,Gid,User}->%%Saca un observador del juego
			L = removeObs(Gid,User,List);
		{show,Pid}->%%Muestra todas la partidas
			L = List,
			spawn(?MODULE,showall,[Pid]);
		{showhere,Pid}->%%Muestra las partidas locales
			Pid!maps:to_list(List),
			L = List;
		{remove,_Pid,Gid}->%%Borra una partida
			L = maps:remove(Gid,List);
		{mov,Pid,User,Gid,Game}->
			L = List,
			case maps:find(Gid,List) of
				{ok,{P1,User,_N2,_L1}} ->
					P1!{mov,Pid,User,Game};
				{ok,{P1,_N1,User,_L1}} ->
					P1!{mov,Pid,User,Game};
				_Error               ->
					Pid!error
			end
	end,
	games(L).

showall(Pid)->
	Lm = lists:map(fun(V) -> {game,V}!{showhere,self()},receive X -> X after ?TIMEOUT -> [] end end,[node()|nodes()]),
	Ls = lists:sort(lists:append(Lm)),
	Pid!{game,Ls}.

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

removeObs(Gid,User,List)->
	case maps:find(Gid,List) of
			{ok,{P1,N1,L1}} ->
				P1!{robs,User},
				maps:put(Gid,{P1,N1,ordsets:del_element(User,L1)},maps:remove(Gid,List));
			{ok,{P1,N1,N2,L1}} ->
				P1!{robs,User},
				maps:put(Gid,{P1,N1,N2,ordsets:del_element(User,L1)},maps:remove(Gid,List));
			_Error ->
				List
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%PARTIDA%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

play(Gid,PidUser,PidPcomando,List)->
	receive
		{obs,Obs}    ->
			play(Gid,PidUser,PidPcomando,[Obs|List]);
		{robs,Obs}   ->
			play(Gid,PidUser,PidPcomando,lists:delete(Obs,List));
		{new,PidPlayer} ->
			PidPcomando!{start,Gid},
			lists:foreach(fun(P)-> P!{msg,"Inicia "++Gid} end,[PidUser|[PidPlayer|List]]),
			play(Gid,PidUser,PidPlayer,List,[0,0,0,0,0,0,0,0,0],1)
	end.

play(Gid,Player1,Player2,List,Game,Turno)->
	T=(Turno+1) rem 2,
	case T of
		0 -> C=Player1,D=Player2;
		1 -> C=Player2,D=Player1
	end,
	Current=C,
	Next=D,
	receive 
		{obs,Obs}    ->
			play(Gid,Player1,Player2,[Obs|List],Game,Turno);
		{robs,Obs}   ->
			play(Gid,Player1,Player2,lists:delete(Obs,List),Game,Turno);
		{mov,Pid,Next,_Lugar}->
			Pid!error;
		{mov,Pid,Current,Lugar}->%%Mejorar Mensajes de Server
			case isok(Game,Lugar,T+1) of
				{ok,Ngame} ->
					Pid!ok,
					lists:foreach(fun(P)-> P!{msg,Gid++tostring(Ngame)} end,List),
					play(Gid,Player1,Player2,List,Ngame,T+1);
				error ->
					Pid!error,
					play(Gid,Player1,Player2,List,Game,T);
				{win,Ngame}   ->
					Pid!ok,
					Current!{msg,"Ganaste! "++Gid++" "++tostring(Ngame)},
					Next!{ok,"Perdiste:( "++Gid++" "++tostring(Ngame)};
				{draw,Ngame}  ->
					Pid!ok,
					Current!{msg,"Empate en "++Gid++" "++tostring(Ngame)},
					Next!{ok,"Empate en "++Gid++" "++tostring(Ngame)}
			end
	end.

isok(Game,Lugar,N)->
	Bool=lists:nth(Lugar,Game)==0,
	if Bool->
			Ngame=change(Lugar,Game,N),
			isover(Ngame,N);
		true -> error
	end.

change(N,Game,E)->
	A=lists:sublist(Game,1,N-1),
	B=[E],
	C=lists:sublist(Game,N+1,length(Game)),
	A++B++C.

isover(Game,N)->
	case Game of
		[N,N,N,_,_,_,_,_,_] -> win;
		[_,_,_,N,N,N,_,_,_] -> win;
		[_,_,_,_,_,_,N,N,N] -> win;
		[N,_,_,N,_,_,N,_,_] -> win;
		[_,N,_,_,N,_,_,N,_] -> win;
		[_,_,N,_,_,N,_,_,N] -> win;
		[N,_,_,_,N,_,_,_,N] -> win;
		[_,_,N,_,N,_,N,_,_] -> win;
		List                ->
			case lists:foldl(fun(X,Mul) -> X+Mul end,1,List) of
				0     -> ok;
				_More -> draw
			end
	end.
