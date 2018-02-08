-module(psocket).
-compile(export_all).
-define(OPCIONES,[{active,false},{mode, binary}]).
-import(pbalance,[getNode/0]).

%%Se encarga a obtener un nombre de usuario y redireccionar los mensajes al pcomando correspondiente

getName(Socket)->
	case string:tokens(inbox(Socket)," ") of
		["CON",Cid,Nombre] ->
			case newName(Nombre) of
			   ok      ->
					gen_tcp:send(Socket,"OK "++Cid),
					interfaz(Socket,Nombre);
			   _Error  ->
					gen_tcp:send(Socket, "ERROR "++Cid++" Used"),
					getName(Socket)
			end;
		[_Com|[Id|_L]]     ->
			gen_tcp:send(Socket,"ERROR "++Id++"comanderror");
		_X                  ->
			clean(Socket)
	end.

interfaz(Client,Nombre)->
	case string:tokens(inbox(Client)," ") of
		[Comand|[Id|Op]] ->
			spawn(getNode(),pcomando,reverse,[[Comand|Op],self()]),
			receive 
				{ok,X}    ->
					gen_tcp:send(Client,"OK "++Id++" "++X);
				{error,Y} ->
					gen_tcp:send(Client,"ERROR "++Id++" "++Y);
				{close}   ->
					gen_tcp:send(Client,"OK "++Id),
					clean(Client,Nombre)
			end
	end,
	interfaz(Client,Nombre).

clean(Sk) ->
	receive after 500 -> ok end,
	gen_tcp:close(Sk),
	exit(ok).
	
clean(Sk,Nombre)->
	dir!{remove,self(),Nombre},
	clean(Sk).

newName(Nombre)->%%Verifica si un nombre esta disponible y lo agrega
	 dir!{is,self(),Nombre},
	 receive
	 	true   ->
	 		error;
	 	_False ->
			dir!{add,self(),Nombre},
	 		ok
	 end.

inbox()-> receive X -> X end.
inbox(Socket)->
	case gen_tcp:recv(Socket,0) of
		{ok,<<S/binary>>} -> binary:bin_to_list(S);
		{error,_Reason}   -> gen_tcp:send(Socket,"Error conexionerror"),error
	end.
