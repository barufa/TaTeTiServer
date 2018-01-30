-module(psocket).
-compile(export_all).
-define(OPCIONES,[{active,false},{mode, binary}]).
%-import(pbalance, [getServer/0]).

init(Client)->%%Funciona como una tuberia, redireccionando los mensajes
	{Ip,Puerto} = pbalance:getServer(),%Funcion de pbalance
	{ok,Server} = gen_tcp:connect(Ip,Puerto,?OPCIONES),
	spawn(?MODULE,interfaz,[Client,Server]),
	interfaz(Server,Client).

interfaz(A,B)->
	case gen_tcp:recv(A,0) of
		{ok,Something}  -> 
			gen_tcp:send(B,Something),
			interfaz(A,B);
		{error,_Reason} ->
			gen_tcp:close(B),
			gen_tcp:close(A)
	end.
