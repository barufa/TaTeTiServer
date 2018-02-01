-module(pcomando).
-compile(export_all).

init(Psocket)->
  io:format("En pcomando~n"),
  receive
    Msg ->
      io:format("Llego ~p~n",[Msg]),
      Nmsg=string:reverse(Msg),
      Psocket!Nmsg
  end,
  init(Psocket).
