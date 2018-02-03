-module(psocket).
-compile(export_all).
-define(OPCIONES,[{active,false},{mode, binary}]).
-import(pbalance,[getNode/0]).

%%Se encarga a obtener un nombre de usuario y redireccionar los mensajes al pcomando correspondiente

getName(Socket)->
	case gen_tcp:recv(Socket,0) of
		{ok,<<"CON ",Name/binary>>}->
			Nombre=binary2name(Name),
			case newName(Nombre) of
			   ok      ->
					Pid=spawn(getNode(),pcomando,reverse,[self()]),
					gen_tcp:send(Socket,"OK CON"),
					interfaz(Socket,Pid);
			   _Error  ->
					gen_tcp:send(Socket, "ERROR CON Used"),
					getName(Socket)
			end;
		{ok,Msg}              ->
			io:format("Error: ~p~n",[Msg]),
			gen_tcp:send(Socket,"Error");
		{error,_Reason}       ->
			gen_tcp:send(Socket,"Error")
	end.

binary2name(Bs)->
	S=binary:bin_to_list(Bs),
	Nd=atom_to_list(node()),
	(S++"_"++Nd).

interfaz(Client,Server)->
	spawn(?MODULE,client2server,[Client,Server]),
	server2client(Client,Server).

client2server(Client,Server)->
	case gen_tcp:recv(Client,0) of
		{ok,<<Msg/binary>>} ->
			Msm=binary:bin_to_list(Msg),
			Server!Msm;
		X ->
			io:format("Error en client2server: ~p~n",[X]),
			exit(ok)
	end,
	client2server(Client,Server).

server2client(Client,_Server)->
	receive
		Msg -> gen_tcp:send(Client,Msg)
	end,
	server2client(Client,_Server).

newName(Nombre)->%%Verifica si un nombre esta disponible y lo agrega
	 dir!{is,self(),Nombre},
	 receive
	 	true   ->
	 		error;
	 	_False ->
			dir!{add,self(),Nombre},
	 		ok
	 end.
