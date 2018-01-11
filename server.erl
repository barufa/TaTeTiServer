-module(server).
-compile(export_all).
-export([init/0]).

-define(PUERTO,8002).

update(List,Pid,Nombre)->%%Agrega un Nombre si esta disponible
	case lists:any(fun({_Id,N}) -> N==Nombre end,List) of
		true -> {used,List};
		_Ok  -> {okname,List++[{Pid,Nombre}]}
	end.

remove(List,Pid)->%%Elimina un nombre de la lista
	lists:filter(fun({Id,_N})-> Pid/=Id end,List).

snd({_A,B})->B.

fixed(List,Pid,Texto)->%%Acomoda el mensaje para identificar a los usuarios
	case lists:filter(fun({Id,_N}) -> Id==Pid end,List) of
		[]    -> "Anonimo: "++Texto;
		[H|_T] -> snd(H)++": "++Texto
	end.

auxiliar(Pid,Id,Texto)->%%Envie el mensaje si el Id y el Pid son distintos
	if Pid/=Id -> Id!{msm,Texto};
		true   -> ok
	end.
	

server(List)->%%Funcion principal del server, se encarga de responde a los clientes(Hilos de esta maquina)
	receive
		{new,Pid,Nombre} ->
			{Atom,L}=update(List,Pid,Nombre),
			Pid!Atom;			
		{msm,Pid,Texto}  ->
			L=List,
			Mensaje=fixed(List,Pid,Texto),
			lists:map(fun({Id,_N}) -> auxiliar(Pid,Id,Mensaje) end,List);
		{ex,Pid}         -> 
			L=remove(List,Pid)
	end,
	server(L).

init()->
	Pid = spawn(fun() -> server([]) end),
	spawn(?MODULE,main,[?PUERTO,Pid]).

main(Puerto,Server)->%%Crea un socket y va a esperar conexiones
	Opciones = [{active, true}, {mode, binary}],
	{ok,Socket} = gen_tcp:listen(Puerto,Opciones),
	io:format("Escuchando en el puetro ~p~n",[Puerto]),
	listen(Socket,Server).
	
listen(Socket,Server)->%%Espera nuevas conexiones
	{ok,Newsocket} = gen_tcp:accept(Socket),
	spawn(fun() -> listen(Socket,Server) end),
	io:format("Se ha establecido una nueva conexio ~p~n",[Newsocket]),
	cliente(Newsocket,Server).

cliente(Socket,Server)->%%Interface entre el cliente y el server(Simplifica tcp)
	receive
	%%Enviado por server
		used        ->
			gen_tcp:send(Socket,"USED/"),
			cliente(Socket,Server);
		okname      ->
			gen_tcp:send(Socket,"OKNAME/"),
			cliente(Socket,Server);
		{msm,Texto} ->
			gen_tcp:send(Socket,"MSM/"++Texto),
			cliente(Socket,Server);
	%%Enviado por el cliente
		{tcp,Socket,<<"NEW/",Nombre/binary>>} ->
			Server!{new,self(),binary:bin_to_list(Nombre)},
			cliente(Socket,Server);
		{tcp,Socket,<<"MSM/",Texto/binary>>}  ->
			Server!{msm,self(),binary:bin_to_list(Texto)},
			cliente(Socket,Server);
		{tcp,Socket,<<"EXIT/">>}                  ->
			Server!{ex,self()},
			gen_tcp:close(Socket);
		{tcp_closed, Socket}                  ->
			io:format("Se cerro la conexion~n");
	%%Errores
		Error			                      ->
			io:format("Error: ~p~n",[Error]),
			cliente(Socket,Server)
	end.
