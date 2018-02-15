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
					P=spawn(?MODULE,listen,[Socket,Nombre]),
					interfaz(Socket,Nombre,P);
			   error  ->
					gen_tcp:send(Socket, "ERROR "++Cid++" Used"),
					getName(Socket)
			end;
		[_Com|[Id|_L]]     ->
			gen_tcp:send(Socket,"ERROR "++Id++"comanderror");
		_X                  ->
			clean(Socket)
	end.

listen(Client,Nombre)->
	receive 
		{res,X}    ->
			gen_tcp:send(Client,X),
			listen(Client,Nombre);
		{msg,Y}    ->
			gen_tcp:send(Client,"UPD "++Y),
			listen(Client,Nombre);
		close   ->
			gen_tcp:send(Client,"Cerrando la conexion~n"),
			clean(Client,Nombre)
	end.

interfaz(Client,Nombre,Plis)->
	case string:tokens(inbox(Client)," ") of
		["LSG",Id]->spawn(getNode(),pcomando,comand,[Plis,Id,{lsg}]);
		["NEW",Id]->spawn(getNode(),pcomando,comand,[Plis,Id,{new}]);
		["HLP",Id]->spawn(getNode(),pcomando,comand,[Plis,Id,{help}]);
		["LEA",Id,Game]->spawn(getNode(),pcomando,comand,[Plis,Id,{leave,Game}]);
		["OBS",Id,Game]->spawn(getNode(),pcomando,comand,[Plis,Id,{obs,Game}]);
		["ACC",Id,Game]->spawn(getNode(),pcomando,comand,[Plis,Id,{acc,Game}]);
		["PLA",Id,Game,Lugar]->spawn(getNode(),pcomando,comand,[Plis,Id,{pla,Game,toint(Lugar)}]);
		["BYE",Id]->spawn(getNode(),pcomando,comand,[Plis,Id,{bye}]);
		["ERROR"] ->clean(Client,Nombre);
		_L    -> gen_tcp:send(Client,"PARSE ERROR~n")
	end,
	interfaz(Client,Nombre,Plis).

clean(Sk) ->
	gen_tcp:close(Sk),
	exit(ok).
	
clean(Sk,Nombre)->
	dir!{remove,self(),Nombre},
	game!{removeall,self()},
	clean(Sk).

newName(Nombre)->
	dir!{add,self(),Nombre},
	receive
		ok    -> ok;
		error -> error
	end.

inbox(Socket)->
	case gen_tcp:recv(Socket,0) of
		{ok,<<S/binary>>} -> binary:bin_to_list(S);
		{error,_Reason}   -> gen_tcp:send(Socket,"Error conexionerror"),"ERROR"
	end.

toint(String)->
	{A,_B}=string:to_integer(String),
	A.
