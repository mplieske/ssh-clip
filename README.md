# ssh-clip

This portable tool wraps netcat and ssh, so you can connect to a remote host via ssh and copy stdout streams of remote processes to you local clipboard.

This tool consists of two parts:

1. ssh-clip (client side)
1. ssh-kopy (remote host)

## Prerequisites

* **Local machine:** xclip
* **Remote host:** ssh server, netcat (nc)

## ssh-clip

ssh-clip is a portable bash function.

As long as you have nc and xclip available everything should work.

ssh-clip listens to the given port on --local-port and forwards everything into your clipboard. So do not expose you computer to the outside world while using this, and do not use it from the server side. Only use ssh-kopy from the server side.
I use the ssh port redirection feature, to actually get the information from the connected host over the network.

When connecting to the remote host, a bash script `~/.local/bin/ssh-kopy` will be created. So ssh-clip installs ssh-kopy on the remote host automatically. It also ensures, that ~/.local/bin/ssh-kopy is on the PATH for the duration of the session.

**Usage:**

```bash
ssh-copy -hrlnu
```

**Options**

| long          | short | description                                                                                                                                                                 | example                                      |
|---------------|-------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------|
| --help        | -h    | Shows the help text. Other options will be ignored. (Optional)                                                                                                              | ssh-clip -h                                  |
| --hostname    | -n    | The hostname of the remote host to connect to via ssh. (Mandatory)                                                                                                          | ssh-clip -n fedora.fritz.box -l 8888         |
| --local-port  | -l    | The local port to use for the ssh-clip connection. Either --local-port or --remote-port or both have to be set. If one of them are omitted, both default to the given port. | ssh-clip -n fedora.fritz.box -l 8888         |
| --remote-port | -r    | Same spiel as for local port but on the remote host.                                                                                                                        | ssh-clip -n fedora.fritz.box -l 8888 -r 8889 |
| --user        | -u    | The user name to connect with on the ssh session. (Optional)                                                                                                                | ssh-clip -u tux -n fedora.fritz.box -r 8888  |

## ssh-kopy

ssh-kopy, as described, is a bashscript that will be automatically created on the remote host, when connecting to it via ssh-clip.

The script will only be present for the duration of the session. After exiting from the ssh session, another short ssh command will be executed, to delete the file again, to prevent litering your system.

**Usage:**

ssh-kopy takes input from stdin and sends it to your local machine via netcat (nc) using the port redirection feature of ssh.

So basically you can pipe the stdout of other processes or stream files or multiline strings with cat, echo, etc. to ssh-kopy.

Example:
```
cat ~/.ssh/id_ed25519.pub | ssh-kopy
```

