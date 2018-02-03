-module(pcomando).
-compile(export_all).

reverser(S)->reverser(S,[]).
reverser([H|T],L)->reverser(T,[H|L]);
reverser([],SS)->SS.

reverse(Psocket)->
  io:format("En pcomando en ~p~n",[node()]),
  receive
    Msg ->
      io:format("Llego ~p~n",[Msg]),
      Nmsg=reverser(Msg),
      Psocket!Nmsg
  end,
  reverse(Psocket).

inbox() -> receive X -> X end.

comand(Psocket)->
	case string:tokens(inbox()," ") of
		["LSG"]      -> 
			dir!{show,self()},
			S=server:tostring(inbox()),
			Psocket!S;
		["ACC",User] ->
			dir!{is,self(),User},
			case inbox() of
				true ->
					Atom=server:getAtom(User),
					Nodo=server:getNode(User),
					sendit({Atom,Nodo});
				_False->
					Psocket!error
			end
	end.

sendit(User)->
	receive Msm -> User!("UPD "++Msm) end,
	sendit(User).
