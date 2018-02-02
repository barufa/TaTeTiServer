-module(pstat).
-compile(export_all).
-define(INTERVAL,2000).

%%Envia la carga del nodo a todos los demas a intervalos regulares

sleep(N) -> receive after N -> ok end.

monitor()->
	sleep(?INTERVAL),
	{_,N} = statistics(reductions),
	L = [node()|nodes()],
	lists:foreach(fun(V)-> {balance,V}!{load,node(),N} end,L),
	monitor().
