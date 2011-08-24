#!/bin/bash
#
# Xonotic Server Tools
#
# Version: 0.99 beta          
# Release date: 19. August 2011
# Created by: It'sMe
#
# Required Software: tmux
# Optional Software: perl, git, qstat
#
# Description:
# This script is created to help admins to manage their servers. 
# Every server, which can easily called by its name, will be 
# loaded in its own tmux window. Same for rcon2irc...
# Basically you can...
# start, stop, restart servers and rcon2irc bots
# For more information check --help
#
# Xonotic Server Tools by It'sMe is released under the following License:
# Attribution-NonCommercial-ShareAlike 3.0 Unported (CC BY-NC-SA 3.0)
# http://creativecommons.org/licenses/by-nc-sa/3.0/
# -----------------------------------------------------------------------------
#
# DO NOT EDIT THIS SCRIPT TO CONFIGURE!! 
# Please use the configuration file: xstool.conf
#
#

xstool_dir="$( cd "$( dirname "$0" )" && pwd )"

# check if our configuration is in the right place
if [[ -f "$xstool_dir/configs/xstools.conf" ]]; then
    source $xstool_dir/configs/xstools.conf
else 
    echo -e "xstools.conf not found."
    exit 1
fi

# check some essential variables
function basic_config_check() {
if [[ "$colored_text" == "true" ]]; then
    print_error="\e[0;33m[\e[1;31mERROR\e[0;33m]\e[0m"
    print_attention="\e[0;31m[\e[1;33mATTENTION\e[0;31m]\e[0m"
    print_info="\e[0;34m[\e[1;32mINFO\e[0;34m]\e[0m"
else
    print_error="[ERROR]"
    print_attention="[ATTENTION]"
    print_info="[INFO]"
fi

which tmux >/dev/null 2>&1 || {
    echo -e "$print_error Couln't find tmux, which is required."
    exit 1
}

if [[ "$enable_quakestat" == "true" ]]; then
    which quakestat >/dev/null 2>&1 || {
    echo -e "$print_error Couldn't find quakestat, which is required."
    echo -e "        Please install 'qstat' or disable it in xstools.conf"
    exit 1
}
fi

if [[ -z $userdir ]]; then
    echo -e "$print_error 'userdir' is empty"
    echo -e "        check xstools.conf"
    exit 1
elif [[ -z "$tmux_session" ]]; then
    echo -e "$print_error 'tmux_session' is empty"
    echo -e "        check xstools.conf"
    exit 1
elif [[ -f "$userdir/lock_update" ]]; then
    echo "xstools is locked, because of an update"
    echo "You can use xstools again, when update is done"
    echo "To unlock manual: remove lock_update in your userdir"
    exit 1
fi
} # end of basic_config_check()

# define the commands to start a 'release' server
# also check if basedir exists and files are executable
function version_release_check_and_set() {
    if [[ ! -d $basedir_release ]]; then
        echo -e "$print_error Xonotic release basedir not found."
        echo -e "        check xstools.conf"
        exit 1
    fi
    case "$(uname -m)" in
    x86_64)   executable="xonotic-linux64-dedicated" ;;
    *)        executable="xonotic-linux32-dedicated" ;;
    esac
    if [[ ! -x "$basedir_release/$executable" ]]; then
        echo -e "$print_error $executable is not marked as executable."
        echo -e "        Please fix this."
        exit 1
    fi
    server_command="cd $basedir_release && ./$executable"
} # end of version_release_check_and_set()

# define the commands to start a 'git' server
# also check if basedir exists and files are executable
function version_git_check_and_set() {
    if [[ ! -d $basedir_git ]]; then
        echo -e "$print_error Xonotic git basedir not found."
        echo -e "        check xstools.conf"
        exit 1
    elif [[ ! -x $basedir_git/all ]]; then
        echo -e "$print_error Xonotic 'all' script is not marked as executable."
        echo -e "        Please fix this."
        exit 1
    fi
    server_command="cd $basedir_git && ./all run dedicated"
} # end of version_git_check_and_set()

# analyse given arguments and set 'git' 'release' or 'default' servers for other functions
function version_server_check_and_set() {
case $1 in
    -g)  
    # we have 'git'
    version_git_check_and_set
    # set this variable for other functions
    # we have to reassign the positional parameters to have server names as first argument
    need_shift=yes
        ;;   
    -r)  
    # we have 'release'
    version_release_check_and_set
    # set this variable for other functions
    # we have to reassign the positional parameters to have server names as first argument
    need_shift=yes
        ;;   
    *)  
    # we choose default, which is defined in xstools.conf
    case $default_version in
        git)
        # we have default option 'git'
        version_git_check_and_set
            ;;
        release)
        # we have default option 'release'
        version_release_check_and_set
            ;;
    esac
        ;;
esac
} # end of version_server_check_and_set()

# check if a server name is given, otherwise abort
function server_first_config_check() {
if [[ "$1" == "" ]]; then
    echo "Server name missing. Check -h or --help"
    exit
fi
} # end server_first_config_check()

# check if config file of given server name exists
# and set common used variables
# (use this function only as part of for: for var in $@ blabla)
function server_config_check_and_set() {
if [[ -f $userdir/configs/servers/$1.cfg  ]]; then
    server_name="$1"
    server_config="$server_name.cfg"
    tmux_window="server-$server_name"
    # define our logfile if enabled in config
        if [[ "$set_logfiles" == "true" ]]; then
            if [[ "$logfile_date" == "true" ]]; then
                logfile_format="logs/$server_name.$(date +"%Y%m%d").log"
                logfile_dp_argument="+set log_file $logfile_format"
            else
                logfile_dp_argument="+set log_file logs/${serverconfig}.log"
            fi
        else
            logfile_dp_argument=""
        fi
else
    echo -e "$print_error '$1.cfg' is not placed in 'configs/servers/'."
    echo -e "        Please move the file into this folder."
    continue
fi
} # end of server_config_check_and_set()

# basic function to start servers
function server_start() {
for var in $@; do
# check if $var exists and set our variables:
server_config_check_and_set $var
    # option 1: server is allready running
    # in this case: print error and continue with for loop
    if [[ $(ps -Af | grep "+set serverconfig $server_config" 2>/dev/null |grep -v grep ) ]]; then
        echo -e "$print_attention Server '$server_name' is allready running."
        continue
    fi
    # option 2: server is not running, tmux session does not exist
    # in this case: start a new tmux session with new window and start server
    if [[ ! $(tmux list-sessions 2>/dev/null| grep "$tmux_session:" ) ]]; then
        tmux new-session -d -n $tmux_window -s $tmux_session
        tmux send -t $tmux_session:$tmux_window "$server_command $dp_default_arguments +set serverconfig $server_config $logfile_dp_argument" C-m 
        echo -e "$print_info Server '$server_name' has been started."
    # option 3: server is not running; tmux session exists, and window allready exists
    # in this case: print error and continue with for loop
    elif [[ $(tmux list-windows -t $tmux_session 2>/dev/null | grep "$tmux_window" ) ]]; then
        echo -e "$print_error Server '$server_name' does not run, but tmux window '$tmux_window' exists."
        echo -e "          Use '--view $server_name' to check window status."  
        continue
    else
    # option 4; server is not running, tmux session exists, window does not exists 
    # in this case: start a new window in tmux session and start server
        tmux new-window -d -n $tmux_window -t $tmux_session
        tmux send -t $tmux_session:$tmux_window "$server_command $dp_default_arguments +set serverconfig $server_config $logfile_dp_argument" C-m 
        echo -e "$print_info Server '$server_name' has been started."
fi
done
} # end of server_start()

# start one or more servers 
function server_start_one() {
version_server_check_and_set $1
if [[ "$need_shift" = "yes" ]]; then
    shift
fi
server_first_config_check $1
server_start "$@"
} # end of server_start_one()

# start all servers by searching for configuration files 
# if optional parameter (-r,-g) is given start them as 'release'/'git' servers
# otherwise use default
function server_start_all() {
version_server_check_and_set $1
# (we do not have to reassign parameters, because function uses server config files
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
cfg_name=$(basename ${cfg%\.cfg})
server_start $cfg_name
done
} # end of server_start_all()

# stop one or more servers
function server_stop() {
# 'version_server_check_and_set' not needed for stopping servers
server_first_config_check $1
for var in $@; do
server_config_check_and_set $var
    if [[ $(ps -Af | grep "+set serverconfig $server_config"  2>/dev/null |grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            echo -e "$print_info Stopping server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            sleep 2
            tmux send -t $tmux_session:$tmux_window "exit" C-m
            echo -e "       Server '$server_name' has been stopped."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    else
        echo -e "$print_error Server '$server_name' is not running, cannot stop."
    fi
done
} # end of server_stop()

# function to stop all servers
# if optional parameter (-r,-g) is given only stop 'release'/'git' servers
function server_stop_all() {
version_server_check_and_set $1
# check which servers shall be stopped
if [[ "$1" == "-r" ]]; then
    # we search for release servers
    function ps_spot_server() {
    ps aux |grep "xonotic-linux.*dedicated .* +set serverconfig $server_config" 2>/dev/null |grep -v grep
    }
elif [[ "$1" == "-g" ]]; then
    # we search for git servers
    function ps_spot_server() {
    ps aux | grep "darkplaces/darkplaces-dedicated -xonotic .* +set serverconfig $server_config" 2>/dev/null | grep -v /bin/sh |grep -v grep
    }
else     
    # we search for both (release and git)
    function ps_spot_server() {
    ps aux | grep "+set serverconfig $server_config" 2>/dev/null |grep -v grep
    }
fi
# we can only stop running servers and only those which are in our tmux session
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    server_config_check_and_set $cfg_name
    # nearly the same if statement like server_stop():
    if [[ $(ps_spot_server) ]]; then
         if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            echo -e "$print_info Stopping server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            sleep 2
            tmux send -t $tmux_session:$tmux_window "exit" C-m
            echo -e "       Server '$server_name' has been stopped."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    # else
    #   echo -e "$print_error Server '$server_name' is not running, cannot stop."
    fi
done        
} # end of server_stop_all()

# restart one or more servers
function server_restart() {
# 'version_server_check_and_set' not needed for restarting servers
server_first_config_check $1
for var in $@; do
server_config_check_and_set $var
    # we can only restart a server if server is running and tmux window exists
    if [[ $(ps aux | grep "+set serverconfig $server_config" 2>/dev/null |grep -v grep) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            echo -e "$print_info Restarting server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            sleep 2
            # just run the last used command, so we do not need to know if we started a git or release server before
            tmux send -t $tmux_session:$tmux_window "!!" C-m
            echo -e "       Server '$server_name' has been restarted."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    else
    echo -e "$print_error Server '$server_name' is not running, cannot restart." 
    fi
done
} # end of server_restart()

# function to stop all servers
# if optional parameter (-r,-g) is given only restart 'release'/'git' servers
function server_restart_all() {
version_server_check_and_set $1
# define function to spot running servers 
function ps_spot_server() {
ps aux | grep "darkplaces/darkplaces-dedicated -xonotic .* +set serverconfig $server_config" 2>/dev/null\
 | grep -v /bin/sh |grep -v grep ||\
 ps aux |grep "xonotic-linux.*dedicated .* +set serverconfig $server_config" 2>/dev/null |grep -v grep 
} 
# we need getopts to check arguments
# -c for sending countdown before restarting
# -r/-g 'release'/'git' servers
while getopts ":crg" options; do
    case $options in
        c) send_countdown_=true ;;
        r) 
            # redefine function to spot only release servers
            function ps_spot_server() {
            ps aux |grep "xonotic-linux.*dedicated .* +set serverconfig $server_config" 2>/dev/null |grep -v grep
            }
            # set variable to store information, which servers shall recieve countdown
            # in this case: onlye 'release' servers
            send_countdown_release_only=true
                ;;
        g) 
        # redefine function to spot only release servers
            function ps_spot_server() {
            ps aux | grep "darkplaces/darkplaces-dedicated -xonotic .* +set serverconfig $server_config" 2>/dev/null | grep -v /bin/sh |grep -v grep
            }
            # set variable to store information, which servers shall recieve countdown
            # in this case: onlye 'release' servers
            send_countdown_git_only=true
                ;;
    esac
done
if [[ "$send_countdown_" == "true" ]]; then
    send_countdown
fi
# server_restart_all is based on server_stop_all and server_restart
# we can only restart running servers and only those which are in our tmux session
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    server_config_check_and_set $cfg_name 
    if [[ $(ps_spot_server) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            echo -e "$print_info Restarting server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            sleep 2
            # just run the last used command, so we do not need to know if we start a git or release server
            tmux send -t $tmux_session:$tmux_window "!!" C-m
            echo -e "       Server '$server_name' has been restarted."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done        
} # end of server_restart_all()

# send countdown for servers that will be updated (git) or restarted
function send_countdown() {
# check which servers should recieve countdown
if [[ "send_countdown_release_only=true" == "true" ]]; then
    # we search for release servers
    function ps_spot_server() {
    ps aux |grep "xonotic-linux.*dedicated .* +set serverconfig $server_config" 2>/dev/null |grep -v grep
    }
elif [[ "send_countdown_git_only=true" == "true" ]]; then
    # we just search for git servers
    function ps_spot_server() {
    ps aux | grep "darkplaces/darkplaces-dedicated -xonotic .* +set serverconfig $server_config" 2>/dev/null | grep -v /bin/sh |grep -v grep
    }

else     
    # we search for both
    function ps_spot_server() {
    ps aux | grep "+set serverconfig $server_config" 2>/dev/null |grep -v grep
    }
fi
typeset -a countdown_array
ca_counter=0
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    # search for servers and save them in a field
    if [[ $(ps_spot_server) ]]; then
        server_config_check_and_set $cfg_name 
        if [[ $(tmux list-windows -t $tmux_session 2>/dev/null| grep "$tmux_window") ]]; then
        countdown_array[$ca_counter]=$tmux_window
        ca_counter=$[$ca_counter+1]
        fi
    fi
done
# send countdown to servers
echo -e "$print_info Sending countdown of 15min..."
for var in ${countdown_array[*]}; do
tmux send -t  $tmux_session:$var "say ^4[^1ATTENTION^4] ^3Server will restart in ^115 minutes^3 (updating)" C-m
done
sleep 5m
echo -e "       10min until update..."
for var in ${countdown_array[*]}; do 
tmux send -t $tmux_session:$var "say ^4[^1ATTENTION^4] ^3Server will restart in ^110 minutes^3 (updating)" C-m
done
sleep 5m
echo -e "       5min until update..."
for var in ${countdown_array[*]}; do 
tmux send -t $tmux_session:$var "say ^4[^1ATTENTION^4] ^3Server will restart in ^15 minutess^3 (updating)" C-m
done
sleep 4m
echo -e "       1min until update..."
for var in ${countdown_array[*]}; do 
tmux send -t $tmux_session:$var "say ^4[^1ATTENTION^4] ^3Server will restart in ^11 minute^3 (updating)" C-m 
tmux send -t $tmux_session:$var "say ^4[^1ATTENTION^4] ^3This will force a disconnect" C-m 
done
sleep 55
for var in ${countdown_array[*]}; do 
tmux send -t $tmux_session:$var "say ^4[^1ATTENTION^4] ^3Server will restart in ^15s^3 (updating)" C-m 
tmux send -t $tmux_session:$var "say ^4[^1ATTENTION^4] ^3This will force a disconnect" C-m 
done
sleep 5
} # end of send_countdown()

function update_git() {
cd $basedir_git
./all update $git_update_options && ./all compile $git_compile_options
echo "// this file defines the last update date of your Xonotic git 
// everytime you run an update the date of the builddate-git variable changes
// you can define the date format in configs/xstools.conf
set builddate-git \"$(date +"$git_update_date")\"" > $userdir/configs/servers/common/builddate-git.cfg
} # end of update_git()

# function to update xonotic git
function server_update_git() {
# first check if git is available and if variables are set
which git >/dev/null 2>&1 || {
    echo -e "$print_error Couldn't find git, which is required."
    exit 1
}
if [[ -z $git_compile_options ]]; then
    echo -e "$print_error 'git_compile_options' is empty"
    echo -e "       'dedicated' will be used for this update"
    git_compile_options='dedicated'
elif [[ -z $git_update_options ]]; then
    echo -e "$print_error 'git_update_options' is empty"
    echo -e "       '-l best' will be used for this update"
    git_update_options='-l best'
elif [[ -z $git_update_date ]]; then
    echo -e "$print_error 'git_update_options' is empty"
    echo -e "       date format: $(date +'%d.%m %H:%M %Z') will be used for this update"
    git_update_date='%d.%m %H:%M %Z'
fi
# if we have -c as extra argument, then send countdown
if [[ "$2" == "-c" ]]; then
send_countdown_git_only=true
send_countdown
fi
# close all servers
# this part is baesed on servers_close_all
# we can only stop running servers and only those which are in our tmux session
# counter is used to save all closed servers in a field for restarting later
typeset -a restart_server
counter_stop=0
# lock xstools, when update started 
touch "$userdir/lock_update"
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    server_config_check_and_set $cfg_name 
    # in this case we are looking for git servers, no 'release' servers, therefore stronger pattern
    if [[ $(ps -Af | grep "darkplaces/darkplaces-dedicated -xonotic .* +set serverconfig $server_config"  2>/dev/null |grep -v grep) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then          
            echo -e "$print_info Stopping server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            # we do not need to close our windows, because we will restart
            #sleep 2 
            #tmux send -t $tmux_session:$tmux_window "exit" C-m
            echo -e "       Server '$server_name' has been stopped."
            # remeber this server
            counter_stop=$[$counter_stop+1]
            restart_server[$counter_stop]=$server_name
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done        
# simply update
update_git
# start all servers in our restart_server field
# counter_stop is the number of the last closed server
# we want to restart our first closed server
counter_restart=0
while [ "$counter_restart" -lt "$counter_stop" ]; do
    counter_restart=$[$counter_restart+1]
    server_config_check_and_set ${restart_server[$counter_restart]}
    # we are only restarting git servers here - instead of '!!' we use the full command
    # !! would work, too :)
    tmux send -t $tmux_session:$tmux_window "./all run dedicated $dp_default_arguments +set serverconfig $server_config $logfile_dp_argument" C-m
    echo -e "$print_info Server '$server_name' has been restarted."
done
# unlock xstools 
rm -f "$userdir/lock_update"
} # end of server_update_git()

# function to attach user to tmux window of give server
function server_view() {
server_first_config_check $1
echo -e "$print_info You will be attached to a server window."
if [[ "$tmux_help" == "true" ]]; then
    echo
    echo -e "$print_attention To get out of tmux..."
    echo -e "            hold ctrl, then press b, release them, then press d."
    echo -e "            To scroll..."
    echo -e "            hold ctrl, then press b, release them, then press 'page up'."
    echo -e "            You can scroll with your arrow keys"
    echo -e "            (Press enter to continue...)"
    read # wait until info has been read
fi
for var in $@; do
server_config_check_and_set $var
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            tmux select-window -t $tmux_session:$tmux_window
            tmux attach -t $tmux_session
        else
            echo -e "$print_error tmux window '$tmux_window' does not exist."
            echo -e "          Use '--list' to list all servers running servers."
        fi
done
} # end of server_view()

# list all running servers
function xstools_list_all() {
if [[ $(tmux list-windows -t $tmux_session 2>/dev/null) ]]; then
    activ_server_windows=$(tmux list-windows -t $tmux_session |awk -F\  '$1 ~ /[0-9]+\:/ && $2 ~ /server-.*/ {print $2}' | cut -f2- -d-)
    if [[ -z $activ_server_windows ]]; then
        echo -e "$print_info No servers are running."
    else
        echo -e "$print_info Following servers are running:"
    fi
    for var in $activ_server_windows; do
        server_config_check_and_set $var
        if [[ $(ps -Af | grep "+set serverconfig $server_config"  2>/dev/null|grep -v grep ) ]]; then
        # if you list your servers it could be very nice to check player numbers and server version :) ... so I added it
                if [[ "$enable_quakestat" == "true" ]]; then
                server_port=$(awk '/^port/ {print $2}'  $userdir/configs/servers/$server_config)
                server_players=$(quakestat -nh -nexuizs localhost:$server_port | awk '{print " - "$2" - "}')
                server_version=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{print $6}' | awk -F= '{print $2}' | awk -F: '{print $2}')
                fi
            echo -e "       - $server_name	${server_players}${server_version}"
        else
            echo -e "       - $print_error window: '$tmux_window' has no running server"
            echo -e "                 Use '--view $server_name' to fix it."  
        fi
    done
    # same for rcon2irc bots
    activ_rcon2irc_windows=$(tmux list-windows -t $tmux_session |awk -F\  '$1 ~ /[0-9]+\:/ && $2 ~ /rcon2irc-.*/ {print $2}' | cut -f2- -d-)
    if [[ -z $activ_rcon2irc_windows ]]; then
        echo -e "$print_info No rcon2irc bots are running."
    else
        echo -e "$print_info rcon2irc bots are running:"
    fi
    for var in $activ_rcon2irc_windows; do
        rcon2irc_config_check_and_set $var
        if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
            echo -e "       - $rcon2irc_name"
        else
            echo -e "       - $print_error window: '$tmux_window' has no running rcon2irc bot"
            echo -e "                 Use '--rcon2irc view $rcon2irc_name' to fix it."
        fi
    done
else
    echo -e "$print_info There are no bots/servers running."
fi
} # end of xstools_list_all()

# list all available server config files (not common ones)
function xstools_list_configs() {
echo -e "$print_info You have this server config files in 'scripts/servers'"
for cfg in $(ls $userdir/configs/servers/*.cfg); do
    echo "       - $(basename ${cfg})"
done 
echo -e "$print_info You have this rcon2irc config files in 'scripts/rcon2irc'"
for conf in $(ls $userdir/configs/rcon2irc/*.conf); do
    echo "       - $(basename ${conf})"
done 
} # end of xstools_list_configs

# basic function to print info for running servers
function xstools_print_info() {
server_port=$(awk '/^port/ {print $2}'  $userdir/configs/servers/$server_config)
server_system_info=$( (ps aux |grep "xonotic-linux.*dedicated .* +set serverconfig $server_config" |grep -v 'grep' ||\
ps aux | grep "darkplaces/darkplaces-dedicated -xonotic .* +set serverconfig $server_config" |grep -v 'grep' |grep -v '/bin/sh') |\
awk '{print "CPU: "$3"% \n       Mem: "$4"% \n       PID: "$2}')
echo -e "$print_info Server  : $server_name"
    if [[ "$enable_quakestat" == "true" ]]; then
        server_players=$(quakestat -nh -nexuizs localhost:$server_port | awk '{print $2}')
        server_map=$(quakestat -nh -nexuizs localhost:$server_port | awk '{print $3}')
        server_hostname=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{print $NF}' | awk -F= '{print $2}')
        server_bots=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{ print $4}' | awk -F= '{print $2}')
        server_gametype=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{print $6}' | awk -F= '{print $2}' | awk -F: '{print $1}')
        server_version=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{print $6}' | awk -F= '{print $2}' | awk -F: '{print $2}')
        echo -e "       Hostname: $server_hostname"
        echo -e "       Port    : $server_port"
        echo -e "       Players : $server_players"
        if [[ "$server_bots" != "0" ]]; then
            echo -e "       Bots    : $server_bots"
        fi
        echo -e "       Gametype: $server_gametype"
        echo -e "       Map     : $server_map"
        echo -e "       Version : $server_version"
        echo
        echo -e "       $server_system_info"
        echo
    else
        server_hostname=$(cat $userdir/configs/servers/$server_config  |grep ^hostname | cut -f2- -d " " |tr -d \")
        echo -e "       Hostname: $server_hostname"
        echo -e "       Port    : $server_port" 
        echo -e "       $server_system_info"
        echo
    fi
} # end of xstools_print_info()

# print info for on or more given servers
function server_info() {
server_first_config_check $1
for var in $@; do
server_config_check_and_set $var
    if [[ $(ps -Af | grep "+set serverconfig $server_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
        xstools_print_info
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    else
        echo -e "$print_attention Server '$server_name' was not found."
    fi
done
} # end of server_info()

# print info of all running servers
function server_info_all() {
if [[ $(tmux list-windows -t $tmux_session 2>/dev/null) ]]; then
    activ_server_windows=$(tmux list-windows -t $tmux_session |awk -F\  '$1 ~ /[0-9]+\:/ && $2 ~ /server-.*/ {print $2}' | cut -f2- -d-)
    for var in $activ_server_windows; do
        server_config_check_and_set $var
        if [[ $(ps -Af | grep "+set serverconfig $server_config"  2>/dev/null|grep -v grep ) ]]; then
        xstools_print_info
        fi
    done
else
    echo -e "$print_info There are no servers running."
fi
} # end of server_info_all()

function server_add_pk3() {
# download / move a given pk3 into $userdir/packages
# and send rescan_pending 1 to all servers to search for new added packages
# check if http_server_folder exists if http_server is set to true
if [[ "$http_server" == "true"  ]]; then
    if [[ ! -d $http_server_folder ]]; then
        echo -e "$print_error $http_server_folder does not exist."
        echo -e "        check xstools.conf (http_server_folder)"
        exit
    elif [[ "$http_server_option" != "copy" ]] && [[ "$http_server_option" != "hardlink" ]] && [[ "$http_server_option" != "symlink" ]]; then
        echo -e "$print_error '$http_server_option' is a invalid option."
        echo -e "        check xstools.conf (http_server_option)"
        exit
    fi
fi
# check urls now
for var in $@; do
    echo "$var" | grep -E 'http://.+.pk3' || {
    echo -e "$print_error xstools only accepts pk3 files from a http url."
    echo -e "        No files have been added. Please add them on your own to 'packages'"
    echo -e "        and use '--rescan'"
    exit 1 
}
done
# download all files
for var in $@; do 
    wget --directory-prefix=$userdir/packages -N $var
    # create copy/symlink/hardlink for http server       
    pk3file_name=$(basename $var)
    if [[ "$http_server" == "true" ]]; then
        case $http_server_option in
            copy)
                cp $userdir/packages/$pk3file_name $http_server_folder/$pk3file_name;;
            hardlink)
                ln $userdir/packages/$pk3file_name $http_server_folder/$pk3file_name;;
            symlink)
                ln -s $userdir/packages/$pk3file_name $http_server_folder/$pk3file_name;;
        esac
    fi
done
server_send_rescan
} # end of server_add_pk3()

# send rescan_pending 1 to servers to scan for new added pk3 packages
function server_send_rescan() {
echo -e "$print_info Servers will scan for new packages at endmatch."
echo -e "$print_info 'rescan_pending 1' has been sent to server..."
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    if [[ $(ps -Af | grep "+set serverconfig $cfg_name" 2>/dev/null |grep -v grep) ]]; then
        server_config_check_and_set $cfg_name
        if [[ $(tmux list-windows -t $tmux_session| grep -E "$tmux_window" 2>/dev/null) ]]; then
            tmux send -t $tmux_session:$tmux_window "rescan_pending 1" C-m
            echo -e "       - '$server_name'"
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done
} # end of server_send_rescan()

# send commands to your server via rcon.pl and recieve its output
function server_send_command() {
# check if everything is fine ...
if [[ ! -x $rcon_script ]]; then
    echo -e "$print_error Could not find rcon script."
    echo -e "        Check xstools.conf. Also check flags, need +x"
    exit
elif [[ "$password_file" == "configs" ]]; then
    search_in_configs="true"
elif [[ -f $password_file ]]; then
        search_in_configs="false"
        single_rcon_password=$(awk '/^rcon_password/ {print $2}' $password_file)
else 
    echo -e "$print_error Could not find rcon password(s)."
    echo -e "        Check xstools.conf."
    exit
fi
# check if first argument is a valid config
server_first_config_check $1
# for each server we save a rcon password and port until 'command to send' begins
for var in "$@"; do
    if [[ "$var" == "-c" ]]; then
        shift
        break
    fi
server_config_check_and_set $var
# we use servers config name, to save the port
server_port=$(awk '/^port/ {print $2}' $userdir/configs/servers/$server_config)
# test if we have found a port... simply grep for a field of digits :)
if ! echo $server_port | grep -E '[0-9]{4,5}' >/dev/null 2>&1; then
    echo -e "$print_error Could not find a port in $server_config"
    echo -e "       No command has been sent to any server..." 
    exit
fi
all_server_names="$all_server_names $server_name"
all_server_ports="$all_server_ports $server_port"
# if we have to search the rcon_password in every config file, then...
if [[ $search_in_configs == "true" ]]; then
    rcon_password=$(awk '/^rcon_password/ {print $2}' $userdir/configs/servers/$server_config)
    # test if we have found a rcon_password.... simply test if rcon_password is NOT empty
    if [[ $rcon_password == "" ]]; then
        echo -e "$print_error Could not find a rcon password in $server_config"
        echo -e "       No command has been sent to any server..."
        exit    
    fi
    all_rcon_passwords="$all_rcon_passwords $rcon_password"
    else
        if [[ $single_rcon_password == "" ]]; then
            echo -e "$print_error Could not find a rcon password in your passwords file."
            echo -e "       No command has been sent to any server..."  
            exit
        fi
    all_rcon_passwords="$all_rcon_passwords $single_rcon_password"
    fi
    # if server port is saved, drop it argument, which is the analyzed server
    shift
done
# everything (also -c) is deleted from arguments, our 'command to send' is the rest
my_command="$@"
# now save server names, ports and passwords in an array
a_name=( $all_server_names )
a_port=( $all_server_ports )
a_pass=( $all_rcon_passwords )
counter=0
while [ "$counter" -lt "${#a_name[@]}" ]; do
    echo -e "$print_info Sending command to server '${a_name[$counter]}'..."
    echo
    rcon_address=127.0.0.1:${a_port[$counter]} rcon_password=${a_pass[$counter]} $rcon_script "$my_command"
    echo 
    counter=$[$counter+1]
done
} # end of server_send_command()

# print date/time to server console
# havent known that there is a cvar allready in xonotic :P - timestamps 1 
function server_time2console() {
if [[ -z $date_to_console ]]; then
    echo -e "$print_error 'date_to_console' is empty."
    echo -e "        'date_to_console' is set to '$(date +'%Y%m%d %H:%M %Z')' for run."
    date_to_console='%Y%m%d %H:%M %Z'
    echo
fi
echo -e "$print_info Printing date and time to server output/logs.\n"
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    if [[ $(ps -Af | grep "+set serverconfig $cfg_name" 2>/dev/null |grep -v grep) ]]; then
        server_config_check_and_set $cfg_name 
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            tmux send -t $tmux_session:$tmux_window "echo ====== $(date +"$date_to_console") ======" C-m
            echo -e "$print_info 'time/date for server console/logs' has been sent to server '$server_name'"
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done
} # end of server_time2console()

# set a new logfile for all servers
function server_set_logfile() {
echo -e "$print_info New logfile set for server:"
log_date=$(date +"%Y%m%d")
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    if [[ $(ps -Af | grep "+set serverconfig $cfg_name" 2>/dev/null |grep -v grep) ]]; then
        server_config_check_and_set $cfg_name 
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            logfile_format="logs/$server_name.$log_date.log"
            tmux send -t $tmux_session:$tmux_window "log_file \"$logfile_format\"" C-m
            echo -e "       - $server_name"
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done
}

# end of function for servers 
# begin of functions for rcon2irc bots
# rcon2irc funtion have a similiar syntax like server functions

function rcon2irc_first_config_check() {
if [[ "$1" == "" ]]; then
    echo "Bot name missing. Check -h or --help"
    exit
fi
} # end of rcon2irc_first_config_check()

function rcon2irc_config_check_and_set() {
# (use this function only as part of for: for var in $@ blabla)
if [[ -f $userdir/configs/rcon2irc/$1.rcon2irc.conf  ]]; then
    rcon2irc_name="$1"
    rcon2irc_config="$rcon2irc_name.rcon2irc.conf"
    tmux_window="rcon2irc-$rcon2irc_name"
    rcon2irc_config_folder="$userdir/configs/rcon2irc"
else
    echo -e "$print_error '$1.rcon2irc.conf' is not placed in 'configs/rcon2irc/'."
    echo -e "        Please move the file into this folder."
    continue
fi
} # end of rcon2irc_config_check_and_set()

function rcon2irc_check_start() {
# check if rcon2irc has been started successfull othewise tell 'Use --rcon2irc view...'
# it seems that we need a small time periode until process is in process list ps -Af
sleep 1
if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
    echo -e "$print_info rcon2irc '$rcon2irc_name' has been started."
else
    echo -e "$print_error Starting rcon2irc '$rcon2irc_name' failed."
    echo -e "        Use '--rcon2irc view $rcon2irc_name' to check window status/error message"
fi
} # end of rcon2irc_check_start()       

function rcon2irc_start() {
rcon2irc_first_config_check $1
for var in $@; do
# check if $var exists and set our variables:
rcon2irc_config_check_and_set $var
    # option 1: rcon2irc is allready running
    # in this case: print error and continue with for loop
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
        echo -e "$print_attention rcon2irc '$rcon2irc_name' is allready running."
        continue
    fi
    # option 2: rcon2irc is not running, tmux session does not exist
    # in this case: start a new tmux session, with new window and start rcon2irc
    if [[ ! $(tmux list-sessions 2>/dev/null| grep "$tmux_session:" ) ]]; then
        tmux new-session -d -n $tmux_window -s $tmux_session
        tmux send -t $tmux_session:$tmux_window "cd $rcon2irc_config_folder && perl $rcon2irc_script $rcon2irc_config" C-m 
        rcon2irc_check_start 
    # option 3: rcon2irc is not running; tmux session exists, and window allready exists
    # in this case: print error and continue with for loop
    elif [[ $(tmux list-windows -t $tmux_session 2>/dev/null | grep "$tmux_window" ) ]]; then
        echo -e "$print_error rcon2irc '$rcon2irc_name' does not run, but tmux window '$tmux_window' exists."
        echo -e "        Use '--rcon2irc view $rcon2irc_name' to check window status."  
        continue
    else
    # option 4; rcon2irc is not running, tmux session exists, window does not exists 
    # in this case: start a new window in tmux session and start rcon2irc
        tmux new-window -d -n $tmux_window -t $tmux_session
        tmux send -t $tmux_session:$tmux_window "cd $rcon2irc_config_folder && perl $rcon2irc_script $rcon2irc_config" C-m 
        rcon2irc_check_start
    fi
done
} # end of rcon2irc_start()

function rcon2irc_start_all() {
 for conf in $(ls $userdir/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
 conf_name=$(basename ${conf%\.rcon2irc.conf})
 rcon2irc_start $conf_name
 done
} # end of rcon2irc_start_all()

function rcon2irc_stop() {
rcon2irc_first_config_check $1
for var in $@; do
rcon2irc_config_check_and_set $var
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            rcon_pid=$(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep | awk '{print $2}')
            echo -e "$print_info Stopping rcon2irc '$rcon2irc_name'..."
            kill -9 $rcon_pid
            sleep 1
            tmux send -t $tmux_session:$tmux_window "exit" C-m 
            echo -e "       rcon2irc '$rcon2irc_name' has been stopped."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but rcon2irc '$rcon2irc_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi  
    else
        echo -e "$print_attention rcon2irc '$rcon2irc_name' was not found."
    fi  
done
} # end of rcon2irc_stop()

function rcon2irc_stop_all() {
# we can only stop running rcon2irc bots and only those which are in our tmux windows
for conf in $(ls $userdir/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
    conf_name=$(basename ${conf%\.rcon2irc.conf})
    rcon2irc_config_check_and_set $conf_name
# nearly the same if statement like rcon2irc_stop
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            rcon_pid=$(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep | awk '{print $2}')
            echo -e "$print_info Stopping rcon2irc '$rcon2irc_name'..."
            kill -9 $rcon_pid
            sleep 1
            tmux send -t $tmux_session:$tmux_window "exit" C-m 
            echo -e "       rcon2irc '$rcon2irc_name' has been stopped."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but rcon2irc '$rcon2irc_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi  
    #else
    #    echo -e "$print_attention rcon2irc '$rcon2irc_name' was not found."
    fi  
done
} # end of rcon2irc_stop_all()

function rcon2irc_restart() {
rcon2irc_first_config_check $1
for var in $@; do
rcon2irc_config_check_and_set $var
    # We can only restart a server if server is running and tmux session exists
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
            rcon_pid=$(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep | awk '{print $2}')
            echo -e "$print_info Restarting rcon2irc '$rcon2irc_name'..."
            kill -9 $rcon_pid
            sleep 1
            tmux send -t $tmux_session:$tmux_window "perl $rcon2irc_script $rcon2irc_config" C-m
            sleep 1
            if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
                echo -e "       rcon2irc '$rcon2irc_name' has been restarted."
            else
                echo -e "$print_error Starting rcon2irc '$rcon2irc_name' failed."
                echo -e "        Use '--rcon2irc view $rcon2irc_name' to check window status/error message"
            fi
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$rcon2irc_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    else
    echo -e "$print_error rcon2irc '$rcon2irc_name' is not running, cannot stop." 
    fi
done
} # end of rcon2irc_restart()

function rcon2irc_restart_all() {
for conf in $(ls $userdir/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
    conf_name=$(basename ${conf%\.rcon2irc.conf})
    rcon2irc_config_check_and_set $conf_name 
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null |grep -v grep) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "$tmux_window" 2>/dev/null) ]]; then
            rcon_pid=$(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep | awk '{print $2}')
            echo -e "$print_info Restarting rcon2irc '$rcon2irc_name'..."
            kill -9 $rcon_pid
            sleep 1
            tmux send -t $tmux_session:$tmux_window "perl $rcon2irc_script $rcon2irc_config" C-m
            sleep 1
            if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
                echo -e "       rcon2irc '$rcon2irc_name' has been restarted."
            else
                echo -e "$print_error Starting rcon2irc '$rcon2irc_name' failed."
                echo -e "        Use '--rcon2irc view $rcon2irc_name' to check window status/error message"
            fi
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$rcon2irc_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done
} # end of rcon2irc_restart_all() {

function rcon2irc_view() {
rcon2irc_first_config_check $1
echo -e "$print_info You will be attached to a rcon2irc window:"
if [[ "$tmux_help" == "true" ]]; then
    echo
    echo -e "$print_attention To get out of tmux..."
    echo -e "            hold ctrl, then press b, release them, then press d."
    echo -e "            To scroll..."
    echo -e "            hold ctrl, then press b, release them, then press 'page up'."
    echo -e "            You can scroll with your arrow keys"
    echo "            (Press enter to continue...)"
    read # wait until info has been read
fi
for var in $@; do
rcon2irc_config_check_and_set $var
    if [[ $(tmux list-windows -t $tmux_session| grep "$tmux_window" 2>/dev/null) ]]; then
        tmux select-window -t $tmux_session:$tmux_window
        tmux attach -t $tmux_session
    else
        echo -e "$print_error tmux window '$tmux_window' does not exist."
        echo -e "        Use '--list' to list all running bots."
    fi
done
} # end of rcon2irc_view

# end of rcon2irc functions

function install_git() {
which git >/dev/null 2>&1 || {
    echo -e "$print_error Couldn't find git, which is required."
    exit 1
}
    echo "Xonotic git install process started"
    sleep 1
    echo "Xonotic git will be installed into $basedir_git"
    echo "To choose another folder, edit 'configs/xstools.conf'"
    sleep 1
    read -p 'Do you wish to continue? Type "yes": ' answer_install
    if [[ "$answer_install" == "yes" ]]; then
        echo "Installing process takes some time..."
        echo 'Get a cup of coffee :)'
        echo
        echo
        sleep 2
        git clone git://git.xonotic.org/xonotic/xonotic.git $basedir_git
        update_git
        echo
        echo
        echo 'Download complete.'
        exit
    else
        echo "Abort."
    exit 1      
    fi
}

function install_release() {
    echo "Please download and extract Xonotic on your own."
    echo "Then fix 'basedir_release' in xstools.conf"
}

# help functions:

function xstools_help() {
cat << EOF
-- Commands --
xstools
    --install-git               - download xonotic git into basedir 
    --start-all                 - start all servers
    --start <server(s)>         - start servers
    --stop-all                  - stop all servers
    --stop <server(s)>          - stop servers
    --restart-all               - restart all servers
                                  optional argument '-c' to send countdown
    --restart <server(s)>       - restart-servers
    
     start-all/start/stop-all/restart-all support an optional argument
     '-r' or '-g'

    --update-git                - update git and restart git servers
                                  optional argument '-c' to send countdown   
    --list                      - list running servers/rcon2irc bots
    --list-configs              - list server and rcon2irc configs
    --info <server(s)>          - show info about server(s)
    --info-all                  - show info about all server(s)    
    --view <server(s)>          - view server console
    --add-pk3 <url(s)>          - add pk3 files from given urls
    --rescan                    - rescan for new added packages
    --send <server(s)>  -c ...  - send a command to given server(s)
    --time2console              - print date/time to server console
    --set-logfile               - set a new logfile for all servers

    --rcon2irc                  syntax: --rcon2irc command <bot(s)>
        start-all               - start all rcon2irc bots
        start <bot(s)>          - start rcon2irc bots
        stop-all                - stop all rcon2irc bots
        stop <bot(s)>           - stop rcon2irc bots
        restart-all             - restart all rcon2irc bots
        restart <bot(s)>        - restart rcon2irc bots
        view <bot(s)>           - view rcon2irc console

    --help                      - print full help
    -h                          - print this help
EOF
}

function xstools_more_help() {
cat << EOF
Xonotic Server Tools is a collection of functions to manage many different
servers by loading every single server in a seperate tmux window. You can 
easily control those servers by their names. This script supports 'release'
and 'git' servers.

----- Important Usage Notes

Xonotic Server Tools recognize your server configuration files in 
'configs/servers' by their file extension .cfg. The name of the server 
is created by the file name without extension. 
That is "config_file%\.cfg". The name of the tmux window has a 
prefix "server-".
Example: Configuration file: my-server.cfg
         Server name: my-server      Window name: my-server
rcon2irc files are recogized by .rcon2irc.conf. The name of the rcon2irc bot 
is created by the filename without extension, too. 
That is "config_file%\.rcon2irc.conf". The name of the tmux window has a 
prefix "rcon2irc-".
Exampe: Congiguration file: my-bot.rcon.cfg
        rcon2irc bot name: my-bot    Window name: rcon-my-bot

----- Functions

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

--restart-all -c        Same as --restart-all, but with a countdown of 15min.
                        This countdown will be sent to players as a message.

--restart <server(s)>   Restart specific server(s).

start-all/start/stop-all/restart-all support an optional argument '-r' or '-g'.
If you use -r (-g) as argument for start functions, xstools will start
'release' ('git') servers. Otherwise default will be used (check xstools.conf).
Example: xstools --start -g server1 
          (start server1 as git server)
          xstools --start-all -r 
          (start all servers, which are not running, as 'release' server)
 If you use -r (-g) as argument for restart functions, xstools will only restart
 'release' ('git') servers.
 If you use -r (-g) as argument for stop functios, xstools will only stop
 'release' ('git') servers.

--update-git            Update Xonotic git and restart all servers.

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
                        Server.

--send <server(s)>      Send a command to given servers and recieve output.
      -c <command>      The beginning of command is defined by -c.                  
                        

--time2console          Print date/time to server console. This gives a better 
                        overview, when parsing output or logs. Very usefull as 
                        part of crontab.
                        Instead of using this function (as part of your crontab)
                        you can use the cvars 'timestamps' and 'timeformat'.

--set-logfile           Change the logfile of all running servers to 
                        'serverconfig.date.log', where 'serverconfig' is the
                        server name  and 'date' is 'YearMonthDay'. 

--rcon2irc              <syntax> --rcon2irc command <bot(s)>
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


--help                  print this help

-h                      print a list of available functions

A wiki can be found here: https://github.com/itsme-/xstools/wiki
Report bugs here: https://github.com/itsme-/xstools/issues

Created by: It'sMe
For any questions and help join #xstools, quakenet (IRC)

EOF
}

function rcon2irc_control() {
if [[ ! -f "$rcon2irc_script" ]]; then
    echo -e "$print_error could not find 'rcon2irc_script'."
    echo -e "        check xstools.conf"
    exit 1
fi
case $1 in
 start)              shift && rcon2irc_start $@;;
 stop)               shift && rcon2irc_stop $@;;
 restart)            shift && rcon2irc_restart $@;;
 stop-all)           rcon2irc_stop_all;;
 start-all)          rcon2irc_start_all;;
 restart-all)        rcon2irc_restart_all;;
 view)               shift && rcon2irc_view $@;;
 ""|*)             echo -e "$print_info Command is invalid or missing."
                     echo "       Use --rcon2irc with one of this arguments:"
                     echo "           start-all"
                     echo "           start <bot(s)>"           
                     echo "           stop-all"
                     echo "           stop <bots>"
                     echo "           restart-all"
                     echo "           restart <bot(s)>"
                     echo "           view <bot(s)>";;
esac
}

case $1 in
 --install-git|install-git)          basic_config_check; install_git;;
 --start-all|start-all)              basic_config_check; shift && server_start_all "$@";;
 --start|start)                      basic_config_check; shift && server_start_one "$@";;
 --stop-all|stop-all)                basic_config_check; shift && server_stop_all "$@";;
 --stop|stop)                        basic_config_check; shift && server_stop "$@";;
 --restart-all|restart-all)          basic_config_check; shift && server_restart_all "$@";;
 --restart|restart)                  basic_config_check; shift && server_restart "$@";;
 --update-git|update-git)            basic_config_check; server_update_git "$@";;
 --list|list)                        basic_config_check; xstools_list_all;;
 --list-configs|list-configs)        basic_config_check; xstools_list_configs;;
 --info|info)                        basic_config_check; shift && server_info $@;;
 --info-all|info-all)                basic_config_check; server_info_all "$@";;
 --view|view)                        basic_config_check; shift && server_view "$@";;
 --add-pk3|add-pk3)                  basic_config_check; shift && server_add_pk3 "$@";;
 --rescan|rescan)                    basic_config_check; server_send_rescan;;
 --send|send)                        basic_config_check; shift && server_send_command "$@";;
 --time2console|time2console)        basic_config_check; server_time2console;;
 --set-logfile|set-logfile)          basic_config_check; server_set_logfile;;
 --rcon2irc|rcon2irc)                basic_config_check; shift && rcon2irc_control "$@";;
 --help|--usage|help|ụsage)          xstools_more_help;;
 -h|h)                               xstools_help;;
 "")                                 echo "xstools needs an argument, check -h or --help";;
 *)                                  echo "This is not a valid argument! Check -h or --help";;
esac    

