%%Un cliente va a tener vario hilos asociados a el(psocket,pcomando):
%%En caso de que un hilo se caiga cerrar todos y volver a mandar al dispacher?
%%En caso de que el socket se cierra matar los procesos y borrar al cliente de los registros

-module(server).
-compile(export_all).
-define(PUERTO,8000).
-define(OPCIONES,[{active,false},{mode, binary}]).
-define(TIMEOUT,8000).

tostring(S)->tostring("~p",[S]).
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
getNode(String)->getit(String,2).
getAtom(String)->list_to_atom(String).

init(Puerto)->
	io:format("Iniciando nodo ~p~n",[node()]),
	Pdir=spawn(?MODULE,userdirectory,[ordsets:new()]),
	Pgam=spawn(?MODULE,gamedirectory,[ordsets:new()]),
	Pwat=spawn(?MODULE,waitdirectory,[ordsets:new()]),
	Pbal=spawn(pbalance,nodeList,[[]]),
	Psta=spawn(pstat,monitor,[]),
	register(dir,Pdir),
	register(balance,Pbal),
	register(stat,Psta),
	register(game,Pgam),
	register(wait,Pwat),
	dispacher:init(Puerto).

userdirectory(List)->
	receive%%Nombre::String => Compuesto como user_node
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
	userdirectory(L).

gamedirectory(List)->
	receive%%Game :: String => pcomando_user_user donde pcomando={self(),node()} del pcomando
		{add,_Pid,Game}    ->
			L=ordsets:add_element(Game,List);
		{remove,_Pid,Game} ->
			L=ordsets:del_element(Game,List);
		{is,Pid,Game}      ->
			L=List,
			R=ordsets:is_element(Game,List),
			Pid!R;
		{show,Pid}         ->
			L=List,
			R=ordsets:to_list(L),
			Pid!R;
		{all,Pid}          ->
			L=List,
			Lw = lists:map(fun(Node)-> spawn(Node,server,getgamelist,[self()]),receive X -> X end end,nodes()),
			Pid!(lists:append(Lw)++L)
	end,
	gamedirectory(L).

waitdirectory(List)->
	receive%%User :: String => pcomando_user donde pcomando={self(),node()} del pcomando
		{add,_Pid,User}    ->
			L=ordsets:add_element(User,List);
		{remove,_Pid,User} ->
			L=ordsets:del_element(User,List);
		{is,Pid,User}      ->
			L=List,
			R=ordsets:is_element(User,List),
			Pid!R;
		{show,Pid}         ->
			L=List,
			R=ordsets:to_list(L),
			Pid!R;
		{all,Pid}          ->
			L=List,
			Lw = lists:map(fun(Node)-> spawn(Node,server,getwaitlist,[self()]),receive X -> X end end,nodes()),
			Pid!(lists:append(Lw)++L)
	end,
	waitdirectory(L).
	
getwaitlist(Pid)->
	wait!{show,self()},
	receive X -> Pid!X end.

getgamelist(Pid)->
	game!{show,self()},
	receive X -> Pid!X end.

getuserlist(Pid)->
	dir!{show,self()},
	receive X -> Pid!X end.
