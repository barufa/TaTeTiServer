-module(client).
-compile(export_all).

-define(PUERTO, 8000).
-define(HOST, {127, 0, 0, 1}).
-define(OPCIONES,[{active,false},{mode, binary}]).

init()-> main(?HOST,?PUERTO).
init(Puerto)-> main(?HOST,Puerto).

main(Host,Puerto)->
	{ok,Socket} = gen_tcp:connect(Host, Puerto, ?OPCIONES),
	username(Socket),
	spawn(?MODULE,writer,[Socket,1]),
	reader(Socket).

username(Socket)->
	Nombre = string:strip(io:get_line("Ingrese un nombre de usuario: "),right,$\n),%Salto de linea o espacio?
	gen_tcp:send(Socket,"CON 0 "++Nombre),
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

writer(Server,Cid)->
	Comando = string:strip(io:get_line("-> "), right, $\n),
	[A|B] = string:tokens(Comando," "),
	Com = lists:foldl(fun(X,R)-> R++" "++X end,"",[A|[server:tostring(Cid)|B]]),
	spawn(gen_tcp,send,[Server,Com]),
	writer(Server,Cid+1).

reader(Server)->
	case gen_tcp:recv(Server,0) of
		{ok,<<"UPD ",Cambio/binary>>} ->
			io:format("UPD ~s ~n",[binary_to_list(Cambio)]),
			reader(Server);
		{ok,<<"OK ",Cambio/binary>>} ->
			io:format("Comando ejecutado con exito: ~p ~n",[binary_to_list(Cambio)]),
			reader(Server);
		{ok,<<"ERROR ",Cambio/binary>>} ->
			io:format("Se ha producio un error en el comando anterior: ~p ~n",[binary_to_list(Cambio)]),
			reader(Server);
		{error,Reason}        ->
			io:format("Error: ~p~n",[Reason]),
			exit(Reason)
	end.
