-module(pcomando).
-compile(export_all).
-define(TIMEOUT,30000).

comand(Client,CId,Comand)->
	server:empty(),
	case Comand of
		{lsg}->
			game!{show,self()},
			receive 
				{game,L} -> 
					Lr=lists:sort(lists:map(fun(X)-> tr(X) end,L)),
					Client!{res,okid(CId)++lists:foldl(fun(X,S)-> X++" "++S end,"",Lr)}
				after ?TIMEOUT -> {res,errorid(CId)}
			end;
		{new}->
			game!{add,self(),Client},
			receive 
				{ok,Gid} -> 
					Client!{res,okid(CId)++Gid} 
				after ?TIMEOUT -> {res,errorid(CId)}
			end;
		{help}->
			Client!{res,okid(CId)++helpstring()};
		{obs,Game}->
			case getNode(Game) of
				error     -> 
					Client!{res,errorid(CId)++Game};
				{ok,Node} ->
					{game,Node}!{obs,self(),Game,Client},
					receive 
						ok    ->
							Client!{res,okid(CId)++Game};
						error ->
							Client!{res,errorid(CId)++Game}
						after ?TIMEOUT -> {res,errorid(CId)}
					end
			end;
		{leave,Game}->
			case getNode(Game) of
				error ->
					Client!{res,errorid(CId)++Game};
				{ok,Node} ->
					{game,Node}!{removeobs,self(),Game,Client},
					Client!{res,okid(CId)++Game}
			end;
		{acc,Game}->
			case getNode(Game) of
				error ->
					Client!{res,errorid(CId)++Game};
				{ok,Node} ->
					{game,Node}!{con,self(),Game,Client},
					receive
						ok    -> Client!{res,okid(CId)++Game};
						error -> Client!{res,errorid(CId)++Game}
						after ?TIMEOUT -> {res,errorid(CId)}
					end
			end;
		{pla,Game,Lugar}->
			case getNode(Game) of
				error ->
					Client!{res,errorid(CId)++Game};
				{ok,Node} ->
					{game,Node}!{mov,self(),Client,Game,Lugar},
					receive
						ok    -> Client!{res,okid(CId)++Game};
						error -> Client!{res,errorid(CId)++Game}
						after ?TIMEOUT -> {res,errorid(CId)}
					end
			end;
		{bye}->
			Client!close
	end.

helpstring()->"Comandos: LSG,NEW,ACC Id,PLA Id Lug,OBS Id,LEA Id,BYE ".
okid(Id)-> "OK "++Id++" ".
errorid(Id)->"ERROR "++Id++" ".
tr(Ele)->
	case Ele of
		{Gid,{_,_,_}}   -> Gid++" Esperando jugador";
		{Gid,{_,_,_,_}} -> Gid++" Jugando"
	end.

getNode(Gid)->
	spawn(server,getNode,[Gid,self()]),
	receive
		{nd,error} -> error;
		{nd,N}     -> {ok,N}
		after ?TIMEOUT -> error
	end.
	
