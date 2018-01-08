%%Falta agregar todo TCP
-module(server).
-compile(export_all).
-export([init/0]).

return() -> ok.
return(A) -> A. %%Para enfatizar donde termina la funcion

update(Pid,Nombre,L)->%%Actualiza la lista L
	case lists:any(fun({_P,N}) -> N==Nombre end,L) of
		true  -> Pid!used,
				 return(L);
	    _     -> Pid!ok,
	             return(L ++ [{Pid,Nombre}])
	end.

update(Pid,L)->%%Actualiza la lista L
	lists:filter(fun({P,_N}) -> P==Pid end,L).

auxiliar({Pid,Nombre},Id,Txt)-> 
	if Pid==Id -> ok;
	   true    -> Pid!{msg,Nombre++": "++Txt}
	end.

server(L)-> %% server(Lista de nombres de {PID,username}).
	receive
		{new,Pid,Nombre}  -> A = update(Pid,Nombre,L),
						     server(A);
		{msg,Pid,Texto}   -> lists:map(fun(X) -> auxiliar(X,Pid,Texto) end,L),
							 server(L);
		{ex,Pid}          -> A = update(Pid,L),
							 server(A)
	end.

init()-> 
	io:format("~p~n",[self()]),
	server([]).

