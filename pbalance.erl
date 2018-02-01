-module(pbalance).
-compile(export_all).

%%Lleva una lista con la carga de los nodos.
%%Se consulta a traves de la funcion getNode, que "retorna" el nodo menos cargado

getNode()-> 
	balance!{min,self()},
	receive	X -> X end.
	
nodeList(List)->
	receive
		{load,S,N} -> 
			Ll=lists:filter(fun({X,_})-> X/=S end,List),
			L=[{S,N}|Ll];
		{min,P}    ->
			L=List,
			{A,_B} = minimo(L),
			P!A
	end,
	nodeList(L).

minimo(L)->
	Ls=lists:sort(fun({_,X},{_,Y})-> X<Y end,L),
	lists:nth(1,Ls).

	
