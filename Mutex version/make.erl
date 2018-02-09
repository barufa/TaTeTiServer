-module(make).
-compile(export_all).

first(Puerto)->
	net_kernel:start([fst, shortnames]),
	spawn(server,init,[Puerto]).
	
sad(Puerto)->
	net_kernel:start([sad, shortnames]),
	net_adm:ping('fst@R480'),
	spawn(server,init,[Puerto]).
	
mas(Puerto)->
	net_kernel:start([mas, shortnames]),
	net_adm:ping('fst@R480'),
	spawn(server,init,[Puerto]).

bad(Puerto)->
	net_kernel:start([bad, shortnames]),
	net_adm:ping('fst@R480'),
	spawn(server,init,[Puerto]).
