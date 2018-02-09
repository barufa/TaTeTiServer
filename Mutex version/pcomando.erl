-module(pcomando).
-compile(export_all).

reverser(S)->reverser(S,[]).
reverser([H|T],L)->reverser(T,[H|L]);
reverser([],SS)->SS.

reverse(Comando,Psocket)->
  C = lists:nth(1,Comando),
  Psocket!{ok,reverser(C)}.

%~ comand(Psocket)->
	%~ case string:tokens(inbox(),"\" ") of
		%~ ["LSG"]      ->%%Lista los juegos disponibles(no iniciados)
		%~ ["LVG"]      ->%%Lista los juegos que se pueden observar
		%~ ["LBS"]      ->%%Observa un juego,cierra el pcomando actual
		%~ ["NEW"]      ->%%Crea un nuevo juego y espera
		%~ ["OBS",GAME] ->%%Observa un juego,cierra el pcomando actual
		%~ ["BYE"]      ->%%Cierrra la conexion
		%~ ["ACC",GAME] ->%%Acepta un juego
		%~ ["PLA",GAME] ->%%Realiza una jugada en un juego
		%~ ["LEA"]      ->%%Abandona una partida que esta obserando			
		%~ ["HLP"]      ->%%Muestra un mensaje de ayuda			
	%~ end.


sendit(User)->
	receive Msm -> User!("UPD "++Msm) end,
	sendit(User).

inbox() -> receive X -> server:tostring(X) end.
