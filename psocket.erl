-module(psocket).
-compile(export_all).
-define(OPCIONES,[{active,false},{mode, binary}]).
-import(pbalance,[getNode/0]).

%%Se encarga a obtener un nombre de usuario y redireccionar los mensajes al pcomando correspondiente

getName(Socket)->
	case gen_tcp:recv(Socket,0) of
		{ok,<<"CON ",Name/binary>>}->
			Nombre=binary:bin_to_list(Name),
			case newName(Nombre) of
			   ok      ->
					gen_tcp:send(Socket,"OK CON"),
					Node=getNode(),
					io:format("Creando Pcomando en ~p~n",[Node]),
					Atom=list_to_atom(Nombre++"server"),
					register(Atom,self()),
					Pid=spawn(Node,pcomando,reverse,[{Atom,node()}]),
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

interfaz(Client,Server)->
	spawn(?MODULE,client2server,[Client,Server]),
	server2client(Client,Server).

client2server(Client,Server)->
	case gen_tcp:recv(Client,0) of
		{ok,<<Msg/binary>>} ->
			io:format("Enviado a server~n"),
			Msm=binary:bin_to_list(Msg),
			Server!Msm;
		X ->
			io:format("Error en client2server: ~p~n",[X]),
			receive after 5000 -> ok end,
			exit(rompe)
	end,
	client2server(Client,Server).

server2client(Client,_Server)->
	receive
		Msg -> gen_tcp:send(Client,Msg)
	end,
	server2client(Client,_Server).

newName(_Nombre)->ok.%%Verifica si un nombre esta disponible y lo agrega
	% dir!{is,self(),Nombre},
	% receive
	% 	true   ->
	% 		error;
	% 	_False ->
	% 		directory!{add,self(),Nombre},
	% 		ok
	% end.
