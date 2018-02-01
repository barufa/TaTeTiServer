-module(server).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).
%%Inicializa todo

f()->
	receive
		X -> io:format("F: ~p~n",[X])
	end,
	f().

next()->ok.%%Nombre del siguiente nodo.
back()->ok.%%Nombre del nodo anterior.

init(Puerto)->
	io:format("Iniciando nodo ~p~n",[node()]),
	Pdir=spawn(?MODULE,directory,[ordsets:new()]),
	Pbal=spawn(pbalance,nodeList,[[]]),
	Psta=spawn(pstat,monitor,[]),
	register(dir,Pdir),
	register(balance,Pbal),
	register(stat,Psta),
	dispacher:init(Puerto).

directory(List)->
	receive
		{add,_Pid,Nombre}    ->
			L=ordsets:add_element(Nombre,List);
		{remove,_Pid,Nombre} ->
			L=ordsets:del_element(Nombre,List);
		{is,Pid,Nombre}      ->
			L=List,
			R=ordsets:is_element(Nombre,List),
			Pid!R
	end,
	directory(L).
