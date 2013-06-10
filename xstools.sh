#!/bin/bash
#
# Xonotic Server Tools
# https://github.com/itsme-/xstools
#
# Version: 0.5
# Created by: It'sMe
#
# Xonotic Server Tools by It'sMe is released under the following License:
# Attribution-NonCommercial-ShareAlike 3.0 Unported (CC BY-NC-SA 3.0)
# http://creativecommons.org/licenses/by-nc-sa/3.0/
#
# THIS SOFTWARE IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT
# ANY WARRANTY. IT IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
# EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK
# AS TO THE QUALITY AND PERFORMANCE OF THIS SOFTWARE IS WITH YOU.
# -----------------------------------------------------------------------------
#
# DO NOT EDIT THIS SCRIPT TO CONFIGURE!!
# Please use the configuration file: xstools.conf
# -----------------------------------------------------------------------------

xstool_dir="$( cd "$( dirname "$0" )" && pwd )"

# check if config is available
if [[ -f "$xstool_dir/configs/xstools.conf" ]]; then
    source "$xstool_dir/configs/xstools.conf"
else
    echo >&2 "xstools.conf not found."
    exit 1
fi

### --- basic functions
# {{{

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

which tmux &>/dev/null || {
    echo >&2 -e "$print_error Couln't find tmux, which is required."
    exit 1
}

which gawk &>/dev/null || {
    echo >&2 -e "$print_error Couln't find gawk, which is required."
    exit 1
}

if [[ "$enable_quakestat" == "true" ]]; then
    which quakestat &>/dev/null || {
    echo >&2 -e "$print_error Couldn't find quakestat, which is required."
    echo >&2 -e "        Please install 'qstat' or disable it in xstools.conf"
    exit 1
}
fi

if [[ -z "$userdir" ]]; then
    echo >&2 -e "$print_error 'userdir' is empty"
    echo >&2 -e "        Check xstools.conf"
    exit 1
elif [[ -z "$tmux_session" ]]; then
    echo >&2 -e "$print_error 'tmux_session' is empty"
    echo >&2 -e "        Check xstools.conf"
    exit 1
elif [[ -f "$userdir/lock_update" ]]; then
    echo >&2 "xstools is locked, because of a git update."
    echo >&2 "You can use xstools again, when update is done."
    echo >&2 "To unlock manual: remove lock_update in your userdir."
    exit 1
fi
} # end of basic_config_check()

# check and set xonotic release stuff
function version_release_check_and_set() {
    if [[ ! -d "$basedir_release" ]]; then
        echo >&2 -e "$print_error Xonotic release basedir not found."
        echo >&2 -e "        Check xstools.conf"
        exit 1
    fi
    case "$(uname -m)" in
    x86_64)   executable="xonotic-linux64-dedicated";;
    *)        executable="xonotic-linux32-dedicated";;
    esac
    if [[ ! -x "$basedir_release/$executable" ]]; then
        echo >&2 -e "$print_error $executable is not marked as executable."
        echo >&2 -e "        Please fix this."
        exit 1
    fi
    server_command="cd \"$basedir_release\" && ./$executable"
} # end of version_release_check_and_set()

function version_autobuild_check_and_set() {
    if [[ ! -d "$basedir_autobuild" ]]; then
        echo >&2 -e "$print_error Xonotic autobuild basedir not found."
        echo >&2 -e "        Check xstools.conf"
        exit 1
    fi
    case "$(uname -m)" in
    x86_64)   executable="xonotic-linux64-dedicated";;
    *)        executable="xonotic-linux32-dedicated";;
    esac
    if [[ ! -x "$basedir_autobuild/$executable" ]]; then
        echo >&2 -e "$print_error $executable is not marked as executable."
        echo >&2 -e "        Please fix this."
        exit 1
    fi
    # make sure we are able to differ release and autobuild executable
    if [[ -z $update_autobuild ]]; then
        [[ -x "$basedir_autobuild/$executable-autobuild" ]] ||\
            ln -f "$basedir_autobuild/$executable" "$basedir_autobuild/$executable-autobuild"
    fi
    server_command="cd \"$basedir_autobuild\" && ./$executable-autobuild"
} # end of version_release_check_and_set()

# check and set xonotic git stuff
function version_git_check_and_set() {
    if [[ ! -d "$basedir_git" ]]; then
        echo >&2 -e "$print_error Xonotic git basedir not found."
        echo >&2 -e "        Check xstools.conf"
        exit 1
    elif [[ ! -x $basedir_git/all ]]; then
        echo >&2 -e "$print_error Xonotic 'all' script is not marked as executable."
        echo >&2 -e "        Please fix this."
        exit 1
    fi
    server_command="cd \"$basedir_git\" && ./all run dedicated"
} # end of version_git_check_and_set()

# }}}

### --- install/update functions
# {{{

function update_autobuild() {
echo "// this file defines the last update date of your Xonotic autobuild
// everytime you run an update the date of the update_autobuild variable changes
// you can define the date format in configs/xstools.conf
set update_autobuild \"$(date +"$autobuild_update_date")\"" > "$userdir/configs/servers/common/update_autobuild.cfg" &&
$autobuild_update_script
}

function update_git() {
cd "$basedir_git"
echo "// this file defines the last update date of your Xonotic git repo
// everytime you run an update the date of the update_git variable changes
// you can define the date format in configs/xstools.conf
set update_git \"$(date +"$git_update_date")\"" > "$userdir/configs/servers/common/update_git.cfg" &&
./all update $git_update_options &&
./all compile $git_compile_options
} # end of update_git()

function install_git() {
which git &>/dev/null || {
    echo >&2 -e "$print_error Couldn't find git, which is required."
    exit 1
}
    echo "Xonotic git install process started."
    sleep 1
    echo "Xonotic git will be installed into $basedir_git"
    echo "To choose another folder, edit 'configs/xstools.conf.'"
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
        echo 'Download and compile complete.'
        exit
    else
        echo >&2 "Abort."
        exit 1
    fi
}

# }}}

### --- server functions
# {{{

# check if config is given
function server_first_config_check() {
if [[ "$1" == "" ]]; then
    echo >&2 -e "$print_error Server name missing. Check -h or --help"
    exit 1
fi
} # end server_first_config_check()

# check given config, set logfile
function server_config_check_and_set() {
if [[ -f "$userdir/configs/servers/$1.cfg"  ]]; then
    server_name="$1"
    server_config="$server_name.cfg"
    tmux_window="server-$server_name"
    # log file settings
    if [[ "$set_logs" == "true" ]]; then
        if [[ "$logs_date" == "true" ]]; then
            log_format="logs/${server_name}_$(date +%F).log"
            log_dp_argument="+set log_file $log_format"
        else
            log_dp_argument="+set log_file logs/$server_name.log"
        fi
    else
        log_dp_argument=""
    fi
else
    echo >&2 -e "$print_error No config file available for '$1'"
    exit 1
fi
} # end of server_config_check_and_set()

function pgrep_server() {
    ps o cmd | grep "+set serverconfig $server_config" |grep -v grep
}
function pgrep_server_release() {
    ps o cmd |grep "xonotic-linux.*-dedicated .* +set serverconfig $server_config" |grep -v grep
}
function pgrep_server_autobuild() {
    ps o cmd |grep "xonotic-linux.*-dedicated-autobuild .* +set serverconfig $server_config" |grep -v grep
}
function pgrep_server_git() {
    ps o cmd | grep "darkplaces/darkplaces-dedicated -xonotic.* +set serverconfig $server_config" |grep -v /bin/sh |grep -v grep
}

# basic function to start servers
function server_start() {
if [[ -f "$xstool_dir/configs/server_paths.conf" ]]; then
    echo -e "$print_info xstools uses server_paths.conf"
    source "$xstool_dir/configs/server_paths.conf"
    function_get_dp_default_arguments=true
fi
for var in $@; do
    server_config_check_and_set $var
    if [[ $function_get_dp_default_arguments == true ]]; then
        get_dp_default_arguments $server_name
    fi
    dp_default_arguments_bak="$dp_default_arguments"
    # set sessionid
    if [[ $sessionid_warning == true && ! -f "$userdir/key_0.d0si.$server_name" ]]; then
        echo -e "$print_attention Key key_0.d0si.$server_name does not exist."
        read -p '            Do you want to go on? (y) ' answer_key
        if [[ $answer_key != y ]]; then
            echo >&2 '            Abort'
            exit 1
        fi
    fi
    dp_default_arguments="$dp_default_arguments -sessionid $server_name"
    # option 1: server is already running
    # -> print error and continue with for loop
    if pgrep_server &>/dev/null; then
        echo -e "$print_attention Server '$server_name' is already running."
        continue
    fi
    # option 2: server is not running, tmux session does not exist
    # -> start a new tmux session with new window and start server
    if ! tmux list-sessions 2>/dev/null |grep "$tmux_session:" &>/dev/null; then
        if [[ -f $HOME/.tmux.conf && -z $xstools_tmux ]]; then
            TMUX=`which tmux`
        else
            TMUX="`which tmux` -f $xstool_dir/configs/.tmux.conf"
        fi
        $TMUX new-session -d -n $tmux_window -s $tmux_session
        tmux send -t $tmux_session:$tmux_window "$server_command $dp_default_arguments +set serverconfig $server_config $log_dp_argument" C-m
        echo -e "$print_info Server '$server_name' has been started."
    # option 3: server is not running; tmux session exists, and window already exists
    # -> print error and continue with for loop
    elif tmux list-windows -t $tmux_session |grep "$tmux_window " &>/dev/null; then
        echo &>2 -e "$print_error Server '$server_name' does not run, but tmux window '$tmux_window' exists."
        echo &>2 -e "          Use '--attach $server_name' to check window status."
        continue
    else
    # option 4; server is not running, tmux session exists, window does not exist
    # -> start a new window in tmux session and start server
        tmux new-window -d -n $tmux_window -t $tmux_session
        tmux send -t $tmux_session:$tmux_window "$server_command $dp_default_arguments +set serverconfig $server_config $log_dp_argument" C-m
        echo -e "$print_info Server '$server_name' has been started."
fi
dp_default_arguments="$dp_default_arguments_bak"
done
} # end of server_start()

# start one or more servers
function server_start_specific() {
server_first_config_check $1
version_has_been_set=false
while getopts ":agr" opt
do
    case $opt in
        a) version_autobuild_check_and_set && version_has_been_set=true;;
        g) version_git_check_and_set && version_has_been_set=true;;
        r) version_release_check_and_set && version_has_been_set=true;;
    esac
done
shift $((OPTIND-1))
for server_name in $@; do
    server_config_check_and_set $server_name
done
if [[ $version_has_been_set == false ]]; then
    case $default_version in
        autobuild) version_autobuild_check_and_set && version_has_been_set=true;;
        git) version_git_check_and_set && version_has_been_set=true;;
        release) version_release_check_and_set && version_has_been_set=true;;
        *)  echo >&2 -e "$print_error Invalid version: $default_version." && echo >&2 -e "        Please fix xstools.conf."; exit 1;;
    esac
fi
server_start "$@"
} # end of server_start_specific()

# start all servers
function server_start_all() {
version_has_been_set=false
while getopts ":agr" opt
do
    case $opt in
        a) version_autobuild_check_and_set && version_has_been_set=true;;
        g) version_git_check_and_set && version_has_been_set=true;;
        r) version_release_check_and_set && version_has_been_set=true;;
    esac
done
shift $((OPTIND-1))
if [[ $version_has_been_set == false ]]; then
    case $default_version in
        autobuild) version_autobuild_check_and_set && version_has_been_set=true;;
        git) version_git_check_and_set && version_has_been_set=true;;
        release) version_release_check_and_set && version_has_been_set=true;;
        *)  echo >&2 -e "$print_error Invalid version: $default_version." && echo >&2 -e "        Please fix xstools.conf."; exit 1;;
    esac
fi
for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
    server_start $(basename ${cfg%.cfg})
done
} # end of server_start_all()

function server_stop() {
case $1 in
    defined_servers)
        shift
        for server_name in $@; do
        server_config_check_and_set $server_name
            if pgrep_server &>/dev/null; then
                if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
                    tmux send -t $tmux_session:$tmux_window "endmatch; quit" C-m
                    sleep 0.5
                    tmux send -t $tmux_session:$tmux_window "exit" C-m
                    echo -e "$print_info Server '$server_name' has been stopped."
                else
                    echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
                    echo >&2 -e "        You have to fix this on your own."
                fi
            else
                echo >&2 -e "$print_error Server '$server_name' is not running, cannot stop."
            fi
        done;;
    all_servers)
        for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
            server_config_check_and_set $(basename ${cfg%.cfg})
            if pgrep_server$pgrep_suffix &>/dev/null; then
                if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
                    tmux send -t $tmux_session:$tmux_window "endmatch; quit" C-m
                    sleep 0.5
                    tmux send -t $tmux_session:$tmux_window "exit" C-m
                    echo -e "$print_info Server '$server_name' has been stopped."
                else
                    echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
                    echo >&2 -e "        You have to fix this on your own."
                fi
            fi
        done;;
esac
} # end of server_stop()

function server_stop_redirect() {
case $1 in
    defined_servers)
        shift
        server_names=( $@ );;
    all_servers)
        all_servers=
        for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
            server_config_check_and_set $(basename ${cfg%.cfg})
            if pgrep_server$pgrep_suffix &>/dev/null; then
                all_servers="$all_servers $server_name"
            fi
        done
        server_names=( $all_servers );;
esac
counter=0
while [ $counter -lt ${#server_names[@]} ]; do
server_config_check_and_set ${server_names[$counter]}
    if pgrep_server &>/dev/null; then
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            echo -e "$print_info Sending 'quit_and_redirect $quit_and_redirect_to' to '$server_name'"
            tmux send -t $tmux_session:$tmux_window "quit_and_redirect ${quit_and_redirect_to}" C-m
            if [[ -n $restart_and_redirect_now ]]; then
                tmux send -t $tmux_session:$tmux_window "endmatch" C-m
                sleep 0.5
                tmux send -t $tmux_session:$tmux_window "exit" C-m
                echo -e "       Server '$server_name' has been stopped."
            fi
    else
            echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
            echo >&2 -e "        You have to fix this on your own."
            unset server_names[$counter]
        fi
    else
        echo >&2 -e "$print_error Server '$server_name' is not running, cannot stop."
        unset server_names[$counter]
    fi
    counter=$[$counter+1] # ((counter++))
done
if [[ -n $not_wait_for_quit ]]; then
    echo -e "$print_info Server(s) will be stopped when empty and next level starts."
    echo -e "       Please close the tmux windows, when servers have been stopped."
    exit
fi
if [[ -z $quit_and_redirect_now ]]; then
# get the new field of server names
server_names=( ${server_names[@]} )
sleep 0.5
counter=0
while [ $counter -lt ${#server_names[@]} ]; do
    server_config_check_and_set ${server_names[$counter]}
        if ! pgrep_server &>/dev/null; then
            tmux send -t $tmux_session:$tmux_window "exit" C-m
            echo -e "       Server '$server_name' has been stopped."
            unset server_names[$counter]
            server_names=( ${server_names[@]} )
        else
            counter=$[$counter+1]
            if [[ $counter -eq ${#server_names[@]} ]]; then
                counter=0
            fi
        fi
    sleep 2
done
fi
} # end of server_stop_redirect

function server_stop_empty() {
case $1 in
    defined_servers)
        shift
        server_names=( $@ );;
    all_servers)
        all_servers=
        for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
            server_config_check_and_set $(basename ${cfg%.cfg})
            if pgrep_server$pgrep_suffix &>/dev/null; then
                all_servers="$all_servers $server_name"
            fi
        done
        server_names=( $all_servers );;
esac
counter=0
while [ $counter -lt ${#server_names[@]} ]; do
server_config_check_and_set ${server_names[$counter]}
    if pgrep_server &>/dev/null; then
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            echo -e "$print_info Sending 'quit_when_empty 1' to '$server_name'"
            tmux send -t $tmux_session:$tmux_window "quit_when_empty 1" C-m
        else
            echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
            echo >&2 -e "        You have to fix this on your own."
            unset server_names[$counter]
        fi
    else
        echo >&2 -e "$print_error Server '$server_name' is not running, cannot stop."
        unset server_names[$counter]
    fi
    counter=$[$counter+1] # ((counter++))
done
if [[ -n $not_wait_for_quit ]]; then
    echo -e "$print_info Server(s) will be stopped when empty and next level starts."
    echo -e "       Please close the tmux windows, when servers have been stopped."
    exit
fi
# get the new field of server names
server_names=( ${server_names[@]} )
sleep 0.5
counter=0
while [ $counter -lt ${#server_names[@]} ]; do
    server_config_check_and_set ${server_names[$counter]}
        if ! pgrep_server &>/dev/null; then
            tmux send -t $tmux_session:$tmux_window "exit" C-m
            echo -e "       Server '$server_name' has been stopped."
            unset server_names[$counter]
            server_names=( ${server_names[@]} )
        else
            counter=$[$counter+1]
            if [[ $counter -eq ${#server_names[@]} ]]; then
                counter=0
            fi
        fi
    sleep 2
done
} # end of server_stop_empty

# stop one or more servers
function server_stop_specific() {
while getopts ":q:new" options; do
    case $options in
        q) quit_and_redirect=true; quit_and_redirect_custom=true; quit_and_redirect_to="$OPTARG";;
        n) quit_and_redirect=true; quit_and_redirect_now=true;;
        e) quit_when_empty=true;;
        w) not_wait_for_quit=true;;
    esac
done
shift $((OPTIND-1))
if [[ -n $quit_and_redirect && -n $quit_when_empty ]]; then
    echo >&2 -e "$print_error You cannot use -n,-q in combination with -e option."
    exit 1
fi
for server_name in $@; do
    server_config_check_and_set $server_name
done
if [[ -n $quit_and_redirect ]]; then
    send_notice defined_servers $@
    server_stop_redirect defined_servers $@
elif [[ -n $quit_when_empty ]]; then
    server_stop_empty defined_servers $@
else
    server_stop defined_servers $@
fi
} # end of server_stop_specific()

# function to stop all servers
function server_stop_all() {
while getopts ":agrq:new" options; do
    case $options in
        a) [ -z $pgrep_suffix ] && pgrep_suffix=_autobuild || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        g) [ -z $pgrep_suffix ] && pgrep_suffix=_git       || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        r) [ -z $pgrep_suffix ] && pgrep_suffix=__release  || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        q) quit_and_redirect=true; quit_and_redirect_custom=true; quit_and_redirect_to="$OPTARG";;
        n) quit_and_redirect=true; quit_and_redirect_now=true;;
        e) quit_when_empty=true;;
        w) not_wait_for_quit=true;;
    esac
done
shift $((OPTIND-1))
if [[ -n $quit_and_redirect && -n $quit_when_empty ]]; then
    echo >&2 -e "$print_error You cannot use -n,-q in combination with -e option."
    exit 1
fi
if [[ -n $quit_and_redirect ]]; then
    send_notice all_servers $@
    server_stop_redirect all_servers $@
elif [[ -n $quit_when_empty ]]; then
    server_stop_empty all_servers
else
    server_stop all_servers
fi
} # end of server_stop_all()

function server_restart() {
case $1 in
    defined_servers)
        shift
        for server_name in $@; do
            server_config_check_and_set $server_name
            if pgrep_server &>/dev/null; then
                if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
                    echo -e "$print_info Restarting server '$server_name'..."
                    tmux send -t $tmux_session:$tmux_window "endmatch; quit" C-m
                    sleep 0.5
                    if [[ "$logs_date" == "true" ]]; then
                        tmux send -t $tmux_session:$tmux_window 'last_command="!!"' C-m
                        tmux send -t $tmux_session:$tmux_window "log_dp_argument=\"$log_dp_argument\"" C-m
                        tmux send -t $tmux_session:$tmux_window 'eval $(echo "$last_command" | awk -F"+set log_file" -v log_dp_argument="$log_dp_argument" "{print \$1 log_dp_argument}")' C-m
                    else
                        tmux send -t $tmux_session:$tmux_window '!!' C-m
                    fi
                    echo -e "       Server '$server_name' has been restarted."
                else
                    echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
                    echo >&2 -e "        You have to fix this on your own."
                fi
                else
            echo >&2 -e "$print_error Server '$server_name' is not running, cannot restart."
            fi
        done;;
    all_servers)
        for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
            server_config_check_and_set $(basename ${cfg%.cfg})
            if pgrep_server$pgrep_suffix &>/dev/null; then
                if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
                    echo -e "$print_info Restarting server '$server_name'..."
                    tmux send -t $tmux_session:$tmux_window "endmatch; quit" C-m
                    sleep 0.5
                    if [[ "$logs_date" == "true" ]]; then
                        tmux send -t $tmux_session:$tmux_window 'last_command="!!"' C-m
                        tmux send -t $tmux_session:$tmux_window "log_dp_argument=\"$log_dp_argument\"" C-m
                        tmux send -t $tmux_session:$tmux_window 'eval $(echo "$last_command" | awk -F"+set log_file" -v log_dp_argument="$log_dp_argument" "{print \$1 log_dp_argument}")' C-m
                    else
                        tmux send -t $tmux_session:$tmux_window '!!' C-m
                    fi
                    echo -e "       Server '$server_name' has been restarted."
                else
                    echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
                    echo >&2 -e "        You have to fix this on your own."
                fi
            fi
        done;;
esac
} # end of server_restart

function server_restart_redirect() {
case $1 in
    defined_servers)
        shift
        server_names=( $@ );;
    all_servers)
        all_servers=
        for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
            server_config_check_and_set $(basename ${cfg%.cfg})
            if pgrep_server$pgrep_suffix &>/dev/null; then
                all_servers="$all_servers $server_name"
            fi
        done
        server_names=( $all_servers );;
esac

counter=0
while [ $counter -lt ${#server_names[@]} ]; do
server_config_check_and_set ${server_names[$counter]}
    if pgrep_server &>/dev/null; then
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            echo -e "$print_info Sending 'quit_and_redirect $restart_and_redirect_to' to '$server_name'..."
            tmux send -t $tmux_session:$tmux_window "quit_and_redirect ${restart_and_redirect_to}" C-m
            if [[ -n $restart_and_redirect_now ]]; then
            tmux send -t $tmux_session:$tmux_window "endmatch" C-m
            fi
    if [[ -n $restart_and_redirect_now ]]; then
        while pgrep_server &>/dev/null; do
            sleep 1
        done
        if [[ "$logs_date" == "true" ]]; then
            tmux send -t $tmux_session:$tmux_window 'last_command="!!"' C-m
            tmux send -t $tmux_session:$tmux_window "log_dp_argument=\"$log_dp_argument\"" C-m
            tmux send -t $tmux_session:$tmux_window 'eval $(echo "$last_command" | awk -F"+set log_file" -v log_dp_argument="$log_dp_argument" "{print \$1 log_dp_argument}")' C-m
        else
            tmux send -t $tmux_session:$tmux_window '!!' C-m
        fi
        echo -e "       Server '$server_name' has been restarted."
    fi
    else
            echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
            echo >&2 -e "        You have to fix this on your own."
            unset server_names[$counter]
        fi
    else
        echo >&2 -e "$print_error Server '$server_name' is not running, cannot stop."
        unset server_names[$counter]
    fi
    counter=$[$counter+1] # ((counter++))
done
if [[ -z $restart_and_redirect_now ]]; then
# get the new field of server names
server_names=( ${server_names[@]} )
sleep 0.5
counter=0
while [ $counter -lt ${#server_names[@]} ]; do
    server_config_check_and_set ${server_names[$counter]}
        if ! pgrep_server &>/dev/null; then
            if [[ "$logs_date" == "true" ]]; then
                tmux send -t $tmux_session:$tmux_window 'last_command="!!"' C-m
                tmux send -t $tmux_session:$tmux_window "log_dp_argument=\"$log_dp_argument\"" C-m
                tmux send -t $tmux_session:$tmux_window 'eval $(echo "$last_command" | awk -F"+set log_file" -v log_dp_argument="$log_dp_argument" "{print \$1 log_dp_argument}")' C-m
            else
                tmux send -t $tmux_session:$tmux_window '!!' C-m
            fi
            echo -e "       Server '$server_name' has been restarted."
            unset server_names[$counter]
            server_names=( ${server_names[@]} )
        else
            counter=$[$counter+1]
            if [[ $counter -eq ${#server_names[@]} ]]; then
                counter=0
            fi
        fi
    sleep 2
done
fi
} # end of server_restart_redirect

# restart one or more servers
function server_restart_specific() {
while getopts ":q:sn" options; do
    case $options in
        q) restart_and_redirect=true; restart_and_redirect_to="$OPTARG";;
        s) restart_and_redirect=true; restart_and_redirect_to="self";;
        n) restart_and_redirect=true; restart_and_redirect_now=true;;
    esac
done
shift $((OPTIND-1))
for server_name in $@; do
    server_config_check_and_set $server_name
done
if [[ -n $restart_and_redirect ]]; then
    send_notice defined_servers $@
    server_restart_redirect defined_servers $@
else
    server_restart defined_servers $@
fi
} # end of server_restart_specific()

# function to restart all servers
function server_restart_all() {
while getopts ":agrq:sn" options; do
    case $options in
        a) [ -z $pgrep_suffix ] && pgrep_suffix=_autobuild || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        g) [ -z $pgrep_suffix ] && pgrep_suffix=_git       || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        r) [ -z $pgrep_suffix ] && pgrep_suffix=__release  || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        q) restart_and_redirect=true; restart_and_redirect_to="$OPTARG";;
        s) restart_and_redirect=true; restart_and_redirect_to="self";;
        n) restart_and_redirect=true; restart_and_redirect_now=true;;
    esac
done
shift $((OPTIND-1))
if [[ -n $restart_and_redirect ]]; then
    send_notice all_servers
    server_restart_redirect all_servers
else
    server_restart all_servers
fi
} # end of server_restart_all()

function send_notice() {
send_notice_to=
case $1 in
    defined_servers)
        shift
        for server_name in $@; do
            server_config_check_and_set $server_name
            if pgrep_server &>/dev/null; then
                if tmux list-windows -t $tmux_session 2>/dev/null| grep "$tmux_window " &>/dev/null; then
                    send_notice_to="$send_notice_to $tmux_window"
                fi
            fi
        done;;
    all_servers)
        for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
        server_config_check_and_set $(basename ${cfg%.cfg})
        # search for servers and save them in a field
        if pgrep_server$pgrep_suffix &>/dev/null; then
            if tmux list-windows -t $tmux_session 2>/dev/null| grep "$tmux_window " &>/dev/null; then
                send_notice_to="$send_notice_to $tmux_window"
            fi
        fi
        done;;

esac
if [[ -n $update_git ]]; then
    for tmux_window in ${send_notice_to}; do
        tmux send -t $tmux_session:$tmux_window "
        set sv_adminnick_bak \"\${sv_adminnick}\";
        set sv_adminnick \"^1Server System^3\";
        say git update process started (will force restart when finished);
        wait; set sv_adminnick \"\${sv_adminnick_bak}\"" C-m
    done
elif [[ -n $update_autobuild ]]; then
    for tmux_window in ${send_notice_to}; do
        tmux send -t $tmux_session:$tmux_window "
        set sv_adminnick_bak \"\${sv_adminnick}\";
        set sv_adminnick \"^1Server System^3\";
        say autobuild update process started (will force restart when finished);
        wait; set sv_adminnick \"\${sv_adminnick_bak}\"" C-m
    done
elif [[ -n $restart_and_redirect_now && $restart_and_redirect_to == "self" ]]; then
    for tmux_window in ${send_notice_to}; do
        tmux send -t $tmux_session:$tmux_window "
        set sv_adminnick_bak \"\${sv_adminnick}\";
        set sv_adminnick \"^1Server System^3\";
        say Server will restart now;
        say You will reconnect automatically;
        wait; set sv_adminnick \"\${sv_adminnick_bak}\"" C-m
    done
elif [[ -n $restart_and_redirect_now && -n $restart_and_redirect_to ]]; then
    for tmux_window in ${send_notice_to}; do
        tmux send -t $tmux_session:$tmux_window "
        set sv_adminnick_bak \"\${sv_adminnick}\";
        set sv_adminnick \"^1Server System^3\";
        say Server will restart now;
        say You will be redirected to another server;
        wait; set sv_adminnick \"\${sv_adminnick_bak}\"" C-m
    done
elif [[ -n $restart_and_redirect && $restart_and_redirect_to == "self" ]]; then
    for tmux_window in ${send_notice_to}; do
        tmux send -t $tmux_session:$tmux_window "
        set sv_adminnick_bak \"\${sv_adminnick}\";
        set sv_adminnick \"^1Server System^3\";
        say Server will restart at endmatch;
        say You will reconnect automatically;
        wait; set sv_adminnick \"\${sv_adminnick_bak}\"" C-m
    done
elif [[ -n $restart_and_redirect && -n $restart_and_redirect_to ]]; then
    for tmux_window in ${send_notice_to}; do
        tmux send -t $tmux_session:$tmux_window "
        set sv_adminnick_bak \"\${sv_adminnick}\";
        set sv_adminnick \"^1Server System^3\";
        say Server will restart at endmatch;
        say You will be redirected to another server;
        wait; set sv_adminnick \"\${sv_adminnick_bak}\"" C-m
    done
elif [[ -n $quit_and_redirect && -n $quit_and_redirect_to ]]; then
    for tmux_window in ${send_notice_to}; do
        tmux send -t $tmux_session:$tmux_window "
        set sv_adminnick_bak \"\${sv_adminnick}\";
        set sv_adminnick \"^1Server System^3\";
        say Server will stop at endmatch;
        say You will be redirected to another server;
        wait; set sv_adminnick \"\${sv_adminnick_bak}\"" C-m
    done
fi
} # end of send_notice()

function server_update_autobuild() {
while getopts ":q:sn" options; do
    case $options in
        q) restart_and_redirect=true; restart_and_redirect_to="$OPTARG";;
        s) restart_and_redirect=true; restart_and_redirect_to="self";;
        n) restart_and_redirect=true; restart_and_redirect_now=true;;
    esac
done
shift $((OPTIND-1))
if [[ -z $autobuild_update_script ]]; then
    echo >&2 -e "$print_error Script to update autobuild not set."
    echo >&2 -e "        Check xstools.conf."
    exit 1
elif [[ ! -x "$autobuild_update_script" ]]; then
    echo >&2 -e "$print_error Cannot not execute autobuild update script."
    echo >&2 -e "        Check if file exists and marked as executable."
    echo >&2 -e "        Please fix this."
    exit 1
fi
# use update_git variable for send_notice function
# avoid creating symlink via version_autobuild_check_and_set
update_autobuild=true
# autobuild version...
version_autobuild_check_and_set
# check options
if [[ -z $autobuild_update_date ]]; then
    echo >&2 -e "$print_error 'autobuild_update_date' is empty"
    echo >&2 -e "       date format: $(date +'%d %b %H:%M %Z') will be used for this update"
    git_update_date='%d %b %H:%M %Z'
fi
# autobuild servers only
pgrep_suffix=_autobuild
# lock xstools, when update started
touch "$userdir/lock_update"
# option -a need not to be set - due the defined suffix
send_notice all_servers
# simply update
update_autobuild
# recreate link
ln -f "$basedir_autobuild/$executable" "$basedir_autobuild/$executable-autobuild"

unset update_autobuild
# option -g need not to be set - due the defined suffix
if [[ -n $restart_and_redirect ]]; then
    send_notice all_servers
    server_restart_redirect all_servers
else
    server_restart all_servers
fi
# unlock xstools
rm -f "$userdir/lock_update"
} # end of server_update_autobuild()

function server_update_git() {
while getopts ":q:sn" options; do
    case $options in
        q) restart_and_redirect=true; restart_and_redirect_to="$OPTARG";;
        s) restart_and_redirect=true; restart_and_redirect_to="self";;
        n) restart_and_redirect=true; restart_and_redirect_now=true;;
    esac
done
shift $((OPTIND-1))
# git version...
version_git_check_and_set
# check options
if [[ -z $git_compile_options ]]; then
    echo >&2 -e "$print_error 'git_compile_options' is empty"
    echo >&2 -e "       'dedicated' will be used for this update"
    git_compile_options='dedicated'
elif [[ -z $git_update_options ]]; then
    echo >&2 -e "$print_error 'git_update_options' is empty"
    echo >&2 -e "       '-l best' will be used for this update"
    git_update_options='-l best'
elif [[ -z $git_update_date ]]; then
    echo >&2 -e "$print_error 'git_update_date' is empty"
    echo >&2 -e "       date format: $(date +'%d %b %H:%M %Z') will be used for this update"
    git_update_date='%d %b %H:%M %Z'
fi
# git servers only
pgrep_suffix=_git
if [[ $grep_release == true && $grep_git != true ]]; then
    pgrep_suffix=_release
elif [[ $grep_release != true && $grep_git == true ]]; then
    pgrep_suffix=_git
fi
# lock xstools, when update started
touch "$userdir/lock_update"
# use update_git variable for send_notice function
update_git=true
# option -g need not to be set - due the defined suffix
send_notice all_servers
# simply update
update_git
unset update_git
# option -g need not to be set - due the defined suffix
if [[ -n $restart_and_redirect ]]; then
    send_notice all_servers
    server_restart_redirect all_servers
else
    server_restart all_servers
fi
# unlock xstools
rm -f "$userdir/lock_update"
} # end of server_update_git()

# }}}

### --- additional server functions
# {{{

# function to attach user to tmux window of give server
function server_attach() {
server_first_config_check $1
if [[ "$tmux_help" == "true" ]]; then
    echo -e "$print_info You will be attached to a server window."
    echo
    echo -e "$print_attention To get out of tmux..."
    echo -e "            hold ctrl, press b, release them, press d."
    echo -e "            To scroll..."
    echo -e "            hold ctrl, press b, release them, press 'page up'."
    echo -e "            You can scroll with your arrow keys"
    echo -e "            (Press enter to continue)"
    read # wait until info has been read
fi
for var in $@; do
    server_config_check_and_set $var
    if tmux list-windows -t $tmux_session| grep -E "[0-9]+: $tmux_window \[[0-9]+x[0-9]+\]" &>/dev/null; then
        tmux select-window -t $tmux_session:$tmux_window
        tmux attach -t $tmux_session
    else
        echo -e "$print_error tmux window '$tmux_window' does not exist." >&2
        echo -e "          Use '--list' to list all servers running servers." >&2
    fi
done
} # end of server_attach()

# list all running servers and rcon2irc bots
function xstools_list_all() {
if tmux list-windows -t $tmux_session &>/dev/null; then
    activ_server_windows=$(tmux list-windows -t $tmux_session |awk -F\  '$2 ~ /server-.*/ {print $2}' |cut -f2- -d- |sort -f)
    if [[ -z $activ_server_windows ]]; then
        echo -e "$print_info No servers are running."
    else
        echo -e "$print_info Following servers are running:"
    fi
    for server_name in $activ_server_windows; do
        server_config_check_and_set $server_name
        if pgrep_server &>/dev/null; then
        # if you list your servers it could be very nice to check player numbers and server version :) ... so I added it
                if [[ "$enable_quakestat" == "true" ]]; then
                server_port=$(awk '/^port/ {print $2}'  $userdir/configs/servers/$server_config)
                server_players=$(quakestat -nh -nexuizs localhost:$server_port | awk '{print " - "$2" - "}')
                if (echo "$server_players" | grep -Eo '[0-9]{1,}/ ') &>/dev/null ; then
                    server_players=$(quakestat -nh -nexuizs localhost:$server_port | awk '{print " - "$2$3"  - "}')
                fi
                server_version=$(quakestat -R -nh -nexuizs localhost:$server_port | tail -1 | awk -F, '{print $6}' | awk -F= '{print $2}' | awk -F: '{print $2}')
                fi
            printf "%-30s%-s\n" "       - $server_name" "${server_players}${server_version}"
        else
            echo >&2 -e "       - $print_error window: '$tmux_window' has no running server"
            echo >&2 -e "                 Use '--attach $server_name' to check window status."
        fi
    done
    # same for rcon2irc bots
    activ_rcon2irc_windows=$(tmux list-windows -t $tmux_session |awk -F\  '$2 ~ /rcon2irc-.*/ {print $2}' |cut -f2- -d- |sort -f)
    if [[ -z $activ_rcon2irc_windows ]]; then
        echo -e "$print_info No rcon2irc bots are running."
    else
        echo -e "$print_info rcon2irc bots are running:"
    fi
    for var in $activ_rcon2irc_windows; do
        rcon2irc_config_check_and_set $var
        if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
            echo -e "       - $rcon2irc_name"
        else
            echo >&2 -e "       - $print_error window: '$tmux_window' has no running rcon2irc bot"
            echo >&2 -e "                 Use '--rcon2irc attach $rcon2irc_name' to check window status."
        fi
    done
fi
if ! tmux list-sessions | cut -d: -f1 | grep $tmux_session &>/dev/null; then
    echo >&2 -e "$print_error tmux session '$tmux_session' not activ"
    exit 1
fi
} # end of xstools_list_all()

# list all available server and rcon2irc config files (not common ones)
function xstools_list_configs() {
echo -e "$print_info Server config files in 'configs/servers'"
for cfg in $(ls "$userdir"/configs/servers/*.cfg); do
    echo "       - ${cfg##*/}"
done
echo -e "$print_info Rcon2irc config files in 'configs/rcon2irc'"
for conf in $(ls "$userdir"/configs/rcon2irc/*.rcon2irc.conf); do
    echo "       - ${conf##*/}"
done
} # end of xstools_list_configs

function server_add_pk3() {
# download / move a given pk3 into $userdir/packages
# and send rescan_pending 1 to all servers to search for new added packages
# check if http_server_folder exists if http_server is set to true
if [[ "$http_server" == "true"  ]]; then
    if [[ ! -d "$http_server_folder" ]]; then
        echo >&2 -e "$print_error $http_server_folder does not exist."
        echo >&2 -e "        Check xstools.conf (http_server_folder)"
        exit 1
    elif [[ "$http_server_option" != "copy" && "$http_server_option" != "hardlink" && "$http_server_option" != "symlink" ]]; then
        echo >&2 -e "$print_error '$http_server_option' is a invalid option."
        echo >&2 -e "        Check xstools.conf (http_server_option)"
        exit 1
    fi
fi
# set target folder
while getopts ":p:" options; do
    case $options in
        p)  [ ! -d $OPTARG ] && echo -e >&2 "$print_error Folder $OPTARG does not exist." && exit 1;
            package_folder="$OPTARG";;
    esac
done
shift $((OPTIND-1))
[  "x$package_folder" = x ] && package_folder="$userdir/packages"
# check urls now
for var in $@; do
    echo "$var" | grep -E 'https?://.+\.pk3' &>/dev/null || {
    echo >&2 -e "$print_error xstools only accepts pk3 files from a http/https url."
    echo >&2 -e "        No files have been added. Please add them on your own to 'packages'"
    exit 1
}
done
# download all files
for var in $@; do
    pk3file_name=$(basename $var |sed 's/%23/#/g' )
    # do not download already existing pk3 packages
    if [[ -f "$package_folder/$pk3file_name" ]]; then
        echo -e "$print_info $pk3file_name already exists."
        continue
    fi
    wget --directory-prefix="$package_folder" -N $var
    # create copy/symlink/hardlink for http server
    if [[ "$http_server" == "true" ]]; then
        case $http_server_option in
            copy)
                cp "$package_folder/$pk3file_name" "$http_server_folder"/$pk3file_name;;
            hardlink)
                ln "$package_folder/$pk3file_name" "$http_server_folder"/$pk3file_name;;
            symlink)
                ln -s "$package_folder/$pk3file_name" "$http_server_folder"/$pk3file_name;;
        esac
    fi
done
server_send_rescan
} # end of server_add_pk3()

# send commands to servers via tmux send
function server_send(){
if [[ -z $sendall ]]; then
    # check if arguments contain -c for seperating command from server names
    if ! echo "$@" | grep ' -c ' &>/dev/null; then
        echo >&2 -e "$print_error Syntax is: --send <server(s)> -c <command>"
        exit 1
    fi
    # check if first argument is a valid config
    server_first_config_check $1
    for var in "$@"; do
        if [[ "$var" == "-c" ]]; then
            break
        fi
        server_config_check_and_set $var
        if pgrep_server &>/dev/null; then
            if ! tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
                echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
                echo >&2 -e "        You have to fix this on your own."
            else
                server_names="$server_names $server_name"
            fi
        fi
    done
    my_command=$(echo "$@" | awk -F' -c ' '{print $2}')
else
    for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
        server_config=${cfg##*/}
        if pgrep_server &>/dev/null; then
            server_config_check_and_set ${server_config%.cfg}
            if ! tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
                echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
                echo >&2 -e "        You have to fix this on your own."
            else
                server_names="$server_names $server_name"
            fi
        fi
    done
    if [[ $1 == '-c' ]]; then
        shift
    fi
    my_command="$@"
fi
server_names=( $server_names )
counter=0
while [ "$counter" -lt "${#server_names[@]}" ]; do
    echo -e "$print_info Sending command to server '${server_names[$counter]}'."
    tmux send -t $tmux_session:server-${server_names[$counter]} "$my_command" C-m
    counter=$[$counter+1]
done
} # end of server_send()

# send rescan_pending 1 to servers to scan for new added pk3 packages
function server_send_rescan() {
echo -e "$print_info Servers will scan for new packages at endmatch."
echo -e "       'rescan_pending 1' has been sent to"
for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
    server_config=${cfg##*/}
    if pgrep_server &>/dev/null; then
        server_config_check_and_set ${server_config%.cfg}
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            tmux send -t $tmux_session:$tmux_window "rescan_pending 1" C-m
            echo -e "       - $server_name"
        else
            echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
            echo >&2 -e "        You have to fix this on your own."
        fi
    fi
done
} # end of server_send_rescan()

# set ports and passwords for every server and save them in a variable
# used in for statements
function server_send_rcon_get_ports_and_pws() {
# we use servers config name, to save the port
server_port=$(awk '/^port/ {print $2}' "$userdir"/configs/servers/$server_config)
# test if we have found a port... simply grep for a field of digits :)
if ! echo $server_port | grep -E '[0-9]{4,5}' &>/dev/null; then
    echo >&2 -e "$print_error Could not find a port in $server_config"
    echo >&2 -e "       No command has been sent to any server."
    exit 1
elif ! pgrep_server &>/dev/null; then
    echo >&2 -e "$print_error Server '$server_name' is not running."
    continue
fi
all_server_names="$all_server_names $server_name"
all_server_ports="$all_server_ports $server_port"
# set/search our rcon passwords
# test if our server config file has password - otherwise use $main_rcon_password
unset rcon_password
rcon_password=$(awk '/^rcon_password/ {print $2}' "$userdir/configs/servers/$server_config")
if [[ -n $rcon_password ]]; then
    all_rcon_passwords="$all_rcon_passwords $rcon_password"
else
    if [[ $main_rcon_password == "" ]]; then
        echo >&2 -e "$print_error Could not find a rcon password in $server_config"
        echo >&2 -e "        or in your security.cfg."
        echo >&2 -e "        No command has been sent to any server."
        exit 1
    fi
    all_rcon_passwords="$all_rcon_passwords $main_rcon_password"
fi
} # end of server_send_set_ports_and_pws

# send commands to server(s) via rcon.pl and receive output
function server_send_rcon() {
# check if everything is fine ...
if [[ ! -x "$rcon_script" ]]; then
    echo >&2 -e "$print_error Could not find rcon script."
    echo >&2 -e "        Check xstools.conf. Also check flags, need +x"
    exit 1
fi

# get main rcon password
main_rcon_password=$(awk '/^rcon_password/ {print $2}' "$userdir"/configs/servers/common/security.cfg)

if [[ -z $sendall ]]; then
    # check if arguments contain -c for seperating command from server names
    if ! echo "$@" | grep ' -c ' &>/dev/null; then
        echo >&2 -e "$print_error Syntax is: --send <server(s)> -c <command>"
        exit 1
    fi
    # check if first argument is a valid config
    server_first_config_check $1
    for var in "$@"; do
        if [[ "$var" == "-c" ]]; then
            break
        fi
        server_config_check_and_set $var
        server_send_rcon_get_ports_and_pws
    done
    my_command=$(echo "$@" | awk -F' -c ' '{print $2}')
else
    for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
        server_config_check_and_set $(basename ${cfg%.cfg})
        if pgrep_server &>/dev/null; then
            if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
                server_send_rcon_get_ports_and_pws
            else
                echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
                echo >&2 -e "        You have to fix this on your own."
            fi
        fi
    done
    if [[ $1 == '-c' ]]; then
        shift
    fi
    my_command="$@"
fi
# for each server we save a rcon password and port until 'command to send' begins
a_name=( $all_server_names )
a_port=( $all_server_ports )
a_pass=( $all_rcon_passwords )
counter=0
while [ "$counter" -lt "${#a_name[@]}" ]; do
    echo -e "$print_info Sending command to server '${a_name[$counter]}'."
    echo
    rcon_address=127.0.0.1:${a_port[$counter]} rcon_password=${a_pass[$counter]} $rcon_script "$my_command"
    echo
    counter=$[$counter+1]
done
} # end of server_send_command()

# log files for servers
function server_set_logs() {
echo -e "$print_info New log file set for server:"
for cfg in $(ls "$userdir"/configs/servers/*.cfg 2>/dev/null); do
    server_config=${cfg##*/}
    if pgrep_server &>/dev/null; then
        server_config_check_and_set ${server_config%.cfg}
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            log_format="logs/${server_name}_$(date +%F).log"
            tmux send -t $tmux_session:$tmux_window "log_file \"$log_format\"" C-m
            echo -e "       - $server_name"
        else
            echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$server_name' is running."
            echo >&2 -e "        You have to fix this on your own."
        fi
    fi
done
} # end of server_set_logs

# delete old log files
function server_del_logs() {
if [[ $mdays == "" ]]; then
    echo >&2 -e "$print_error You have not set a value for 'mdays'."
    echo >&2 -e "        Check xstools.conf"
    exit 1
fi
while getopts ":d:" options; do
    case $options in
        d) data_dirname="${OPTARG%/}";;
    esac
done
shift $((OPTIND-1))
[ -z $data_dirname ] && data_dirname=data
if [[ ! -d "$userdir/$data_dirname" ]]; then
     echo -e >&2 "$print_error Data folder $data_dirname does not exist."
     exit 1
fi
find "$userdir/$data_dirname"/logs/*.log -type f -mtime +$mdays -exec rm -f {} \; 2>/dev/null
echo -e "$print_info Log files in $data_dirname older than $mdays days deleted."
} # end of server_del_logs

function server_logs() {
case $1 in
    "set") server_set_logs;;
    "del") shift; server_del_logs "$@";;
    ""|*)
        echo >&2 -e "$print_error Argument invalid or missing."
        echo >&2 -e "        Use --send 'set' or 'del'."
        exit 1
esac
}

# }}}

### --- maplist functions
# {{{
function server_maplist_autobuild() {
echo -e "$print_info Checking autobuild mapinfos."
map_infos=$(unzip -l "$autobuild_release"/data/xonotic-*-maps*.pk3 |grep -Eo '[A-Za-z0-9#._+-]+\.mapinfo' |tr "\n" " ")
for map_info in $map_infos; do
    map_name=${map_info%.mapinfo}
    if [[ -f $userdir/$data_dirname/maps/$map_info ]]; then
        # user has defined his own mapinfo
        continue
#   elif [[ pk3 has been copied to packages... ]]; then
#       continue
    fi
    unzip -p "$basedir_autobuild"/data/xonotic-*-maps*.pk3 maps/$map_info | grep -Eo "^(gametype|type) $@" >/dev/null &&
    maplist="$map_name $maplist"
done
}

function server_maplist_git() {
echo -e "$print_info Checking git mapinfos."
for map_info_location in "$basedir_git"/data/xonotic-maps.pk3dir/maps/*.mapinfo; do
    map_info=$(basename $map_info_location)
    map_name=${map_info%.mapinfo}
    if [[ -f $userdir/$data_dirname/maps/$map_info ]]; then
        # user has defined his own mapinfo
        continue
#   elif [[ pk3 has copied to packages... ]]; then
#       continue
    fi
    grep -Eo "^(gametype|type) $@" $map_info_location >/dev/null &&
    maplist="$map_name $maplist"
done
}

function server_maplist_release() {
echo -e "$print_info Checking release mapinfos."
map_infos=$(unzip -l "$basedir_release"/data/xonotic-*-maps*.pk3 |grep -Eo '[A-Za-z0-9#._+-]+\.mapinfo' |tr "\n" " ")
for map_info in $map_infos; do
    map_name=${map_info%.mapinfo}
    if [[ -f $userdir/$data_dirname/maps/$map_info ]]; then
        # user has defined his own mapinfo
        continue
#   elif [[ pk3 has been copied to packages... ]]; then
#       continue
    fi
    unzip -p "$basedir_release"/data/xonotic-*-maps*.pk3 maps/$map_info | grep -Eo "^(gametype|type) $@" >/dev/null &&
    maplist="$map_name $maplist"
done
}

# create maplists for one or more gametypes
function server_maplist() {
which unzip &>/dev/null || {
    echo >&2 -e "$print_error Couldn't find unzip, which is required."
    exit 1
}
which uniq &>/dev/null || {
    echo >&2 -e "$print_error Couldn't find uniq, which is required."
    exit 1
}

while getopts ":agrd:p:" options; do
    case $options in
        a) [ -z $_version ] &&  _version=autobuild || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        g) [ -z $_version ] &&  _version=git       || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        r) [ -z $_version ] &&  _version=release   || ( echo >&2 "$print_error You cannot combine -a,-g,-r"; exit 1 );;
        d) data_dirname="${OPTARG%/}";;
        p) [ ! -d $OPTARG ] && echo -e >&2 "$print_error Folder ${OPTARG%/} does not exist." && exit 1;
           package_folders="$package_folders ${OPTARG%/}";;
    esac
done
shift $((OPTIND-1))

[ -z $data_dirname ] && data_dirname=data
if [[ ! -d "$userdir/$data_dirname" ]]; then
     echo -e >&2 "$print_error Data folder $data_dirname does not exist."
     exit 1
fi
[  "x$package_folders" = x ] && package_folders="$userdir/packages"

echo -e "$print_info Options:"
echo -e "       Version:           ${_version:-$default_version}"
echo -e "       data folder:       $data_dirname"
echo -e "       package folder(s): $package_folders"
echo

case ${_version:-$default_version} in
    autobuild)
    version_autobuild_check_and_set
    server_maplist_autobuild "$@"
        ;;
    git)
    version_git_check_and_set
    server_maplist_git "$@"
        ;;
    release)
    version_release_check_and_set
    server_maplist_release "$@"
        ;;
esac

echo -e "$print_info Checking user added .pk3 packages."
echo
# users may add sublevel folders to packages
for folder in $package_folders; do
    # no mapinfo in this directory.. then continue with next one
    ls $folder/*.pk3 &>/dev/null || continue
    for map_pk3 in $folder/*.pk3; do
        # pk3 packages can contain several bsp files
        map_bsps=$(unzip -l $map_pk3 |grep -Eo '[A-Za-z0-9#._+-]+\.bsp' |tr "\n" " ")
        # check if pk3 package contains a bsp, if not continue
        if [[ -z $map_bsps ]]; then
            continue
        fi
        # get the mapname of every bsp
        for map_bsp in $map_bsps; do
            map_name=${map_bsp%.bsp}
            # we have the map name... and can search for a mapinfo file in different folders/files
            # first we search data/maps
            if [[ -f "$userdir/$data_dirname/maps/$map_name.mapinfo" ]]; then
                grep -Eo "^(gametype|type) $@" "$userdir/$data_dirname/maps/$map_name.mapinfo" >/dev/null &&
                maplist="$map_name $maplist"
                continue
                # if there is no mapinfo in data/maps, we check the mapinfo in pk3 package
            elif unzip -l ${map_pk3} | grep maps/$map_name.mapinfo >/dev/null; then
                unzip -p ${map_pk3} maps/$map_name.mapinfo | grep -Eo "^(gametype|type) $@" >/dev/null &&
                maplist="$map_name $maplist"
                continue
                # last chance an autogenerated one
            elif [[ -f "$userdir/$data_dirname/data/maps/autogenerated/$map_name.mapinfo" ]]; then
                grep -Eo "^(gametype|type) $@" "$userdir/$data_dirname/data/maps/autogenerated/$map_name.mapinfo" >/dev/null &&
                maplist="$map_name $maplist"
                continue
            else
                echo >&2 -e "$print_error No $map_name.mapinfo file found!"
                echo >&2 -e "        ... ${map_pk3##*/}"
            fi
        done
    done
done
# sort the map names
if [[ -z $maplist ]]; then
    echo >&2 -e "$print_attention No maps for $@"
elif [[ $@ == "" ]]; then
    echo -e "$print_info Maplist for all gametypes:"
    echo $maplist |tr " " "\n" |sort -f|uniq
else
    echo -e "$print_info Maplist for $@:"
    echo $maplist |tr " " "\n" |sort -f|uniq
fi
} # end of server_maplist()

# }}}

### --- mapinfo functions
# {{{

# check of first argument is given and a pk3 name
function server_mapinfo_check_first() {
if [[ "$1" == "" ]]; then
    echo >&2 -e "$print_error pk3 file missing. Check -h or --help"
    exit 1
elif ! echo "$1" | grep ".pk3" 2>/dev/null; then
    echo >&2 -e "$print_error Argument must be a pk3 file."
    exit 1
fi
} # end of server_mapinfo_check_first()

# check if argument is a pk3 package and if file exists
# (used in for statements)
function server_mapinfo_check() {
if ! echo "$map_pk3" | grep ".pk3" >/dev/null 2>&1; then
    echo -e "$print_error ${map_pk3##*/} is not a a pk3 file." >&2
    continue
elif [[ ! -f $map_pk3 ]]; then
    echo -e "$print_error Could not find ${map_pk3##*/}"
    continue
fi
} # end of server_mapinfo_check()

# extract mapinfo files of given pk3 into data/maps
function server_mapinfo_extract() {
while getopts ":d:" options; do
    case $options in
        d) data_dirname="${OPTARG%/}";;
    esac
done
shift $((OPTIND-1))
[ -z $data_dirname ] && data_dirname=data
if [[ ! -d "$userdir/$data_dirname" ]]; then
     echo -e >&2 "$print_error Data folder $data_dirname does not exist."
     exit 1
fi
server_mapinfo_check_first $1
echo -e "$print_info Extract mapinfo files of pk3 files to:"
echo -e "       $userdir/$data_dirname/maps"
mkdir "$userdir/$data_dirname/maps" &>/dev/null
for map_pk3 in "$@"; do
    server_mapinfo_check $map_pk3
    echo $map_pk3 | grep '.pk3' &>/dev/null || echo -e "$print_error ${map_pk3##/*} is not a pk3 file." >&2
    map_infos=$(unzip -l $map_pk3 |grep -v MACOSX| grep -Eo '[A-Za-z0-9#._+-]+\.mapinfo' |tr "\n" " ")
    if [[ -z $map_infos ]]; then
        echo -e "$print_attention ${map_pk3##/*} does not contain a mapinfo file."
        continue
    fi
    for map_info in $map_infos; do
        if [[ -f "$userdir/$data_dirname/maps/$map_info" ]]; then
            echo -e "$print_info $map_info already exists."
        else
            echo -e "$print_info Extract $map_info of ${map_pk3##*/}."
            unzip -qnj -d "$userdir/$data_dirname/maps"  $map_pk3 maps/$map_info
        fi
    done
done
} # end of server_mapinfo_extract()

# show the difference of a mapinfo file in pk3 package and in data/maps
function server_mapinfo_diff() {
while getopts ":d:" options; do
    case $options in
        d) data_dirname="${OPTARG%/}";;
    esac
done
shift $((OPTIND-1))
[ -z $data_dirname ] && data_dirname=data
if [[ ! -d "$userdir/$data_dirname" ]]; then
     echo -e >&2 "$print_error Data folder $data_dirname does not exist."
     exit 1
fi
server_mapinfo_check_first $1
for map_pk3 in "$@"; do
    server_mapinfo_check $map_pk3
    echo $map_pk3 | grep '.pk3' &>/dev/null || echo -e "$print_error ${map_pk##*/} is not a pk3 file." >&2
    map_infos=$(unzip -l $map_pk3 |grep -v MACOSX| grep -Eo '[A-Za-z0-9#._+-]+\.mapinfo' |tr "\n" " ")
    if [[ -z $map_infos ]]; then
        echo -e "$print_attention $(basename $map_pk3) does not contain a mapinfo file."
        echo -e "            Cannot compare."
        continue
    fi
    for map_info in $map_infos; do
        if [[ -f "$userdir/$data_dirname"/maps/$map_info ]]; then
            echo -e "$print_info Difference of "$data_dirname/maps/$map_info" and $map_pk3:"
            diff "$userdir/$data_dirname"/maps/$map_info <(unzip -pq $map_pk3 maps/$map_info) &&
            echo "       No Difference."
        else
            echo -e "$print_attention Cannot compare files: "$userdir/$data_dirname"/maps/$map_info does not exist"
        fi
    done
done
} # end of server_mapinfo_diff()

# show the difference of all mapinfo files in pk3 package and in data/maps
function server_mapinfo_diff_all() {
while getopts ":rgd:p:" options; do
    case $options in
        d) data_dirname="${OPTARG%/}";;
        p) [ ! -d $OPTARG ] && echo -e >&2 "$print_error Folder ${OPTARG%/} does not exist." && exit 1;
           package_folders="$package_folders ${OPTARG%/}";;
    esac
done
shift $((OPTIND-1))
[ -z $data_dirname ] && data_dirname=data || data_dirname=$(echo $data_dirname|sed 's#/$##g')
if [[ ! -d "$userdir/$data_dirname" ]]; then
     echo -e >&2 "$print_error Data folder $data_dirname does not exist."
     exit 1
fi
[  "x$package_folders" = x ] && package_folders="$userdir/packages"
for folder in $package_folders; do
    # no mapinfo in this directory.. then continue with next one
    ls $folder/*.pk3 &>/dev/null || continue
    for map_pk3 in $folder/*.pk3; do
        echo $map_pk3 | grep '.pk3' &>/dev/null || echo -e "$print_error ${map_pk3##*/} is not a pk3 file." >&2
        map_infos=$(unzip -l $map_pk3 |grep -v MACOSX| grep -Eo '[A-Za-z0-9#._+-]+\.mapinfo' |tr "\n" " ")
        if [[ -z $map_infos ]]; then
            continue
        fi
        for map_info in $map_infos; do
            if [[ -f "$userdir/$data_dirname/maps/$map_info" ]]; then
                if ! diff "$userdir/$data_dirname/maps/$map_info" <(unzip -pq $map_pk3 maps/$map_info) &>/dev/null; then
                    echo -e "$print_info Difference of $data_dirname/maps/$map_info and $map_pk3:"
                    diff "$userdir/$data_dirname/maps/$map_info" <(unzip -pq $map_pk3 maps/$map_info)
                fi
            fi
        done
    done
done
} # end of server_mapinfo_diff_all()

# show mapinfo files of pk3 packages and if exists in $data_dirname/maps
function server_mapinfo_show() {
while getopts ":d:" options; do
    case $options in
        d) data_dirname="${OPTARG%/}";;
    esac
done
shift $((OPTIND-1))
if [[ -n $data_dirname && ! -d "$userdir/$data_dirname" ]]; then
     echo -e >&2 "$print_error Data folder $data_dirname does not exist."
     exit 1
else
    data_dirname=data
fi
server_mapinfo_check_first $1
for map_pk3 in "$@"; do
    server_mapinfo_check $map_pk3
    echo $map_pk3 | grep '.pk3' &>/dev/null || echo -e "$print_error ${map_pk3##*/} is not a pk3 file." >&2
    map_infos=$(unzip -l $map_pk3 |grep -v MACOSX| grep -Eo '[A-Za-z0-9#._+-]+\.mapinfo' |tr "\n" " ")
    if [[ -z $map_infos ]]; then
        echo -e "$print_attention ${map_pk3##*/} does not contain a mapinfo."
        continue
    fi
    for map_info in $map_infos; do
        if [[ -d "$userdir/$data_dirname" ]]; then
            if [[ -f "$userdir/$data_dirname/maps/$map_info" ]]; then
                echo -e "$print_info $data_dirname/maps/$map_info:"
                cat "$userdir/$data_dirname/maps/$map_info"
            else
                echo -e "$print_info $data_dirname/maps/$map_info does not exist."
            fi
        fi
        echo -e "$print_info ${map_pk3##*/} - $map_info:"
        unzip -pq $map_pk3 maps/$map_info
    done
done
} # end of server_mapinfo_show()

# reduce server console errors messages
# replace type 'type' with 'gametype', mv autogenerated mapinfo files
function server_mapinfo_fix() {
while getopts ":rgd:p:" options; do
    case $options in
        d) data_dirname="${OPTARG%/}";;
        p) [ ! -d $OPTARG ] && echo -e >&2 "$print_error Folder ${OPTARG%/} does not exist." && exit 1;
           package_folders="$package_folders ${OPTARG%/}";;
    esac
done
shift $((OPTIND-1))
[ -z $data_dirname ] && data_dirname=data
if [[ ! -d "$userdir/$data_dirname" ]]; then
     echo -e >&2 "$print_error Data folder $data_dirname does not exist."
     exit 1
fi
[  "x$package_folders" = x ] && package_folders="$userdir/packages"
echo -e "$print_info Fix mapinfos in $data_dirname/maps"
for map_info_l in "$userdir/$data_dirname/maps/*.mapinfo"; do
    sed -i -e 's/^type /gametype /g'\
           -e 's/^gametype freezetag/gametype ft/g'\
           -e 's/^gametype keepaway/gametype ka/g'\
           -e 's/^gametype nexball/gametype nb/g' $map_info_l &>/dev/null
done
echo -e "$print_info Scanning pk3 packages and fix them"
echo -e "       Existing mapinfos are not overwritten."
for folder in $package_folders; do
    # no pk3 files in this directory.. then continue with next one
    ls $folder/*.pk3 &>/dev/null || continue
    for map_pk3 in $folder/*.pk3; do
        map_infos=$(unzip -l $map_pk3 |grep -v MACOSX| grep -Eo '[A-Za-z0-9#._+-]+\.mapinfo' |tr "\n" " ")
        if [[ -z $map_infos ]]; then
            continue
        fi
        for map_info in $map_infos; do
            if [[ -f "$userdir/$data_dirname/maps/$map_info" ]]; then
                continue
            elif unzip -qp $map_pk3 maps/$map_info |grep -E '(^type )|(^gametype (freezetag)|(keepaway)|(nexball))' &>/dev/null; then
                unzip -qjn -d "$userdir/$data_dirname/maps/" $map_pk3 maps/$map_info
                sed -i -e 's/^type /gametype /g'\
                       -e 's/^gametype freezetag/gametype ft/g'\
                       -e 's/^gametype keepaway/gametype ka/g'\
                       -e 's/^gametype nexball/gametype nb/g' $map_info_l &>/dev/null
            fi
        done
    done
done
if [[ -d "$userdir/$data_dirname/data/maps/autogenerated" ]]; then
    echo -e "$print_info Move autogenerated maps into $data_dirname/maps"
    mv -i "$userdir/$data_dirname/data/maps/autogenerated/"*.mapinfo "$userdir/$data_dirname/maps/"
    if [[ -d "$userdir/$data_dirname/data/maps/autogenerated" ]]; then
        rmdir "$userdir/$data_dirname/data/maps/autogenerated"
    fi
fi
} # end of server_mapinfo_fix()
# }}}

### --- rcon2irc funtions
# {{{
function rcon2irc_first_config_check() {
if [[ "$1" == "" ]]; then
    echo >&2 "Bot name missing. Check -h or --help"
    exit 1
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
    echo >&2 -e "$print_error No config file available for '$rcon2irc_name'"
    exit 1
fi
} # end of rcon2irc_config_check_and_set()

function rcon2irc_check_start() {
# check if rcon2irc has been started successfull othewise tell 'Use --rcon2irc attach...'
# it seems that we need a small time periode until process is in process list ps o cmd
sleep 1
if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
    echo -e "$print_info rcon2irc '$rcon2irc_name' has been started."
else
    echo >&2 -e "$print_error Starting rcon2irc '$rcon2irc_name' failed."
    echo >&2 -e "        Use '--rcon2irc attach $rcon2irc_name' to check window status."
fi
} # end of rcon2irc_check_start()

function rcon2irc_start() {
rcon2irc_first_config_check $1
for rcon2irc_name in $@; do
    rcon2irc_config_check_and_set $rcon2irc_name
done
for var in $@; do
# check if $var exists and set our variables:
rcon2irc_config_check_and_set $var
    # option 1: rcon2irc is already running
    # in this case: print error and continue with for loop
    if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
        echo -e "$print_attention rcon2irc '$rcon2irc_name' is already running."
        continue
    fi
    # option 2: rcon2irc is not running, tmux session does not exist
    # in this case: start a new tmux session, with new window and start rcon2irc
    if ! tmux list-sessions 2>/dev/null| grep "$tmux_session:" &>/dev/null; then
        if [[ -f $HOME/.tmux.conf && -z $xstools_tmux ]]; then
            TMUX=`which tmux`
        else
            TMUX="`which tmux` -f $xstool_dir/configs/.tmux.conf"
        fi
        $TMUX new-session -d -n $tmux_window -s $tmux_session
        tmux send -t $tmux_session:$tmux_window "cd $rcon2irc_config_folder && perl $rcon2irc_script $rcon2irc_config" C-m
        rcon2irc_check_start
    # option 3: rcon2irc is not running; tmux session exists, and window already exists
    # in this case: print error and continue with for loop
    elif tmux list-windows -t $tmux_session | grep "$tmux_window " &>/dev/null; then
        echo >&2 -e "$print_error rcon2irc '$rcon2irc_name' does not run, but tmux window '$tmux_window' exists."
        echo >&2 -e "        Use '--rcon2irc attach $rcon2irc_name' to check window status."
        continue
    else
    # option 4; rcon2irc is not running, tmux session exists, window does not exist
    # in this case: start a new window in tmux session and start rcon2irc
        tmux new-window -d -n $tmux_window -t $tmux_session
        tmux send -t $tmux_session:$tmux_window "cd $rcon2irc_config_folder && perl $rcon2irc_script $rcon2irc_config" C-m
        rcon2irc_check_start
    fi
done
} # end of rcon2irc_start()

function rcon2irc_start_all() {
 for conf in $(ls $userdir/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
 conf_name=$(basename ${conf%.rcon2irc.conf})
 rcon2irc_start $conf_name
 done
} # end of rcon2irc_start_all()

function rcon2irc_stop() {
rcon2irc_first_config_check $1
for rcon2irc_name in $@; do
    rcon2irc_config_check_and_set $rcon2irc_name
done
for var in $@; do
rcon2irc_config_check_and_set $var
    if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            rcon_pid=$(ps o pid,cmd | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep | awk '{print $1}')
            kill -9 $rcon_pid
            sleep 1
            tmux send -t $tmux_session:$tmux_window "exit" C-m
            echo -e "$print_info rcon2irc '$rcon2irc_name' has been stopped."
        else
            echo -e >&2 "$print_error tmux window '$tmux_window' does not exist, but rcon2irc '$rcon2irc_name' is running."
            echo -e >&2 "        You have to fix this on your own."
        fi
    else
        echo -e "$print_attention rcon2irc '$rcon2irc_name' was not found."
    fi
done
} # end of rcon2irc_stop()

function rcon2irc_stop_all() {
# we can only stop running rcon2irc bots and only those which are in our tmux windows
for conf in $(ls "$userdir"/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
    rcon2irc_config_check_and_set $(basename ${conf%.rcon2irc.conf})
    # nearly the same if statement like rcon2irc_stop
    if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            rcon_pid=$(ps o pid,cmd | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep | awk '{print $1}')
            kill -9 $rcon_pid
            sleep 1
            tmux send -t $tmux_session:$tmux_window "exit" C-m
            echo -e "$print_info rcon2irc '$rcon2irc_name' has been stopped."
        else
            echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but rcon2irc '$rcon2irc_name' is running."
            echo >&2 -e "        You have to fix this on your own."
        fi
    fi
done
} # end of rcon2irc_stop_all()

function rcon2irc_restart() {
rcon2irc_first_config_check $1
for rcon2irc_name in $@; do
    rcon2irc_config_check_and_set $rcon2irc_name
done
for var in $@; do
rcon2irc_config_check_and_set $var
    # We can only restart a server if server is running and tmux session exists
    if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep ) ]]; then
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            rcon_pid=$(ps o pid,cmd | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep | awk '{print $1}')
            echo -e "$print_info Restarting rcon2irc '$rcon2irc_name'"
            kill -9 $rcon_pid
            sleep 1
            tmux send -t $tmux_session:$tmux_window "perl $rcon2irc_script $rcon2irc_config" C-m
            sleep 1
            if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
                echo -e "       rcon2irc '$rcon2irc_name' has been restarted."
            else
                echo >&2 -e "$print_error Starting rcon2irc '$rcon2irc_name' failed."
                echo >&2 -e "        Use '--rcon2irc attach $rcon2irc_name' to check window status."
            fi
        else
            echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$rcon2irc_name' is running."
            echo >&2 -e "        You have to fix this on your own."
        fi
    else
    echo >&2 -e "$print_error rcon2irc '$rcon2irc_name' is not running, cannot stop."
    fi
done
} # end of rcon2irc_restart()

function rcon2irc_restart_all() {
for conf in $(ls $userdir/configs/rcon2irc/*.rcon2irc.conf 2>/dev/null); do
    rcon2irc_config_check_and_set $(basename ${conf%.rcon2irc.conf})
    if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null |grep -v grep) ]]; then
        if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
            rcon_pid=$(ps o pid,cmd | grep "perl $rcon2irc_script $rcon2irc_config"  2>/dev/null|grep -v grep | awk '{print $1}')
            echo -e "$print_info Restarting rcon2irc '$rcon2irc_name'"
            kill -9 $rcon_pid
            sleep 1
            tmux send -t $tmux_session:$tmux_window "perl $rcon2irc_script $rcon2irc_config" C-m
            sleep 1
            if [[ $(ps o cmd | grep "perl $rcon2irc_script $rcon2irc_config" 2>/dev/null |grep -v grep ) ]]; then
                echo -e "       rcon2irc '$rcon2irc_name' has been restarted."
            else
                echo >&2 -e "$print_error Starting rcon2irc '$rcon2irc_name' failed."
                echo >&2 -e "        Use '--rcon2irc attach $rcon2irc_name' to check window status."
            fi
        else
            echo >&2 -e "$print_error tmux window '$tmux_window' does not exist, but server '$rcon2irc_name' is running."
            echo >&2 -e "        You have to fix this on your own."
        fi
    fi
done
} # end of rcon2irc_restart_all() {

function rcon2irc_attach() {
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
    if tmux list-windows -t $tmux_session| grep "$tmux_window " &>/dev/null; then
        tmux select-window -t $tmux_session:$tmux_window
        tmux attach -t $tmux_session
    else
        echo >&2 -e "$print_error tmux window '$tmux_window' does not exist."
        echo >&2 -e "        Use '--list' to list all running bots."
    fi
done
} # end of rcon2irc_attach
# }}}

### --- help functions
# {{{
function xstools_help() {
cat << EOF
-- Commands --
xstools
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
    --send-rcon-all <command>        - send a command to all servers using rcon
    --send-rcon <server(s)>          - send a command to given server(s)
        -c <command>                   using rcon

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
EOF
}

function xstools_more_help() {
cat << EOF

Xonotic Server Tools is a collection of functions to manage your Xonotic
servers. Check Wiki for complete help.

----- Functions

--start-all             Start all servers whose configuration files are placed
                        in 'configs/servers'.
  Options:   -r         Start all servers as release servers.
             -a         Start all servers as autobuild servers.
             -g         Start all servers as git servers.
                        (otherwise use default)

--start <server(s)>     Start specific server(s).
  Options:   -r         Start given servers as release servers.
             -a         Start given servers as autobuild servers.
             -g         Start given servers as git servers.
                        (otherwise use default)

--stop-all              Stop all running servers..
  Options:  -r          Command only affects release servers.
            -a          Command only affects autobuild servers.
            -g          Command only affects git servers.
                        (otherwise command affects all servers)

--stop <server(s)>      Stop specific server(s).

  Options for both stop functions:
            -q          Quit server at endmatch and redirect all players
                        to given server (hostname+port).
            -n          Optional parameter in combination with -q. Directly
                        quit, do not wait for endmatch.
            -e          Quit server when empty and next level starts.
            -w          Optional parameter in combination with -e or -q.
                        xstools will not wait for server endmatch.
                        You have to close the tmux window on your own.

--restart-all           Restart all running server(s).
  Options:  -r          Command only affects release servers.
            -a          Command only affects git servers.
            -g          Command only affects git servers.
                        (otherwise command affects all servers)

--restart <server(s)>   Restart specific server(s).

  Options for both restart functions:
            -q          Restart server at endmatch and redirect all players
                        to given server (hostname+port).
            -s          Restart server at endmatch at let all players reconnect
            -n          Optional parameter in combination with -q or -s.
                        Directly restart, do not wait for endmatch.


--install-git           Download Xonotic Git and save it in the given basedir
                        folder. Check xtools.conf to adjust this.

--update-git            Update Xonotic git repository and restart all
                        git servers.
--update-autobuild      Update Xonotic autobuild basedir and restart all
                        autobuild servers.

  Options for both update functions:
            -q          Restart server at endmatch and redirect all players
                        to given server (hostname+port).
            -s          Restart at endmatch and let all players reconnect.
            -n          Optional parameter in combination with -q or -s.
                        Directly restart, do not wait for endmatch.


--list                  List all running servers and bots.

--list-configs          List all server and rcon2irc configuration files.

--attach <server(s)>    Attach a tmux window and show server console of
                        server(s).

--add-pk3 <url(s)>      Add .pk3 files to packages folder (set by -p) from
                        given urls and rescan for them at endmatch with
                        every server.
  Options: -p           Set the package folder (full path)
                        (if not set, default is used: packages)

--rescan                Rescan for new added packages at endmatch, every server

--send-all <command>    Send a command to all servers and receive output.

--send <server(s)>      Send a command to given servers and receive output.
      -c <command>      The beginning of command is defined by -c.

--send-rcon-all  <command>    Send a command to all servers and receive output.
                              (uses rcon)

--send-rcon <server(s)>       Send a command to given server(s) and receive
      -c <command>            output. The beginning of command is defined by -c
                              (uses rcon)

--logs set              Change the log file of all running servers to
                        'serverconfig.date.log', where 'serverconfig' is the
                        server name  and 'date' is 'YearMonthDay'.

--logs del              Delete older log files than given time in
                        days. Check xstools.conf to adjust this.
  Options: -d           Set the data folder where logs are located.
                        (default is data)

--maplist               Create a maplist for all gamtypes or use a regex.
  Options:  -a/-g/-r    Scan autobuild, release or git basedir.
                        to given server (hostname+port).
            -d          Define the name of data folder - default is data.
            -p          Define the package folder (full path).
                        - default is packages.
                        Examples:
                        ctf          --maplist ctf
                        ctf,lms,dm   --maplist '(ctf|lms|\bdm)'
                        Several package folders:
                        xst --mapinfo -p folder1 -p folder2 ...

--mapinfo               Syntax: --mapinfo command <options> <pk3(s)>
                        command is one of the following options:

        extract <pk3(s)>    Extract mapinfo files of given pk3 package(s)
                            to data folder name (set by -d).
          Options: -d       Set the name data folder to extract to.

        diff <pk3(s)>   Show difference between pk3 mapinfo
                        and mapinfo file in data folder (set by -d).
          Options: -d   Set the data folder name to compare with.

        diff-all        Same as 'diff' but for all pk3 packages in package
                        folder (set by -p) and mapinfos in data folder
                        (set by -d).
                        No output if comparing was not possible
                        No output if mapinfo files are the same.
          Options: -d   Set the data folder name to compare with.
                        -p   Set the package folder with pk3 files (full path).

        fix             Fix server console warnings by mapinfo files:
                        Replace 'type' with 'gametype'
                        Replace long gametype names with short ones
                        and move the autogenerated mapinfo files.
         Options: -d    Set the data folder name.
                  -p    Set the package folder (full path).

        show <pk3(s)>   Show mapinfo file of given pk3 package and mapinfo file
                        in data folder (set by -d).
          Options: -d   Set the data folder name.

-d and -p are optional. If options are not used default is set:
    data folder:    data
    package folder: /\$userdir/packages
To set several package folders use: xst --mapinfo -p folder1 -p folder2 ...

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

      attach <bot(s)>   Attach a tmux window and show bot console of bot(s).


--help                  print this help

-h                      print a list of available functions

A wiki can be found here: https://github.com/itsme-/xstools/wiki
Report bugs here: https://github.com/itsme-/xstools/issues

Created by: It'sMe
For any questions and help join #xstools, quakenet (IRC)

EOF
}
# }}}

### --- argument handlers
# {{{
function server_mapinfo_control() {
case $1 in
    --extract|extract)                 shift && server_mapinfo_extract "$@";;
    --diff|diff)                       shift && server_mapinfo_diff "$@";;
    --diff-all|diff-all)               shift && server_mapinfo_diff_all "$@";;
    --fix|fix)                         shift && server_mapinfo_fix "$@";;
    --show|show)                       shift && server_mapinfo_show "$@";;
    ""|*)            {
                     echo -e "$print_error Command is invalid or missing."
                     echo "        Use --mapinfo with one of this arguments:"
                     echo "        --extract <-d>"
                     echo "        --diff <-d>"
                     echo "        --diff-all <-dp>"
                     echo "        --fix <-dp>"
                     echo "        --show"
                     } >&2; exit 1;;
esac
}

function rcon2irc_control() {
if [[ ! -f "$rcon2irc_script" ]]; then
    echo >&2 -e "$print_error Could not find 'rcon2irc_script'."
    echo >&2 -e "        Check xstools.conf"
    exit 1
fi
case $1 in
 --start|start)                 shift && rcon2irc_start $@;;
 --stop|stop)                   shift && rcon2irc_stop $@;;
 --restart|restart)             shift && rcon2irc_restart $@;;
 --stop-all|stop-all)           rcon2irc_stop_all;;
 --start-all|start-all)         rcon2irc_start_all;;
 --restart-all|restart-all)     rcon2irc_restart_all;;
 --attach|attach|att)           shift && rcon2irc_attach $@;;
 ""|*)               {
                     echo -e "$print_error Command is invalid or missing."
                     echo "        Use --rcon2irc with one of this arguments:"
                     echo "            start-all"
                     echo "            start <bot(s)>"
                     echo "            stop-all"
                     echo "            stop <bots>"
                     echo "            restart-all"
                     echo "            restart <bot(s)>"
                     echo "            attach <bot(s)>"
                     } >&2; exit 1;;
esac
}

case $1 in
 --start-all|start-all)              basic_config_check; shift && server_start_all "$@";;
 --start|start)                      basic_config_check; shift && server_start_specific "$@";;
 --stop-all|stop-all)                basic_config_check; shift && server_stop_all "$@";;
 --stop|stop)                        basic_config_check; shift && server_stop_specific "$@";;
 --restart-all|restart-all)          basic_config_check; shift && server_restart_all "$@";;
 --restart|restart)                  basic_config_check; shift && server_restart_specific "$@";;
 --install-git|install-git)          basic_config_check; install_git;;
 --update-git|update-git)            basic_config_check; shift && server_update_git "$@";;
 --update-autobuild|update-autobuild)   basic_config_check; shift && server_update_autobuild "$@";;
 --list|list|ls)                     basic_config_check; xstools_list_all;;
 --list-configs|list-configs)        basic_config_check; xstools_list_configs;;
 --attach|attach|att)                basic_config_check; shift && server_attach "$@";;
 --add-pk3|add-pk3)                  basic_config_check; shift && server_add_pk3 "$@";;
 --rescan|rescan)                    basic_config_check; server_send_rescan;;
 --send|send)                        basic_config_check; shift && server_send "$@";;
 --send-all|send-all)                basic_config_check; shift && sendall=true && server_send "$@";;
 --send-rcon|send-rcon)              basic_config_check; shift && server_send_rcon "$@";;
 --send-rcon-all|send-rcon-all)      basic_config_check; shift && sendall=true && server_send_rcon "$@";;
 --logs|logs)                        basic_config_check; shift && server_logs "$@";;
 --maplist|maplist)                  basic_config_check; shift && server_maplist "$@";;
 --mapinfo|mapinfo)                  basic_config_check; shift && server_mapinfo_control "$@";;
 --rcon2irc|rcon2irc)                basic_config_check; shift && rcon2irc_control "$@";;
 --help|--usage|help|usage)          xstools_more_help | less;;
 -h|h)                               xstools_help;;
 "")                                 echo >&2 "xstools needs an argument, check -h or --help"; exit 1;;
 *)                                  echo >&2 "This is not a valid argument! Check -h or --help"; exit 1;;
esac
# }}}

# vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0

