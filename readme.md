``` 
                      __  __                 _   _      
                      \ \/ /___  _ __   ___ | |_(_) ___ 
                       \  // _ \| '_ \ / _ \| __| |/ __|
                       /  \ (_) | | | | (_) | |_| | (__ 
                      /_/\_\___/|_| |_|\___/ \__|_|\___|
             ____                             _____           _     
            / ___|  ___ _ ____   _____ _ __  |_   _|__   ___ | |___ 
            \___ \ / _ \ '__\ \ / / _ \ '__|   | |/ _ \ / _ \| / __|
             ___) |  __/ |   \ V /  __/ |      | | (_) | (_) | \__ \
            |____/ \___|_|    \_/ \___|_|      |_|\___/ \___/|_|___/


----- Version: 0.2 
      Created by: It'sMe
                  
      For any questions or help, join #xstools, quakenet (IRC).

----- Required Software: tmux
                         gawk
      Optional Software: perl  (for rcon2irc)
                         git   (for running 'git' servers)
                         qstat (to list server informations)

----- Description:
      Xonotic Server Tools is a collection of functions to manage different
      Xonotic servers by loading every single server in a seperate tmux window.
      You can easily control those servers by their names. This script supports
      Xonotic release and git servers.
      Next to managing servers and rcon2irc bots Xonotic Server Tools supports
      a more extended home folder tree, but also 'the default'.
      The new folder tree gives a better overview of your server files:
      'pk3' packages, log files, server configuration files ... 

      ├── configs
      │   ├── rcon2irc         - your rcon2irc configuration files
      │   └── servers          - your individual server configuration files
      │       └── common       - your 'common' server configuration files
      ├── data                 - the default 'data' folder
      │   ├── logs             - all generated logs will be here
      │   └── maps             - the default map folder - add your mapinfo files here
      ├── logs -> data/logs/   - just a symlink 
      └── packages             - place your packages (.pk3) here

      Use the following extenstions for your configs:
      Server configuration files: .cfg
      Rcon2irc configuration files: .rcon2irc.conf

---- Functions:
        
    --install-git           Download Xonotic Git and save it in the given basedir
                            folder. Check xtools.conf to adjust this.

    --start-all             Start all servers whose configuration files are placed
                            in 'configs/servers'.
      Options:   -r         Start all servers as release servers.
                 -g         Start all servers as git servers.
                            (otherwise use default)
    
    --start <server(s)>     Start specific server(s).
      Options:   -r         Start given servers as release servers.
                 -g         Start given servers as git servers.
                            (otherwise use default)

    --stop-all              Stop all running servers..
      Options:  -r          command only affects release servers.
                -g          command only affects git servers.
                            (otherwise command affects all servers)

    --stop <server(s)>      Stop specific server(s).

    Options for both stop functions:
                -c          Send a countdown of 10min before quit.
                -q <server> Quit server at endmatch and redirect all players
                            to given server (hostname+port).
                -n          Optional parameter in combination with -q. Directly
                            quit, do not wait for endmatch.
                -e          Quit server when empty and next level starts.
                -w          Optional parameter in combination with -q. xstools

    --restart-all           Restart all running server(s).
      Options:  -r          command only affects release servers.
                -g          command only affects git servers.
                            (otherwise command affects all servers)

    --restart <server(s)>   Restart specific server(s).

    Options for both restart functions:
                -c          Send a countdown of 10min before restart.
                -q <server> Restart server at endmatch and redirect all players
                            to given server (hostname+port).
                -s          Restart server at endmatch at let all players reconnect.
                -n          Optional parameter in combination with -q or -s.
                            Directly restart, do not wait for endmatch.

    --update-git            Update Xonotic git and restart all servers.
      Options:  -c          Send a countdown of 10min before restart.
                -s          Restart at endmatch and let all players reconnect.
                -n          Optional parameter in combination with -s.
                            Directly restart, do not wait for endmatch.

    --list                  List all running servers and bots.

    --list-configs          List all server and rcon2irc configuration files.

    --view <server(s)>      Attach a tmux window and show server console of
                            server(s).

    --add-pk3 <url(s)>      Add .pk3 files to 'packages' from given urls and rescan
                            for them at endmatch with every server.

    --rescan                Rescan for new added packages at endmatch, every server

    --send-all <command>    Send a command to all servers and receive output.

    --send <server(s)>      Send a command to given servers and receive output.
          -c <command>      The beginning of command is defined by -c.

    --logs set              Change the log file of all running servers to 
                            'serverconfig.date.log', where 'serverconfig' is the
                            server name  and 'date' is 'YearMonthDay'. 

    --logs del              Delete older log files in 'logs/' than given time in
                            days. Check xstools.conf to adjust this.

    --maplist               Create a maplist for all gamtypes or use a regex.
                            Examples:
                            ctf          --maplist ctf
                            ctf,lms,dm   --maplist '(ctf|lms|\bdm)'

    --mapinfo               Syntax: --mapinfo command <pk3(s)>
                            command is one of the following options:

            extract <pk3(s)>    Extract mapinfo files of given pk3 package(s)
                                to 'data/maps/'.

            extract-all     Extract all mapinfo files of pk3 packages in 'packages'
                            and its subfolders to 'data/maps/'.

            diff <pk3(s)>   Show difference between pk3 package mapinfo
                            and mapinfo file in 'data/maps/'.

            diff-all        Same as 'diff' but for all pk3 packages in 'packages' 
                            and its subdirs. No output if comparing was not possible
                            No output if mapinfo files are the same.

            fix             Fix server console warnings by mapinfo files:
                            Replace 'type' with 'gametype'
                            Replace long gametype names with short ones
                            and copy autogenerated mapinfo files to 'data/maps/'.

            show <pk3(s)>   Show mapinfo file of given pk3 package and mapinfo file
                            in 'data/maps/'.

    --rcon2irc              Syntax: --rcon2irc command <bot(s)>
                            command is one of the following options:

        start-all         Start all rcon2irc bots, whose configuration files
                          are placed in 'configs/rcon2irc'. Those configuration 
                          files are recognized by their extenstion .rcon2irc.conf

        start <bot(s)>    same as --rcon-start-all, but you can specify bot(s)

        stop-all          Stop all currently running bots. Those servers must
                          run in the defined tmux session. Otherwise xstools 
                          cannot stop them.

        stop <bot(s)>     Stop specific bot(s).

        restart-all       Restart all running bot(s).

        restart <bot(s)>  Restart rcon2irc specific bot(s).

        view <bot(s)>     Attach a tmux window and show bot console of bot(s).

----- Common Important Usage Notes:
    Server configuration files in are recognized by the extension .cfg and
    must be placed in 'configs/servers'. The name of the server is created by
    the file name without extension. That is "config_file%\.cfg".
    The name of the tmux window has a prefix "server-".
    Example: Configuration file: my-server.cfg
             Server name: my-server      Window name: server-my-server
    rcon2irc configuration files  are recogized by the extension .rcon2irc.conf
    and must be placed in 'configs/rcon2irc'. The name of the rcon2irc bot is
    created by without extension. That is "config_file%\.rcon2irc.conf".
    The name of the tmux window has a prefix "rcon2irc-".
    Exampe: Congiguration file: my-bot.rcon.cfg
            rcon2irc bot name: my-bot    Window name: rcon2irc-my-bot

----- rcon2irc Important Usage Notes:
      If you are loading extra plugins in your .rcon2irc.conf configuration file
      ... then use the full path '/home/user/..../plugin.pl' 
      ... or put them into 'configs/rcon2irc' folder.
```
