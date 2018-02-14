-module(pbalance).
-compile(export_all).

getNode()->
	balance!{min,self()},
	receive	{nd,X} -> X end.

nodeList(List)->
	receive
		{load,S,N} ->
			%~ io:format("Pbalance: ~p~n",[List]),
			Ll=lists:filter(fun({X,_})-> X/=S end,List),
			L=[{S,N}|Ll];
		{min,P}    ->
			L=List,
			{A,_B} = minimo(L),
			P!{nd,A}
	end,
	nodeList(L).

minimo(L)->
	case L of
		[] ->
			{node(),1};
		Li ->
			Ls=lists:sort(fun({_,X},{_,Y})-> X<Y end,Li),
			lists:nth(1,Ls)
	end.
