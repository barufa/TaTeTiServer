-module(server).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).
%%Inicializa todo

tostring(S)->tostring(S,[]).
tostring(S,L)-> lists:flatten(io_lib:format(S,L)).

getit(String,N)->
	L=string:tokens(String,"{_}"),
	case length(L) of
		2 ->
			lists:nth(N,L);
		_M ->
			error
	end.

getName(String)->getit(String,1).
getNode(String)->list_to_atom(getit(String,2)).
getAtom(String)->list_to_atom(String).

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
			io:format("Dir add ~p~n",[Nombre]),
			L=ordsets:add_element(Nombre,List);
		{remove,_Pid,Nombre} ->
			L=ordsets:del_element(Nombre,List);
		{is,Pid,Nombre}      ->
			L=List,
			io:format("Dir is ~p~n",[Nombre]),
			R=ordsets:is_element(Nombre,List),
			Pid!R;
		{show,Pid}           ->
			L=List,
			R=ordsets:to_list(L),
			Pid!R;
		{all,Pid}            ->
			L=List,
			Lw = lists:map(fun(Node)-> spawn(Node,server,getuserlist,[self()]),receive X -> X end end,nodes()),
			Pid!(lists:append(Lw)++L)
	end,
	directory(L).

getuserlist(Pid)->
	dir!{show,self()},
	receive X -> Pid!X end.
