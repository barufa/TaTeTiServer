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
