-module(dispacher).
-compile(export_all).
-define(OPCIONES,[{active,false},{mode, binary}]).

init(Puerto)->
	{ok,Socket} = gen_tcp:listen(Puerto,?OPCIONES),
	listen(Socket).

listen(ListenSocket)->
	{ok, Socket} = gen_tcp:accept(ListenSocket),
	io:format("Nueva conexion ~p~n",[Socket]),
   	spawn(psocket,getName,[Socket]),
	listen(ListenSocket).

