-module(server).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).
-define(TIMEOUT,1000).
-define(GTIMEOUT,60000).
-define(P,100000).

sleep(N)-> receive after N -> ok end.
tostring(S)->tostring("~p",[S]).
tostring(S,L)-> lists:flatten(io_lib:format(S,L)).
reduce(F,Z,X)->
	{_A,B}=lists:mapfoldl(fun(Y,Sum)->{0,F(Y,Sum)} end,Z,X),
	B.

empty()->
	receive
		_ -> empty()
		after 0 -> ok
	end.

init()->init(?PUERTO).

init(Puerto)->
	io:format("Iniciando nodo ~p~n",[node()]),
	spawn(pstat,monitor,[]),
	register(dir,spawn(?MODULE,directory,[ordsets:new(),unlock])),
	register(game,spawn(?MODULE,games,[maps:new(),[]])),
	register(balance,spawn(pbalance,nodeList,[[]])),
	dispacher:init(Puerto).

%%%%%%%%%%%%%%%%%%MUTEX%%%%%%%%%%%%%%%%%%

dirunlock()->lists:foreach(fun(X)-> {dir,X}!{unlock} end,nodes()).

dirlock(L) -> dirlock(random:uniform(?P),L).

dirlock(N,L)->
	Pid=spawn(?MODULE,dirlock,[N,L,self()]),
	receive
		{lock,P,T} -> Pid!{lock,P,T};
		ok    -> ok;
		error -> waitunlock(L),dirlock(random:uniform(?P),L)
	end.

dirlock(N,_L,Pid)->
	empty(),
	lists:foreach(fun(X)-> {dir,X}!{lock,self(),N} end,nodes()),
	case cath(0,N) of
		ok    -> Pid!ok;
		error -> Pid!error
	end.
		
cath(M,N)->
	A = length(nodes()) < M + 1, %%length(nodes()) == M
	if A    -> ok;
	   true -> 
		receive 
			locked       -> cath(M+1,N);
			{lock,Pid,T} ->	if T<N  -> cath(M+1,N);
							   T==N ->
								Bool = node()<node(Pid),
								if Bool -> cath(M+1,N);
								   true -> Pid!locked,error
								end;				    
							   true -> Pid!locked,error
							end
		end
	end.

waitunlock(List)->
	receive 
		{unlock}          -> ok;
		{lock,P,_T}       -> P!locked,waitunlock(List);
		{ishere,P,Nombre} -> P!ordsets:is_element(Nombre,List),waitunlock(List)
	end.
	
%%%%%%%%%%DIRECTORIO DE NOMBRES%%%%%%%%%%

directory(List,State)->
	receive
		{lock,Pid,_N}            ->
			Pid!locked,directory(List,lock);
		{unlock}                 ->
			directory(List,unlock);
		{remove,_Pid,Nombre}     ->
			spawn(lists,foreach,[fun(V)-> {dir,V}!{removehere,self(),Nombre} end,nodes()]),
			directory(ordsets:del_element(Nombre,List),State);
		{show,Pid}               ->
			spawn(?MODULE,getuserlist,[Pid]),
			directory(List,State);
		{is,Pid,Nombre}          ->
			case ordsets:is_element(Nombre,List) of
				true   -> Pid!true;
				_False -> spawn(?MODULE,isavailiable,[Pid,Nombre])
			end,
			directory(List,State);
		{ishere,Pid,Nombre}      ->
			R=ordsets:is_element(Nombre,List),
			Pid!R,
			directory(List,State);
		{showhere,Pid}           ->
			Pid!List,
			directory(List,State);
		{removehere,_Pid,Nombre} ->
			directory(ordsets:del_element(Nombre,List),State);
		{add,Pid,Nombre}         ->
			directory(addelement({Pid,Nombre},List,State),unlock)
	end.

addelement({Pid,Nombre},List,State)->
	case ordsets:is_element(Nombre,List) of
		true   -> Pid!error,L=List;
		_False -> 
			case State of
				lock -> waitunlock(List);
				unlock -> ok
			end,
			dirlock(List),
			case isavailiable(Nombre) of
			   false -> Pid!error,L=List;
			   true  -> Pid!ok,L=ordsets:add_element(Nombre,List)					  
			end,
			dirunlock()
	end,
	L.

isavailiable(Pid,Nombre)->Pid!isavailiable(Nombre).
isavailiable(Nombre)->
	case nodes() of
		[] -> true;                                                        
		_L -> lists:all(fun(Node)->{dir,Node}!{ishere,self(),Nombre},receive true->false;false->true after ?TIMEOUT -> false end end,nodes())
	end.

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

%%%%%%%%%%DIRECTORIO DE JUEGOS%%%%%%%%%%%

games(List,Lid)->
	receive
		{new,Gid}        ->
			games(List,[Gid|Lid]);
		{free,Gid}       ->
			games(List,lists:delete(Gid,Lid));
		{add,Pid,User}             ->
			Gid=getNextid(Lid),
			Pgm=spawn(?MODULE,play,[Gid,User,[]]),
			L=maps:put(Gid,{Pgm,User,ordsets:new()},List),
			lists:foreach(fun(X)-> {game,X}!{new,Gid} end,nodes()),
			Pid!{ok,Gid},
			games(L,[Gid|Lid]);
		{con,Pid,Gid,User}         ->
			case maps:find(Gid,List) of
				{ok,{_,User,_}} -> 
					L = List,
					Pid!error;
				{ok,{P1,N1,L1}} ->
					L = maps:put(Gid,{P1,N1,User,L1},maps:remove(Gid,List)),
					P1!{new,User},
					Pid!ok;
				_Error          ->
					L=List,
					Pid!error
			end,
			games(L,Lid);
		{obs,Pid,Gid,User}         ->
			games(addObs(Pid,Gid,User,List),Lid);
		{removeobs,_Pid,Gid,User}  ->
			games(removeObs(Gid,User,List),Lid);
		{removeuser,User}          ->
			games(removeuser(User,List),Lid);
		{removeall,User}           ->
			spawn(lists,foreach,[fun(X)-> {game,X}!{removeuser,User} end,[node()|nodes()]]),
			games(List,Lid);
		{show,Pid}                 ->
			spawn(?MODULE,showall,[Pid]),
			games(List,Lid);
		{showhere,Pid}             ->
			Pid!maps:to_list(List),
			games(List,Lid);
		{remove,_Pid,Gid}          ->
			lists:foreach(fun(X)-> {game,X}!{free,Gid} end,nodes()),
			games(maps:remove(Gid,List),lists:delete(Gid,Lid));
		{is,Pid,Gid}               ->
			L = List,
			case maps:find(Gid,List) of
				{ok,_} -> Pid!true;
				_Error -> Pid!false
			end,
			games(L,Lid);
		{mov,Pid,User,Gid,Lugar}   ->
			L = List,
			case maps:find(Gid,List) of
				{ok,{P1,User,_N2,_L1}} ->
					P1!{mov,Pid,User,Lugar};
				{ok,{P1,_N1,User,_L1}} ->
					P1!{mov,Pid,User,Lugar};
				_Error                 ->
					Pid!error
			end,
		games(L,Lid)
	end.
	
getNextid(Lid)->
	case Lid of
		[] -> "1";
		_L -> tostring(lists:min(lists:filter(fun(N)-> not lists:member(tostring(N),Lid) end,lists:seq(1,length(Lid)+1))))
	end.

removeuser(User,List)->
	L=lists:map(fun(X)-> isUser(X,User) end,maps:to_list(List)),
	lists:foreach(fun(X)-> game!{remove,self(),X} end,lists:append(L)),
	List.

isUser(C,User)->
	case C of
		{Gid,{_,User,_}}   -> [Gid];
		{Gid,{_,_,User,_}} -> [Gid];
		{Gid,{_,User,_,_}} -> [Gid];
		_Otherwise         -> []
	end.

getNode(Gid,Pid)->
	Lm=lists:map(fun(X)-> {game,X}!{is,self(),Gid},receive true->[X];false->[] end end,[node()|nodes()]),
	case lists:append(Lm) of
		[]     -> Pid!{nd,error};
		[H|_T] -> Pid!{nd,H}
	end.

showall(Pid)->
	Lm = lists:map(fun(V) -> {game,V}!{showhere,self()},receive X -> X after ?TIMEOUT -> [] end end,[node()|nodes()]),
	Ls = lists:sort(lists:append(Lm)),
	Pid!{game,Ls}.

addObs(Pid,Gid,User,List)->
	case maps:find(Gid,List) of
				{ok,{_,User,_}} ->
					L=List,
					Pid!error;
				{ok,{_,_,User,_}} ->
					L=List,
					Pid!error;
				{ok,{_,User,_,_}} ->
					L=List,
					Pid!error;
				{ok,{P1,N1,L1}}    ->
					L = maps:put(Gid,{P1,N1,ordsets:add_element(User,L1)},maps:remove(Gid,List)),
					P1!{obs,User},
					Pid!ok;
				{ok,{P1,N1,N2,L1}} ->
					L = maps:put(Gid,{P1,N1,N2,ordsets:add_element(User,L1)},maps:remove(Gid,List)),
					P1!{obs,User},
					Pid!ok;
				_Error             ->
					L=List,
					Pid!error
	end,
	L.

removeObs(Gid,User,List)->
	case maps:find(Gid,List) of
			{ok,{P1,N1,L1}}    ->
				P1!{robs,User},
				maps:put(Gid,{P1,N1,ordsets:del_element(User,L1)},maps:remove(Gid,List));
			{ok,{P1,N1,N2,L1}} ->
				P1!{robs,User},
				maps:put(Gid,{P1,N1,N2,ordsets:del_element(User,L1)},maps:remove(Gid,List));
			_Error             ->
				List
	end.

%%%%%%%%%%%%%%%%%Partida%%%%%%%%%%%%%%%%%

play(Gid,PidUser,List)->
	empty(),
	receive
		{obs,Obs}       ->
			play(Gid,PidUser,[Obs|List]);
		{robs,Obs}      ->
			play(Gid,PidUser,lists:delete(Obs,List));
		{new,PidPlayer} ->
			lists:foreach(fun(P)-> P!{msg,"Inicia "++Gid} end,[PidUser|[PidPlayer|List]]),
			play(Gid,PidUser,PidPlayer,List,[0,0,0,0,0,0,0,0,0],0)
	end.

play(Gid,Player1,Player2,List,Game,Turno)->
	T=Turno rem 2,
	case T of
		0 -> C=Player1,D=Player2;
		1 -> C=Player2,D=Player1
	end,
	Current=C,
	Next=D,
	receive 
		{obs,Obs}                  ->
			play(Gid,Player1,Player2,[Obs|List],Game,Turno);
		{robs,Obs}                 ->
			play(Gid,Player1,Player2,lists:delete(Obs,List),Game,Turno);
		{mov,Pid,Next,_Lugar}      ->
			Pid!error,
			play(Gid,Player1,Player2,List,Game,Turno);
		{mov,Pid,Current,Lugar}    ->
			case isok(Game,Lugar,T+1) of
				{ok,Ngame}    ->
					Pid!ok,
					lists:foreach(fun(P)-> P!{msg,Gid++" "++tostring(Ngame)} end,[Player1|[Player2|List]]),
					play(Gid,Player1,Player2,List,Ngame,Turno+1);
				error         ->
					Pid!error,
					play(Gid,Player1,Player2,List,Game,Turno);
				{win,Ngame}   ->
					Pid!ok,
					game!{remove,Gid},
					lists:foreach(fun(P)-> P!{msg,Gid++tostring(Ngame)},P!{msg,Gid++" fin"} end,List),
					Current!{msg,"Ganaste! "++Gid++" "++tostring(Ngame)},
					Next!{ok,"Perdiste:( "++Gid++" "++tostring(Ngame)},
					game!{remove,self(),self()};
				{draw,Ngame}  ->
					Pid!ok,
					game!{remove,Gid},
					lists:foreach(fun(P)-> P!{msg,Gid++tostring(Ngame)},P!{msg,Gid++" fin"} end,List),
					Current!{msg,"Empate en "++Gid++" "++tostring(Ngame)},
					Next!{msg,"Empate en "++Gid++" "++tostring(Ngame)},
					game!{remove,self(),self()}
			end
		after ?GTIMEOUT ->
			Current!{msg,"Se te acabo el tiempo "++Gid++" "++tostring(Game)},
			Next!{msg,"Ganaste por default  "++Gid++" "++tostring(Game)},
			lists:foreach(fun(P)-> P!{msg,Gid++tostring(Game)},P!{msg,Gid++" fin por timeout"} end,List)
	end.

isok(Game,Lugar,N)->
	Bool=lists:nth(Lugar,Game)==0,
	if Bool ->
		Ngame=change(Lugar,Game,N),
		{isover(Ngame,N),Ngame};
	   true -> error
	end.

change(N,Game,E)->
	lists:sublist(Game,1,N-1)++[E]++lists:sublist(Game,N+1,length(Game)).

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
			case lists:foldl(fun(X,Mul) -> X*Mul end,1,List) of
				0     -> ok;
				_More -> draw
			end
	end.
