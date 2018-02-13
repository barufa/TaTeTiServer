-module(pcomando).
-compile(export_all).

reverser(S)->reverser(S,[]).
reverser([H|T],L)->reverser(T,[H|L]);
reverser([],SS)->SS.

reverse(Comando,Psocket)->
  C = lists:nth(1,Comando),
  Psocket!{ok,reverser(C)}.

comand(Psocket,Comand)->
	case string:tokens(Comand," ") of
		["LSG"]      ->%%Lista los juegos disponibles(no iniciados)
			game!{show,self()},
			receive {game,L} -> L end,
			Psocket!{ok,server:tostring(L)};
		["NEW"]      ->%%Crea un nuevo juego y espera
			game!{add,self(),Psocket},
			receive {start,Gid} -> Gid end,
			Psocket!{ok,"Partidi identificada como "++server:tostring(Gid)};
		["OBS",Game] ->%%Observa un juego,cierra el pcomando actual
			game!{obs,self(),Game,Psocket},
			receive 
				ok    -> Psocket!{ok,Game};
				error -> Psocket!{error,Game}
			end;
		["BYE"]      ->%%Cierrra la conexion
			Psocket!close;
		["ACC",Game] ->%%Acepta un juego
			game!{con,self(),Game,Psocket},
			receive
				ok    -> Psocket!{ok,Game};
				error -> Psocket!{error,Game}
			end;
		["PLA",_GAME] ->%%Realiza una jugada en un juego
			Psocket!{error,"imp"},io:format("Comando no implementado~n");
		["LEA",Game]      ->%%Abandona una partida que esta obserando			
			game!{removeobs,self(),Game,Psocket};
		["HLP"]      ->%%Muestra un mensaje de ayuda			
			Psocket!helpstring();
		["UPD",Gid,Game]      ->%%Modifica un juego			
			game!{mov,self(),Gid,Psocket,Game},
			receive
				ok    -> Psocket!{ok,Gid};
				error -> Psocket!{error,Gid}
			end
	end.

sendit(User)->
	receive Msm -> User!("UPD "++Msm) end,
	sendit(User).

inbox() -> receive X -> server:tostring(X) end.

helpstring()->"Mensaje de ayuda~n".
