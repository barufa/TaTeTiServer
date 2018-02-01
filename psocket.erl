-module(psocket).
-compile(export_all).
-define(OPCIONES,[{active,false},{mode, binary}]).
-import(pbalance,[getNode/0]).

%%Se encarga a obtener un nombre de usuario y redireccionar los mensajes al pcomando correspondiente

getName(Socket)->
	case gen_tcp:recv(Socket,0) of
		{ok,<<"CON",Nombre>>}->
			case newName(Nombre) of
			   ok      -> 
					gen_tcp:send(Socket,"OK CON"),
					Node=getNode(),
					Pid=spawn(Node,pcomando,init,[{self(),node()}]),
					interfaz(Socket,{Node,Pid});
			   _Error  -> 
					gen_tcp:send(Socket, "ERROR CON Used"),
					getName(Socket)
			end;
		{ok,_Msg}              ->
			gen_tcp:send(Socket,"Error: Parser");
		{error,_Reason}       ->
			gen_tcp:send(Socket,"Error: recv")
	end.

interfaz(Client,Server)->
	spawn(?MODULE,client2server,[Client,Server]),
	spawn(?MODULE,server2client,[Client,Server]).

client2server(Client,Server)->
	case gen_tcp:recv(Client,0) of
		{ok,Msg} -> Server!Msg
	end,
	client2server(Client,Server).

server2client(Client,_Server)->
	receive
		Msg -> gen_tcp:send(Client,Msg)
	end,
	server2client(Client,_Server).

newName(Nombre)->
	dir!{is,self(),Nombre},
	receive
		true   -> 
			error;
		_False ->
			directory!{add,self(),Nombre},
			ok
	end.
