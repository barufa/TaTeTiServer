-module(dispacher).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).

%%Toma la conexion y llama a psocket.

init()-> init(?PUERTO).

init(Puerto)->
	{ok,Socket} = gen_tcp:listen(Puerto,?OPCIONES),
	listen(Socket).

listen(ListenSocket)->
	{ok, Socket} = gen_tcp:accept(ListenSocket),
   	spawn(psocket,getName,[Socket]),
	listen(ListenSocket).

