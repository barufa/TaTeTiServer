-module(psocket).
-compile(export_all).
-define(OPCIONES,[{active,false},{mode, binary}]).
-import(pbalance,[getNode/0]).

%%Se encarga a obtener un nombre de usuario y redireccionar los mensajes al pcomando correspondiente

getName(Socket)->
	case gen_tcp:recv(Socket,0) of
		{ok,<<"CON",Name/binary>>}->
			Nombre=binary:bin_to_list(Name),
			case newName(Nombre) of
			   ok      ->
					gen_tcp:send(Socket,"OK CON"),
					Node=getNode(),
					AtomSv=list_to_atom(Nombre++"server"),
					AtomCl=list_to_atom(Nombre++"client"),
					register(AtomSv,self()),
					Pid=spawn(Node,pcomando,init,[{AtomSv,node()}]),
					register(AtomCl,Pid),
					interfaz(Socket,{AtomCl,node()});
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
			Server!binary:bin_to_list(Msg);
		_X ->
			io:format("Rompe todo~n")
	end,
	client2server(Client,Server).

server2client(Client,_Server)->
	receive
		Msg -> gen_tcp:send(Client,Msg)
	end,
	server2client(Client,_Server).

newName(_Nombre)->ok.
	% dir!{is,self(),Nombre},
	% receive
	% 	true   ->
	% 		error;
	% 	_False ->
	% 		directory!{add,self(),Nombre},
	% 		ok
	% end.
