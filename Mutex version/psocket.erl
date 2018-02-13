-module(psocket).
-compile(export_all).
-define(OPCIONES,[{active,false},{mode, binary}]).
-import(pbalance,[getNode/0]).

getName(Socket)->
	case string:tokens(inbox(Socket)," ") of
		["CON",Cid,Nombre] ->
			dir!{add,self(),Nombre},
			receive
			   ok      ->
					gen_tcp:send(Socket,"OK "++Cid),
					interfaz(Socket,Nombre);
			   error  ->
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
			spawn(getNode(),pcomando,comand,[self(),lists:append([Comand|Op])]),
			receive 
				{ok,X}    ->
					gen_tcp:send(Client,"OK "++Id++" "++X),
					interfaz(Client,Nombre);
				{error,Y} ->
					gen_tcp:send(Client,"ERROR "++Id++" "++Y),
					interfaz(Client,Nombre);
				{msg,Z}   ->
					gen_tcp:send(Client,"SERVER "++Z),
					interfaz(Client,Nombre);
				close   ->
					gen_tcp:send(Client,"OK "++Id),
					clean(Client,Nombre)
			end;
		["ERROR"] ->
			clean(Client,Nombre);
		_L -> io:format("What???~n")
	end.

clean(Sk) ->
	receive after 500 -> ok end,
	gen_tcp:close(Sk),
	exit(ok).
	
clean(Sk,Nombre)->%%Quitar tambien de games
	dir!{remove,self(),Nombre},
	clean(Sk).

newName(Nombre)->
	dir!{add,self(),Nombre},
	receive
		ok    -> ok;
		error -> error
	end.

inbox()-> receive X -> X end.
inbox(Socket)->
	io:format("Wait~n"),
	case gen_tcp:recv(Socket,0) of
		{ok,<<S/binary>>} -> binary:bin_to_list(S);
		{error,_Reason}   -> gen_tcp:send(Socket,"Error conexionerror"),"ERROR"
	end.
