-module(dispatcher).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).

init()-> init(?PUERTO).

init(Puerto)->
	{ok,Socket} = gen_tcp:listen(Puerto,?OPCIONES),
	Pid = spawn(?MODULE,directory,[ordset:new()]),
	register(directory,Pid),
	listen(Socket).

directory(List)->%%Deberia estar en server, por el momento la implemento aca
	receive 
		{add,_Pid,Nombre}    ->
			L=ordset:add_element(Nombre,List);
		{remove,_Pid,Nombre} ->
			L=ordset:del_element(Nombre,List);
		{is,Pid,Nombre}      ->
			L=List,
			R=ordset:is_element(Nombre,List),
			Pid!R
	end,
	directory(L).

listen(ListenSocket)->
	{ok, Socket} = gen_tcp:accept(ListenSocket),
    	spawn(?MODULE,interfaz,[Socket]),
	listen(ListenSocket).
	
interfaz(Socket)->
	 case gen_tcp:recv(Socket, 0) of
		{ok,<<"CON",Nombre>>} ->
			case newName(Nombre) of
			   ok      -> 
					gen_tcp:send(Socket, "OK"),
					spawn(psocket, init, [Socket]);
			   _Error  -> 
					gen_tcp:send(Socket, "ERROR CON Name")
			end;
		{ok,_Msg}              ->
			gen_tcp:send(Socket, "Error: Parser");
		{error,_Reason}       ->
			gen_tcp:send(Socket,"Error: recv")
		end.

newName(Nombre)->
	directory!{is,self(),Nombre},
	receive
		true   -> 
			error;
		_False ->
			directory!{add,self(),Nombre},
			ok
	end.
