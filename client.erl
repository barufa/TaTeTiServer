-module(client).
-compile(export_all).
-export([init/0]).

-define(PUERTO, 8002).
-define(HOST, {127, 0, 0, 1}).

username(Socket)->%%Lee un nombre de usuario
	Nombre = string:strip(io:get_line("Ingrese un nombre de usuario: "), right, $\n),
	gen_tcp:send(Socket,"NEW/"++Nombre),
	receive
		{tcp,Socket,<<"USED/">>}   ->
			io:format("El usuario ~p ya esta en uso~n",[Nombre]),
			username(Socket);
		{tcp,Socket,<<"OKNAME/">>} ->
			io:format("Bienvenido ~p~n",[Nombre]),
			Nombre
	end.
	
reader(Server,Nombre)->
	case string:strip(io:get_line(Nombre++": "), right, $\n) of
		"Chat:Salir" -> Server!ex;
		Mensaje      -> Server!{msm,Mensaje},reader(Server,Nombre)
	end.

init()-> main(?PUERTO,?HOST).

main(Puerto,Host)->
	Opciones = [{active, true}, {mode, binary}],
	{ok,Socket} = gen_tcp:connect(Host, Puerto, Opciones),
	io:format("Se conecto al servidor ~w en el puerto ~w~n", [Host, Puerto]),
	Nombre = username(Socket),
	spawn(?MODULE,reader,[self(),Nombre]),
	interfaz(Socket).

interfaz(Socket)->
	receive
		{msm,Mensaje}->
			gen_tcp:send(Socket,"MSM/"++Mensaje),
			interfaz(Socket);
		{tcp,Socket,<<"MSM/",Texto/binary>>}->
			io:format("~s~n",[binary:bin_to_list(Texto)]),
			interfaz(Socket);
		ex ->
			io:format("Cerrando Sesion~n"),
			gen_tcp:send(Socket,<<"EXIT/">>),
			gen_tcp:close(Socket);
		Error->
			io:format("Error: ~p~n",Error),
			interfaz(Socket)
	end.
