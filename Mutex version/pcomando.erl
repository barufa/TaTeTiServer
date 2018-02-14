-module(pcomando).
-compile(export_all).

comand(Client,CId,Comand)->%%Mejorar mensajes
	case Comand of
		{lsg}->
			game!{show,self()},
			receive {game,L} -> L end,
			Client!{res,okid(CId)++server:tostring(L)};			
		{new}->
			game!{add,self(),Client},
			receive {ok,Gid} -> Gid end,
			Client!{res,okid(CId)++server:tostring(Gid)};
		{help}->
			Client!{res,okid(CId)++helpstring()};
		{obs,Game}->
			game!{obs,self(),Game,Client},
			receive 
				ok    ->
					Client!{res,okid(CId)++Game};
				error ->
					Client!{res,errorid(CId)++Game}
			end;
		{leave,Game}->
			game!{removeobs,self(),Game,Client};
		{acc,Game}->
			game!{con,self(),Game,Client},
			receive
				ok    -> Client!{res,okid(CId)++Game};
				error -> Client!{res,errorid(CId)++Game}
			end;
		{pla,Game,Lugar}->%%IMPLEMENTAR
			game!{mov,self(),Game,Client,Lugar},
			receive
				ok    -> Client!{res,okid(CId)++Game};
				error -> Client!{res,errorid(CId)++Game}
			end,
			Client!{res,errorid(CId)++"Comando no implementado"};
		{bye}->
			Client!close
	end.

helpstring()->"Mensaje de ayuda~n".
okid(Id)-> "OK "++Id++" ".
errorid(Id)->"ERROR "++Id++" ".
