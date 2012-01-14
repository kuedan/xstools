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


----- Version: 0.99 beta 
      Created by: It'sMe
                  
      For any questions and help, join #xstools, quakenet (IRC).

----- Required Software: tmux
      Optional Software: perl  (for rcon2irc)
                         git   (for running 'git' servers)
                         qstat (to list server informations)

----- Description:
      Xonotic Server Tools is a collection of functions to manage many different
      servers by loading every single server in a seperate tmux window. You can 
      easily control those servers by their names. This script supports Xonotic 
      release and git servers.
      Next to managing servers and rcon2irc bots Xonotic Server Tools supports
      a more extended home folder tree, but it still supports 'the default'.
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

      If the 'Xonotic Server Tools' should be able to recongize your configuration 
      files then use for Xonotic servers .cfg and for rcon2irc .rcon2irc.conf as file 
      extension.
        
----- General Usage:
      xstools
        --install-git           Download Xonotic Git and save it in the given 'basedir' 
                                folder. Check xtools.conf to adjust this.

        --start-all             Start all servers whose configuration files are placed
                                in 'configs/servers'. Those configuration files are 
                                recognized by their extension .cfg.

        --start <server(s)>     Same as --start-all, but you can specify server(s).

        --stop-all              Stop all currently running servers. Those servers must
                                run in the defined tmux session. Otherwise xstools 
                                cannot stop them.

        --stop <server(s)>      Stop specific server(s).

        --restart-all           Restart all running server(s).

        --restart <server(s)>   Restart specific server(s).

        --start-all/--start/--stop-all/--restart-all support -r and -g as optional
        argument.
        If you use -r (-g) as argument for --start-all or --start , xstools will start
        'release' ('git') servers. Otherwise default will be used (check xstools.conf).
        Example: xstools --start -g server1 
                  (start server1 as git server)
                  xstools --start-all -r 
                  (start all servers, which are not running, as 'release' servers)
        If you use -r (-g) as argument for --restart-all, xstools will restart
        'release' ('git') servers only.
        If you use -r (-g) as argument for --stop-all, xstools will stop
        'release' ('git') servers only.

        start-all/start support the option -i to disable or enable a unique session id 
        per config. The argument of -i must be 'true' to enable a session id per config,
        or 'false' to disable.

        stop-all/stop/restart-all/restart support -c as optional argument to send a
        countdown of 15min before servers are stopped or restarted.

        --update-git            Update Xonotic git and restart git servers.

        --update-git -c         Same as --update-all, but with a countdown of 15min
                                This countdown will be sent to players as a message.

        --list                  List all running servers and bots.

        --list-configs          List all server and rcon2irc configuration files.

        --info <server(s)>      Show informations like hostname, port.... of server(s).
                                If qstat is enabled you will get more informations.

        --info-all              Same as --info, but this lists info for all servers.

        --view <server(s)>      Attach a tmux window and show server console of server(s).

        --add-pk3 <url(s)>      Add .pk3 files to 'packages' from given urls and rescan 
                                for them at endmatch with every server.

        --rescan                Rescan for new added packages at endmatch with every 
                                server.

        --send-all <command>    Send a command to all servers and receive output.

        --send <server(s)>      Send a command to given servers and receive output.
              -c <command>      The beginning of command is defined by -c.

        --time2console          Print date/time to server console. This gives a better 
                                overview, when parsing output or logs. Very usefull as 
                                part of crontab.
                                Instead of using this function (as part of your crontab)
                                you can use the cvars 'timestamps' and 'timeformat'.

        --logs set              Change the logfile of all running servers to 
                                'serverconfig.date.log', where 'serverconfig' is the
                                server name  and 'date' is 'YearMonthDay'. 

        --logs del              Delete older log files in 'logs/' than given time in days.

        --maplist               Create a maplist for all gamtypes or use a regex.
                                Examples:
                                ctf          --maplist ctf
                                ctf,lms,dm   --maplist '(ctf|lms|\bdm)'

        --mapinfo               Syntax: --mapinfo command <pk3(s)>
                                command is one of the following options:
        
            extract <pk3(s)>    Extract mapinfo files of given pk3 package(s)
                                to 'data/maps/'.

            extract-all         Extract all mapinfo files of pk3 packages in 'packages/'
                                and its subfolders to 'data/maps/'.
    
            diff <pk3(s)>       Show difference between pk3 package mapinfo
                                and mapinfo file in 'data/maps/'.
    
            diff-all            Same as 'diff' but for all pk3 packages in 'packages' 
                                and its subdirs. No output if comparing was not possible.
                                No output if mapinfo files are the same.

            fix                 Fix server console warnings by mapinfo files:
                                Replace 'type' with 'gametype' and copy autogenerated
                                mapinfo files to 'data/maps/'.
    
            show <pk3(s)>       Show mapinfo file of given pk3 package and mapinfo file 
                                in 'data/maps/'.

        --rcon2irc              Syntax: --rcon2irc command <bot(s)>
                                command is one of the following options:
       
             start-all          Start all rcon2irc bots, whose configuration files
                                are placed in 'configs/rcon2irc'. Those configuration 
                                files are recognized by their extenstion .rcon2irc.conf.

             start <bot(s)>     Same as --rcon-start-all, but you can specify bot(s).

             stop-all           Stop all currently running bots. Those servers must
                                run in the defined tmux session. Otherwise xstools 
                                cannot stop them.

             stop <bot(s)>      Stop specific bot(s).

             restart-all        Restart all running bot(s).

             restart <bot(s)>   Restart rcon2irc specific bot(s).

             view <bot(s)>      Attach a tmux window and show bot console of bot(s).


        --help                  Print this help.

        -h                      Print a list of available functions.

----- Installation:
      For installation please read the INSTALL file. 

----- Common Important Usage Notes:
      Xonotic Server Tools recognize your server configuration files in 
      'configs/servers' by their file extension .cfg. The name of the server 
      is created by the file name without extension. 
      That is "config_file%\.cfg". The name of the tmux window has a 
      prefix "server-".
      rcon2irc files are recogized by .rcon2irc.conf. The name of the rcon2irc bot 
      is created by the filename without extension, too. 
      That is "config_file%\.rcon2irc.conf". The name of the tmux window has a 
      prefix "rcon2irc-".
----- rcon2irc Important Usage Notes:
      If you are loading extra plugins in your .rcon2irc.conf configuration file
      ... then use the full path '/home/user/..../plugin.pl' 
      ... or put them into 'configs/rcon2irc' folder.
```
