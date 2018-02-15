-module(pcomando).
-compile(export_all).

comand(Client,CId,Comand)->
	case Comand of
		{lsg}->
			game!{show,self()},
			receive {game,L} -> L end,
			Lr=lists:sort(lists:map(fun(X)-> tr(X) end,L)),
			Client!{res,okid(CId)++lists:foldl(fun(X,S)-> X++S end,"",Lr)};		
		{new}->
			game!{add,self(),Client},
			receive {ok,Gid} -> Gid end,
			Client!{res,okid(CId)++Gid};
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
					end
			end;
		{leave,Game}->
			{game,getNode(Game)}!{removeobs,self(),Game,Client};
		{acc,Game}->
			{game,getNode(Game)}!{con,self(),Game,Client},
			receive
				ok    -> Client!{res,okid(CId)++Game};
				error -> Client!{res,errorid(CId)++Game}
			end;
		{pla,Game,Lugar}->
			{game,getNode(Game)}!{mov,self(),Client,Game,Lugar},
			receive
				ok    -> Client!{res,okid(CId)++Game};
				error -> Client!{res,errorid(CId)++Game}
			end;
		{bye}->
			Client!close
	end.

helpstring()->"Seguro hay un deadlock, desisti~n".
okid(Id)-> "OK "++Id++" ".
errorid(Id)->"ERROR "++Id++" ".
tr(Ele)->
	case Ele of
		{Gid,{_,_,_}}   -> Gid++" Esperando jugador ~n";
		{Gid,{_,_,_,_}} -> Gid++" Jugando ~n"
	end.

getNode(Gid)->
	spawn(server,getNode,[Gid,self()]),
	receive 
		{nd,error} -> error;
		{nd,N}     -> {ok,N}
	end.
	
