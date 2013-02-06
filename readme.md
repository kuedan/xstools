# Xonotic Server Tools
Created by: It'sMe

Xonotic Server Tools is a collection of functions to manage several [Xonotic](http://www.xonotic.org) servers by loading each server in a seperate [tmux](http://tmux.sourceforge.net/) window. Server admins can call those servers by their name. The script supports *release*, *autobuild* and *git* servers. Next to servers Xonotic Server Tools can manage rcon2irc bots, too. The script also offers a extended folder tree to organize your configuration files, logs and pk3 packages.
All adjustments can be made in the basic configuration file: **xstools.conf**.

## Commands

```
    --start-all <-agr>               - start all servers
    --start <-agr> <server(s)>       - start servers
    --stop-all <-agreqnw>            - stop all servers
    --stop <-eqnw> <server(s)>      - stop servers
    --restart-all <-agrnqs>          - restart all servers
    --restart <-nqs> <server(s)>    - restart-servers

    --install-git                   - download xonotic git into basedir
    --update-git <-nqs>             - update git and restart git servers
    --update-autobuild <-nqs>       - update autobuild and update
                                      autobuild servers

    --list                           - list running servers/rcon2irc bots
    --list-configs                   - list server and rcon2irc configs
    --attach <server(s)>             - attach server console
    --add-pk3 <-p> <url(s)>          - add pk3 files from given urls
    --rescan                         - rescan for new added packages
    --send-all <command>             - send a command to all servers
    --send <server(s)> -c <command>  - send a command to given server(s)
    --logs set/ del <-d>             - set a new log file for all servers,
                                       delete log files in data folder (-d)
                                       older than given days
    --maplist <-agrdp>                - create maplist for all gametypes based
                                       on data (-d) and package folder (-p),
                                       also supports regex.
    --mapinfo                   syntax: --rcon2irc command <options> <pk3(s)>
        extract <-d>            - extract mapinfo files of given pk3 packages
                                  to data folder (-d)
        diff <-d>               - show difference between mapinfo in pk3 and
                                  data folder (-d)
        diff-all <-dp>          - show the difference between mapinfo in pk3s
                                  in package folder (-p) and data folder (-d)
        fix <-dp>               - fix server console warnings by mapinfo files
                                  in data folder (-d) and in pk3s of package
                                  folder (-p)
        show                    - show mapinfo files of given pk3 package

    --rcon2irc                  syntax: --rcon2irc command <bot(s)>
        start-all               - start all rcon2irc bots
        start <bot(s)>          - start rcon2irc bots
        stop-all                - stop all rcon2irc bots
        stop <bot(s)>           - stop rcon2irc bots
        restart-all             - restart all rcon2irc bots
        restart <bot(s)>        - restart rcon2irc bots
        attach <bot(s)>         - attach rcon2irc console

    --help                      - print full help for functions
    -h                          - print this help
```

## Extended Folder Tree

```
      ├── configs
      │   ├── rcon2irc         - your rcon2irc configuration files
      │   └── servers          - your individual server configuration files
      │       └── common       - your 'common' server configuration files
      ├── data                 - the default 'data' folder
      │   ├── logs             - all generated logs will be here
      │   └── maps             - the default map folder - add your mapinfo files here
      ├── logs -> data/logs/   - just a symlink 
      └── packages             - place your packages (.pk3) here
```

Use the following extenstions for your configs: 

- Server configuration files: .cfg

- Rcon2irc configuration files: .rcon2irc.conf

## Dependencies

- Required Software: A linux or unix based operating system, bash, tmux, gawk

- Optional Software: git, perl, qstat, rsync


## Documentation

Check this [Documentation](http://lcbx.dyndns.org/xonotic/xstools).

For any questions or help, join [#xstools, quakenet](http://webchat.quakenet.org/?channels=xstools) (IRC).

