-module(client).
-compile(export_all).
-export([init/1]).

username(Server)->%%Lee un nombre de usuario
	Nombre = io:get_line("Ingrese su nombre de usuario: "),
	Server ! {new,self(),Nombre},
	receive
		used -> io:format("El usuario ~p ya esta en uso~n",[Nombre]),
				username(Server);
		ok   -> io:format("Bienvenido ~p~n",[Nombre])
	end.
	
send(Server,Pid) -> %%Lee una linea y envia el mensaje al servidor
	case io:get_line("") of
		"Chat:Salir\n" -> Server!{ex,Pid};
		Mensaje        -> Server!{msg,Pid,Mensaje},send(Server,Pid)
	end.%%Se llama recursivamente (asumo que io:get_line duerme hasta que el usuario escriba algo)
	
reader()->%%Encargado de recibir los mensajes(Hilo principal para mantener el inbox)
	receive
		{msg,Texto} -> io:format("~p~n",[Texto]),
					   reader();
		_           -> reader()
	end.

init(Server)->
	username(Server),
	spawn(?MODULE,send,[Server,self()]),
	reader().
