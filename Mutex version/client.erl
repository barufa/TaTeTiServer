-module(client).
-compile(export_all).

-define(PUERTO, 8002).
-define(HOST, {127, 0, 0, 1}).
-define(OPCIONES,[{active,false},{mode, binary}]).

init()-> main(?HOST,?PUERTO).
init(Puerto)-> main(?HOST,Puerto).

main(Host,Puerto)->
	{ok,Socket} = gen_tcp:connect(Host, Puerto, ?OPCIONES),
	username(Socket),
	spawn(?MODULE,writer,[Socket]),
	reader(Socket).

username(Socket)->
	Nombre = string:strip(io:get_line("Ingrese un nombre de usuario: "),right,$\n),%Salto de linea o espacio?
	gen_tcp:send(Socket,"CON "++Nombre),
	case gen_tcp:recv(Socket,0) of
		{ok,<<"OK ",_/binary>>}  ->
			io:format("Bienvenido ~p~n",[Nombre]),
			Nombre;
		{ok,<<"ERROR ",_/binary>>}   ->
			io:format("El nombre de usuario no esta disponible~n"),
			username(Socket);
		{error,closed}              ->
			io:format("Se ha cerrado la conexion~n"),
			exit(closed);
		{error,Reason}              ->
			io:format("Se ha producido un error en la conexion~n"),
			exit(Reason)
	end.

writer(Server)->
	Comando = string:strip(io:get_line("-> "), right, $\n),
	spawn(gen_tcp,send,[Server,Comando]),
	writer(Server).

reader(Server)-> %%Falta modificar
	case gen_tcp:recv(Server,0) of
		{ok,<<"UPD ",Cambio>>} ->
			io:format("~s~n",Cambio),%%Mejorar Vista
			reader(Server);
		{ok,Otherwise}        ->
			io:format("Mensaje: ~p~n",[Otherwise]),%%Necesario??
			reader(Server);
		{error,Reason}        ->
			io:format("Error: ~p~n",[Reason]),
			exit(Reason)
	end.
