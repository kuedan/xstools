#!/bin/bash
#
# Xonotic Server Tools
#
# Version: 0.95 beta          
# Release date: 09. August 2011
# Created by: It'sMe
#
# Required Software: tmux
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

if [[ -f "$xstool_dir/configs/xstools.conf" ]]; then
source $xstool_dir/configs/xstools.conf
else 
echo -e "$print_error xstools.conf not found"
exit 1
fi


function big_config_check() {
if [[ "$colored_text" == "true" ]]; then
    print_error="\e[0;33m[\e[1;31mERROR\e[0;33m]\e[0m"
    print_attention="\e[0;31m[\e[1;33mATTENTION\e[0;31m]\e[0m"
    print_info="\e[0;34m[\e[1;32mINFO\e[0;34m]\e[0m"
else
    print_error="[ERROR]"
    print_attention="[ATTENTION]"
    print_info="[INFO]"
fi

which git >/dev/null 2>&1 || {
    echo -e "$print_error Couldn't find git, which is required."
}
which tmux >/dev/null 2>&1 || {
    echo -e "$print_error Couln't find tmux, which is required."
    exit 1
}

if [[ "$enable_quakestat" == true ]]; then
    which quakestat >/dev/null 2>&1 || {
    echo -e "$print_error Couldn't find quakestat, which is required."
    echo -e "        Please install 'qstat' or disable it in xstools.conf"
    exit 1
}
fi

if [[ ! "$basedir" ]]; then
    echo blah
    echo -e "$print_error 'basedir' is empty"
    echo -e "        check xstools.conf"
    exit 1
elif [[ ! "$userdir" ]]; then
    echo -e "$print_error 'userdir' is empty"
    echo -e "        check xstools.conf"
    exit 1
elif [[ ! "$tmux_session" ]]; then
    echo -e "$print_error 'tmux_session' is empty"
    echo -e "        check xstools.conf"
    exit 1
elif [[ ! "$git_compile_options" ]]; then
    echo -e "$print_error 'git_compile_options' is empty"
    echo -e "        check xstools.conf"
    exit 1
elif [[ ! "$rcon2irc_script" ]]; then
    echo -e "$print_error 'rcon2irc_script' is empty."
    echo -e "        check xstools.conf"
    exit 1
elif [[ ! "$date_to_console" ]]; then
    echo -e "$print_error 'date_to_console' is empty."
    echo -e "        check xstools.conf"
    exit 1
    echo -e
elif [[ -f "$userdir/lock_update" ]]; then
    echo "xstools is locked, because of an update"
    echo "You can use xstools again, when update is done"
    echo "To unlock manual: remove lock_update in your userdir"
    exit 1
fi

if [[ "$1" != "--install" ]]; then

    if [[ ! -d $userdir ]]; then
        echo -e "$print_error Xonotic user folder not found."
        echo -e "        check xstools.conf"
        exit 1
    elif [[ ! -d $basedir ]]; then
        echo -e "$print_error Xonotic git folder not found."
        echo -e "        check xstools.conf"
        exit 1
    fi
fi
}

function update_git() {
cd $basedir
./all update $git_update_options && ./all compile $git_compile_options
echo "// this file will defines the last update date of your Xonotic git 
// everytime you run an update the date of the builddate-git variable changes
// you can define the date format in configs/xstools.conf
set builddate-git \"$(date +"$git_update_date")\"" > $userdir/configs/servers/common/builddate-git.cfg
}

function install_git() {
    echo "Xonotic git install process started"
    sleep 1
    echo "Xonotic git will be installed into $basedir"
    echo "To choose another folder, edit 'configs/xstools.conf'"
    sleep 1
    read -p 'Do you wish to continue? Type "yes": ' answer_install
    if [[ "$answer_install" == "yes" ]]; then
        echo "Installing process takes some time..."
        echo 'Get a cup of coffee :)'
        echo
        echo
        sleep 2
        git clone git://git.xonotic.org/xonotic/xonotic.git $basedir
        update_git
        echo
        echo
        echo 'Download complete.'
        exit
    else
        echo "Aborting."
    exit 1      
    fi
}

function server_check_argument() {
if [[ "$1" == "" ]]; then
    echo "Server name missing. Check -h or --help"
    exit
fi
}

function server_check_and_set() {
 # use this function only as part of for: for var in $@ blabla
 if [[ -f $userdir/configs/servers/$1.cfg  ]]; then
    server_name="$1"
    server_config="$server_name.cfg"
    tmux_window="server-$server_name"
    # define our logfile
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
}

function send_countdown() {
# countdown
echo -e "$print_info Sending countdown of 15min..."
typeset -a countdown_array
ca_counter=0
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})                                                                                                                  
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $cfg_name"  2>/dev/null |grep -v grep) ]]; then
        server_check_and_set $cfg_name 
        if [[ $(tmux list-windows -t $tmux_session 2>/dev/null| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]") ]]; then
        countdown_array[$ca_counter]=$tmux_window
        ca_counter=$[$ca_counter+1]
        fi
    fi
done

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
}

function server_start() {
server_check_argument $1
for var in $@; do
# check if $var exists and set our variables:
server_check_and_set $var
    # option 1: server is allready running
    # in this case: print error and coninue with for loop
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config" 2>/dev/null |grep -v grep ) ]]; then
        echo -e "$print_attention Server '$server_name' is allready running."
        continue
    fi
    # option 2: server is not running, tmux session does not exist
    # in this case: start a new tmux session, with new window and start server
    if [[ ! $(tmux list-sessions 2>/dev/null| grep "$tmux_session:" ) ]]; then
        tmux new-session -d -n $tmux_window -s $tmux_session
        tmux send -t $tmux_session:$tmux_window "cd $basedir &&\
./all run dedicated $dp_default_arguments +set serverconfig $server_config $logfile_dp_argument" C-m 
        echo -e "$print_info Server '$server_name' has been started."
    
    # option 3: server is not running; tmux session exists, and window allready exists
    # in this case: print error and continue with for loop
    elif [[ $(tmux list-windows -t $tmux_session 2>/dev/null | grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" ) ]]; then
        echo -e "$print_error Server '$server_name' does not run, but tmux window '$tmux_window' exists."
        echo -e "        Use '--view $server_name' to check window status."  
        continue
    else
    # option 4; server is not running, tmux session exists, window does not exists 
    # in this case: start a new window in tmux session and start server
        tmux new-window -d -n $tmux_window -t $tmux_session
        tmux send -t $tmux_session:$tmux_window "cd $basedir &&\
./all run dedicated $dp_default_arguments +set serverconfig $server_config $logfile_dp_argument" C-m 
        echo -e "$print_info Server '$server_name' has been started."
        continue
fi
done
}

function server_stop() {
server_check_argument $1
for var in $@; do
server_check_and_set $var
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
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
        echo -e "$print_attention Server '$server_name' was not found."
    fi
done
}

function server_start_all() {
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
cfg_name=$(basename ${cfg%\.cfg})
server_start $cfg_name
done
}

function server_stop_all() {
# we can only stop running servers and only those which are in our tmux session
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    server_check_and_set $cfg_name
# same if statement like server_stop but commented else of first if statement
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config" 2>/dev/null |grep -v grep) ]]; then
         if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            echo -e "$print_info Stopping server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            sleep 2
            tmux send -t $tmux_session:$tmux_window "exit" C-m
            echo -e "       Server '$server_name' has been stopped."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
#    else
#        echo -e "$print_attention No server '$server_name' was found."
    fi
done        
}

function server_restart() {
server_check_argument $1
for var in $@; do
server_check_and_set $var
    # We can only restart a server if server is running and tmux session exists
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            echo -e "$print_info Restarting server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            sleep 2
            tmux send -t $tmux_session:$tmux_window "./all run dedicated $dp_default_arguments +set serverconfig $server_config $logfile_dp_argument" C-m
            echo -e "       Server '$server_name' has been restarted."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    else
    echo -e "$print_error Server '$server_name' is not running, cannot restart." 
    fi
done
}



function server_restart_all() {
# xstools_restart_all is based on xstools_stop_all
# we can only restart running servers and only those which are in our tmux session
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    server_check_and_set $cfg_name 
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config"  2>/dev/null |grep -v grep) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            echo -e "$print_info Restarting server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            sleep 2
            tmux send -t $tmux_session:$tmux_window "./all run dedicated $dp_default_arguments +set serverconfig $server_config $logfile_dp_argument" C-m
            echo -e "       Server '$server_name' has been restarted."
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done        
}

function server_update_all() {
# simply close all
# not thaaaaat simply -.-, we have to remember running servers :/
# this part is baesed on xstools_close_all
# we can only stop running servers and only those which are in our tmux session
# counter is used to save all closed servers in a field for restarting later
typeset -a restart_server
counter_stop=0
# lock xstools, when update started 
touch "$userdir/lock_update"
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    server_check_and_set $cfg_name 
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config"  2>/dev/null |grep -v grep) ]]; then
        echo $server_config
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then          
            echo -e "$print_info Stopping server '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit" C-m
            # we do not need to close our sessions..., because we will restart again
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
# counter is the number of the last closed server
# we want to restart our first closed server
counter_restart=0
while [ "$counter_restart" -lt "$counter_stop" ]; do
    counter_restart=$[$counter_restart+1]
    server_check_and_set ${restart_server[$counter_restart]}
    tmux send -t $tmux_session:$tmux_window "./all run dedicated $dp_default_arguments +set serverconfig $server_config $logfile_dp_argument" C-m
            echo -e "$print_info Server '$server_name' has been restarted."
done
# unlock xstools 
rm -f "$userdir/lock_update"
}

function server_update_all_countdown() {
 send_countdown
 server_update_all
}

function server_restart_all_countdown() {
 send_countdown
 server_restart_all
}

function server_view() {
server_check_argument $1
echo -e "$print_info You will be attached to a server window."
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
server_check_and_set $var
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            tmux select-window -t $tmux_session:$tmux_window
            tmux attach -t $tmux_session
        else
            echo -e "$print_error tmux window '$tmux_window' does not exist."
            echo -e "        Use '--list' to list all servers running servers."
        fi
done
}

function xstools_list_all() {
 if [[ $(tmux list-windows -t $tmux_session 2>/dev/null) ]]; then
    activ_server_windows=$(tmux list-windows -t $tmux_session |awk -F\  '$1 ~ /[0-9]+\:/ && $2 ~ /server-.*/ {print $2}' | awk -F"-" '{print $2}')
    echo -e "$print_info Following servers are running:"
    for var in $activ_server_windows; do
        server_check_and_set $var
        if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config"  2>/dev/null|grep -v grep ) ]]; then
        # if u list your servers it could be very nice to check player numbers :) ... so we directly add it here
                if [[ "$enable_quakestat" == "true" ]]; then
                server_port=$(awk '/^port/ {print $2}'  $userdir/configs/servers/$server_config)
                server_players=$(quakestat -nh -nexuizs localhost:$server_port | awk '{print "("$2")"}')
                fi
            echo -e "       - $server_name $server_players"
        else
            echo -e "       - $print_error window: '$tmux_window' has no running server"
            echo -e "               Use '--view $server_name' to fix it."
        
        fi
    done
    activ_rcon2irc_windows=$(tmux list-windows -t $tmux_session |awk -F\  '$1 ~ /[0-9]+\:/ && $2 ~ /rcon2irc-.*/ {print $2}' | awk -F"-" '{print $2}')
    echo -e "$print_info Following rcon2irc bots are running:"
    for var in $activ_rcon2irc_windows; do
        rcon2irc_check_and_set $var
        if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
            echo -e "       - $rcon2irc_name"
        else
            echo -e "       - $print_error window: '$tmux_window' has no running rcon2irc bot"
            echo -e "               Use '--rcon2irc view $rcon2irc_name' to fix it."
        fi
    done
 
 else
    echo -e "$print_info There are no bots/servers running."
 fi
}

function xstools_list_configs() {
 echo -e "$print_info You have this server config files in 'scripts/servers'"
 for cfg in $(ls $userdir/configs/servers/*.cfg); do
 echo "       - $(basename ${cfg})"
 done 
 echo -e "$print_info You have this rcon2irc config files in 'scripts/rcon2irc'"
 for conf in $(ls $userdir/configs/rcon2irc/*.conf); do
 echo "       - $(basename ${conf})"
 done 
}

function xstools_print_info() {
            server_port=$(awk '/^port/ {print $2}'  $userdir/configs/servers/$server_config)
            server_system_info=$(ps aux | grep "darkplaces/darkplaces-dedicated -xonotic $dp_default_arguments +set serverconfig $server_config" | grep -v 'grep' |grep -v '/bin/sh' | awk '{print "CPU: "$3"% \n       Mem: "$4"% \n       PID: "$2}')
            echo -e "$print_info Server  : '$server_name'"
            if [[ "$enable_quakestat" == "true" ]]; then
                server_players=$(quakestat -nh -nexuizs localhost:$server_port | awk '{print $2}')
                server_map=$(quakestat -nh -nexuizs localhost:$server_port | awk '{print $3}')
                server_hostname=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{print $NF}' | awk -F= '{print $2}')
                server_bots=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{ print $4}' | awk -F= '{print $2}')
                server_gametype=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{print $6}' | awk -F= '{print $2}' | awk -F: '{print $1}')
                echo -e "       Hostname: $server_hostname"
                echo -e "       Port    : $server_port"
                echo -e "       Players : $server_players"
                if [[ "$server_bots" != "0" ]]; then
                    echo -e "       Bots    : $server_bots"
                fi
                echo -e "       Gametype: $server_gametype"
                echo -e "       Map     : $server_map"
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
}

function server_info() {
server_check_argument $1
for var in $@; do
server_check_and_set $var
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
        xstools_print_info
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    else
        echo -e "$print_attention Server '$server_name' was not found."
    fi
done
}

function server_info_all() {
 if [[ $(tmux list-windows -t $tmux_session 2>/dev/null) ]]; then
    activ_server_windows=$(tmux list-windows -t $tmux_session |awk -F\  '$1 ~ /[0-9]+\:/ && $2 ~ /server-.*/ {print $2}' | awk -F"-" '{print $2}')
    for var in $activ_server_windows; do
        server_check_and_set $var
        if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $server_config"  2>/dev/null|grep -v grep ) ]]; then
        xstools_print_info
        fi
    done
 else
    echo -e "$print_info There are no servers running."
 fi
}

function server_add_pk3() {
# download / move a given pk3 into packages
# send rescan_pending 1 to all servers
# check if http_server_folder exists if http_server is set to true
if [[ "$http_server" == "true"  ]]; then
    if [[ ! -d $http_server_folder ]]; then
        echo -e "$print_error $http_server_folder does not exist"
        echo -e "        Check xstools.conf (http_server_folder)"
        exit
    elif [[ "$http_server_option" != "copy" ]] && [[ "$http_server_option" != "hardlink" ]] && [[ "$http_server_option" != "symlink" ]]; then
        echo -e "$print_error '$http_server_option' is a invalid option"
        echo -e "        Check xstools.conf (http_server_option)"
        exit
    fi
fi

# check urls now
for var in $@; do
 echo "$var" | grep -E 'http://.+.pk3' || {
 echo -e "$print_error xstools only accepts pk3 files from a http url." &&
 echo -e "        No files have been added. Please add them on your own to 'packages'," &&
 echo -e "        and use '--scan-pk3'" &&
 exit 1 
 }
done

# download all files
for var in $@; do 
    wget --directory-prefix=$userdir/packages -N $var       
    pk3file_name=$(basename $var)
    # ONLY CREATE SYMLINK IF CURL SERVER IS AVAILABLE 
    # NEEDS TO BE IMPLEMENTED
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
}

function server_send_rescan() {
echo -e "$print_info Servers will scan for new packages at endmatch.\n"
echo -e "$print_info 'rescan_pending 1' has been sent to server..."
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $cfg_name"  2>/dev/null |grep -v grep) ]]; then
        server_check_and_set $cfg_name
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            tmux send -t $tmux_session:$tmux_window "rescan_pending 1" C-m
            echo -e "       - '$server_name'"
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done
}

function server_time2console() {
echo -e "$print_info Printing date and time to server output/logs.\n"
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $cfg_name"  2>/dev/null |grep -v grep) ]]; then
        server_check_and_set $cfg_name 
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            tmux send -t $tmux_session:$tmux_window "echo ====== $(date +"$date_to_console") ======" C-m
            echo -e "$print_info 'time/date for server console/logs' has been sent to server '$server_name'"
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done
}

function server_set_logfile() {
echo -e "$print_info Set new logfile for servers.\n"
log_date=$(date +"%Y%m%d")
for cfg in $(ls $userdir/configs/servers/*.cfg 2>/dev/null); do
    cfg_name=$(basename ${cfg%\.cfg})
    if [[ $(ps -Af | grep "./all run dedicated $dp_default_arguments +set serverconfig $cfg_name"  2>/dev/null |grep -v grep) ]]; then
        server_check_and_set $cfg_name 
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            logfile_format="logs/$server_name.$log_date.log"
            tmux send -t $tmux_session:$tmux_window "log_file \"$logfile_format\"" C-m
            echo -e "$print_info New logfile set for '$server_name'"
        else
            echo -e "$print_error tmux window '$tmux_window' does not exists, but server '$server_name' is running."
            echo -e "        You have to fix this on your own, sorry."
        fi
    fi
done
}

function rcon2irc_check_argument() {
if [[ "$1" == "" ]]; then
    echo "Bot name missing. Check -h or --help"
    exit
fi
}

function rcon2irc_check_and_set() {
 # use this function only as part of for: for var in $@ blabla
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
}

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
}        

function rcon2irc_start() {
rcon2irc_check_argument $1
for var in $@; do
# check if $var exists and set our variables:
rcon2irc_check_and_set $var
    # option 1: rcon2irc is allready running
    # in this case: print error and coninue with for loop
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
    elif [[ $(tmux list-windows -t $tmux_session 2>/dev/null | grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" ) ]]; then
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
}

function rcon2irc_stop() {
rcon2irc_check_argument $1
for var in $@; do
rcon2irc_check_and_set $var
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
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
}

function rcon2irc_start_all() {
 for conf in $(ls $userdir/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
 conf_name=$(basename ${conf%\.rcon2irc.conf})
 rcon2irc_start $conf_name
 done
}

function rcon2irc_stop_all() {
# we can only stop running servers and only those which are in our tmux session
for conf in $(ls $userdir/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
    conf_name=$(basename ${conf%\.rcon2irc.conf})
    rcon2irc_check_and_set $conf_name
# same if statement like server_stop but but uncommented else of first if statement
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
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
}

function rcon2irc_restart() {
rcon2irc_check_argument $1
for var in $@; do
rcon2irc_check_and_set $var
    # We can only restart a server if server is running and tmux session exists
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
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
}

function rcon2irc_restart_all() {
# xstools_restart_all is based on xstools_stop_all
# we can only restart running servers and only those which are in our tmux session
for conf in $(ls $userdir/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
    conf_name=$(basename ${conf%\.rcon2irc.conf})
    rcon2irc_check_and_set $conf_name 
    if [[ $(ps -Af | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null |grep -v grep) ]]; then
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
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
}

function rcon2irc_view() {
rcon2irc_check_argument $1
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
rcon2irc_check_and_set $var
        if [[ $(tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" 2>/dev/null) ]]; then
            tmux select-window -t $tmux_session:$tmux_window
            tmux attach -t $tmux_session
        else
            echo -e "$print_error tmux window '$tmux_window' does not exist."
            echo -e "        Use '--list' to list all running bots."
        fi
done
}

function xstools_help() {
cat << EOF
-- Commands --
xstools
    --install                   - download xonotic git into basedir 
    --start-all                 - start all servers
    --start <server(s)>         - start servers
    --stop-all                  - stop all servers
    --stop <server(s)>          - stop servers
    --restart-all               - restart all servers
    --restart-all-c             - + send countdown of 15min
    --restart <server(s)>       - restart-servers
    --update-all                - update git and restart all servers
    --update-all-c              - + send countdown of 15min
    --list                      - list running servers/rcon2irc bots
    --list-configs              - list server and rcon2irc configs
    --info <server(s)>          - show info about server(s)
    --info-all                  - show info about all server(s)    
    --view <server(s)>          - view server window
    --add-pk3 <url(s)>          - add pk3 files from given urls
    --rescan                    - rescan for new added packages
    --time2console              - print date/time to server console
    --set-logfile               - set a new logfile for all servers

    --rcon2irc                  syntax: --rcon2irc command <bot(s)>
        start-all               - start all rcon2irc bots
        start <bot(s)>          - start rcon2irc bots
        stop-all                - stop all rcon2irc bots
        stop <bot(s)>           - stop rcon2irc bots
        restart-all             - restart all rcon2irc bots
        restart <bot(s)>        - restart rcon2irc bots
        view <bot(s)            - view rcon2irc window

    --help                      - print full help
    -h                          - print this help
EOF
}
    
function xstools_more_help() {
cat << EOF
Xonotic Server Tools is a collection of functions to manage many different
servers by loading every single server in a seperate tmux window. You can 
easily control those servers by their names. In current release this script
only supports Xonotic git servers.

Created by: It'sMe
For any questions, help, and reporting bugs, join #xstools, quakenet (IRC)

----- Important Usage Notes

Xonotic Server Tools recognize your server configuration files in 
'configs/servers' by their file extension .cfg. The name of the server 
is created by the file name without extension. 
That is "config_file%\.cfs". The name of the tmux window has a 
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

--install               Download Xonotic Git and save it in the given 'basedir' 
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

--restart-all-c         Same as --restart-all, but with a countdown of 15min.
                        This countdown will be sent to players as a message.

--restart <server(s)>   Restart specific server(s).

--update-all            Update Xonotic git and restart all servers.

--update-all-c          Same as --update-all, but with a countdown of 15min
                        This countdown will be sent to players as a message.

--list                  List all running servers and bots.

--list-configs          List all server and rcon2irc configuration files.

--info                  Show informations like hostname, port.... of server(s).
                        If qstat is enabled you will get more informations.

--info-all              Same as --info, but this lists info for all servers.

--view <server(s)>      Attach a tmux window and show server window of server(s).

--add-pk3 <url(s)>      Add .pk3 files to 'packages' from given urls and rescan 
                        for them at endmatch with every server.

--rescan                Rescan for new added packages at endmatch with every 
                        Server.

--time2console          Print date/time to server console. This gives a better 
                        overview, when parsing output or logs. Very usefull as 
                        part of crontab.
                        Instead of using this function (as part of your crontab)
                        you can use the cvars 'timestamps' and 'timeformat'.

--set-logfile           Change the logfile of all running servers to 
                        'serverconfig.date.log', where 'serverconfig' is the
                        server name  and 'date' is 'YearMonthDay'. 

--rcon2irc              <syntax> --rcon2irc command <bot(s)
                        command is one of the following options:
       
      start-all         Start all rcon2irc bots, whose configuration files are
                        are placed in 'configs/rcon2irc'. Those configuration 
                        files are recognized by their extenstion .rcon2irc.conf

      start <bot(s)>    same as --rcon-start-all, but you can specify bot(s)

      stop-all          Stop all currently running bots. Those servers must
                        run in the defined tmux session. Otherwise xstools 
                        cannot stop them.

      stop <bot(s)>     Stop specific bot(s).

      restart-all       Restart all running bot(s).

      restart <bot(s)>  Restart rcon2irc specific bot(s).

      view <bot(s)      Attach a tmux window and show bot window of bot(s).


--help                  print this help

-h                      print a list of available functions

EOF
}
function rcon2irc_control() {
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
 --install)                 big_config_check; install_git;;
 --start-all)               big_config_check; server_start_all;;
 --start)                   big_config_check; shift && server_start "$@";;
 --stop-all)                big_config_check; server_stop_all;;
 --stop)                    big_config_check; shift && server_stop "$@";;
 --restart-all)             big_config_check; server_restart_all;;
 --restart-all-c)           big_config_check; server_restart_all_countdown;;
 --restart)                 big_config_check; shift && server_restart "$@";;
 --update-all)              big_config_check; server_update_all;;
 --update-all-c)            big_config_check; server_update_all_countdown;;
 --list)                    big_config_check; xstools_list_all;;
 --list-configs)            big_config_check; xstools_list_configs;;
 --info)                    big_config_check; shift && server_info $@;;
 --info-all)                big_config_check; server_info_all;;
 --view)                    big_config_check; shift && server_view "$@";;
 --add-pk3)                 big_config_check; shift && server_add_pk3 "$@";;
 --rescan)                  big_config_check; server_send_rescan;;
 --time2console)            big_config_check; server_time2console;;
 --set-logfile)             big_config_check; server_set_logfile;;
 --rcon2irc)                big_config_check; shift && rcon2irc_control "$@";;
 --help | --usage)          xstools_more_help;;
 -h)                        xstools_help;;
 "")                        echo "xstools needs an argument, check -h or --help";;
 *)                         echo "This is not a valid argument! Check -h or --help";;
esac    

