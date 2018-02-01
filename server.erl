-module(server).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).

%%Inicializa todo

next()->ok.%%Nombre del siguiente nodo.
back()->ok.%%Nombre del nodo anterior.

init(Puerto)->
	io:format("Iniciando nodo ~p~n",[node()]),
	Pdir=spawn(?MODULE,directory,[ordset:new()]),
	Psta=spawn(pstat,monitor,[]),
	Pbal=spawn(pbalance,nodeList,[]),
	register(dir,Pdir),
	register(balance,Pbal),
	register(stat,Psta),
	dispacher:init(Puerto).
	
directory(List)->
	receive 
		{add,_Pid,Nombre}    ->
			L=ordset:add_element(Nombre,List);
		{remove,_Pid,Nombre} ->
			L=ordset:del_element(Nombre,List);
		{is,Pid,Nombre}      ->
			L=List,
			R=ordset:is_element(Nombre,List),
			Pid!R
	end,
	directory(L).
