
[![Build Status]](https://github.com/barufa/TaTeTiServer)

# Erlang Tic-Tac-Toe
<pre>                                                         
  _|      _|                  _|                                _|       
_|_|_|_|        _|_|_|      _|_|_|_|    _|_|_|    _|_|_|      _|_|_|_|    _|_|      _|_| 
  _|      _|  _|              _|      _|    _|  _|              _|      _|    _|  _|_|_|_| 
  _|_     _|  _|              _|_     _|    _|  _|              _|_     _|    _|  _|      
    _|_|  _|    _|_|_|          _|_|    _|_|_|    _|_|_|          _|_|    _|_|      _|_|_|  
</pre>                                                                                                           

A simple implementation of a distributed Tic-Tac-Toe game implemented in Erlang.

## How to use
The program runs on an Erlang virtual machine, so it is necessary to have Erlang installed on your computer.
Erlang is a programming language used to build massively scalable soft real-time systems with requirements on high availability. You can install it through the following commands:
```
$ wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
$ sudo dpkg -i erlang-solutions_1.0_all.deb
$ sudo apt-get update
$ sudo apt-get install esl-erlang
```
To use the server, the following commands must be executed:
```
erl -name NameNode@IP -setcookie Cookie
```
Once this is done it is necessary to connect the nodes with each other:
```
net adm:ping(’nodeNameOtherComputer@IP’)
```
Where ’nodeNameOtherComputer@IP’ is one of the server nodes. Finally, it runs to start the server:
```
server:init().
```
On behalf of the client, in a virtual Erlang machine we write:
```
client:init().
```
and we will have the client connected to the server.

## Communication protocol
The virutal machines act as a server listening on TCP port 8000 (in case of using the same PC, they can listen on different ports).
The communication between client and server is by sending strings on a TCP socket.
The general form of the user's requests to the server is:
```
CMD cmdid op1 op2 ...
```
where CMD are three letters that indicate the operation to be performed followed by an identifier and possibly its arguments. The response of the server is of the form:
```
OK cmdid op1 op2 ...
ERROR cmdid op1 op2 ...
```
where OK indicates that the order identified by cmdid was successful, returning the result if there was an argument and ERROR indicates that there was an error when executing the request.
In the same way, the messages that the server must send to the client will have the form:
```
CMD cmdid op1 op2 ...
```
to which the client must respond with:
```
OK cmdid
```

## Comands

* CON name: Start communication with the server. The client must provide a username. If the name is not in use, the server must respond by accepting the request.
* LSG cmdid: List the available games. These are the ones that are in
and those who are waiting for an opponent.
* NEW cmdid: Create a new game, which will be between the player who starts it and the first one who accepts it.
* ACC cmdid gameid: Accept the game identified by game. The server must answer if the command was successful or not (for example, if someone accepted before).
* PLA cmdid gameid played:Make a move in the game identified by gameid. The play may be to abandon the game. You can return an error if the play is illegal. In case of being accepted, the server must answer with the change in the state of the game.
* OBS cmdid gameid: Ask to watch a game. The server starts sending changes to the game state. The server must answer with the current state of the game.
* LEA cmdid gameid: Stop watching a game.
* BYE: Terminate the connection. Leave all games in which you participate.

The messages that the server sends are:
* UPD cmdid juegoid change: A game update. The observers and the opposing player receive it.

