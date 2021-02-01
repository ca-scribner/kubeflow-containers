#!/bin/bash
### every exit != 0 fails the script
set -e

## print out help
help (){
echo "
USAGE:
docker run -it -p 6901:6901 -p 5901:5901 consol/<image>:<tag> <option>

IMAGES:
consol/ubuntu-xfce-vnc

OPTIONS:
-s, --skip      skip the vnc startup and just execute the assigned command.
                example: docker run consol/centos-xfce-vnc --skip bash
-d, --debug     enables more detailed startup output
                e.g. 'docker run consol/centos-xfce-vnc --debug bash'
-h, --help      print out this help

Fore more information see: https://github.com/ConSol/docker-headless-vnc-container
"
}
if [[ $1 =~ -h|--help ]]; then
    help
    exit 0
fi

# should also source $STARTUPDIR/generate_container_user
source $HOME/.bashrc

#Average use is docker run --rm -p 6901:6901 -p 5901:5901 imagename

# add `--skip` to startup args, to skip the VNC startup procedure
#keep in comment for now, but make green so i glaze over it. 
#if [[ $1 =~ -s|--skip ]]; then
#    echo -e "\n\n------------------ SKIP VNC STARTUP -----------------"
#    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
#    echo "Executing command: '${@:2}'"
#    exec "${@:2}"
#fi
#if [[ $1 =~ -d|--debug ]]; then
#    echo -e "\n\n------------------ DEBUG VNC STARTUP -----------------"
#    export DEBUG=true
#fi

## correct forwarding of shutdown signal
cleanup () {
    kill -s SIGTERM $!
    exit 0
}
trap cleanup SIGINT SIGTERM

## resolve_vnc_connection
VNC_IP=$(hostname -i)

#base password we should keep at (for now) vncpassword. 
## change vnc password
echo -e "\n------------------ change VNC password  ------------------"
# first entry is control, second is view (if only one is valid for both)
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.vnc/passwd"

if [[ -f $PASSWD_PATH ]]; then
    echo -e "\n---------  purging existing VNC password settings  ---------"
    rm -f $PASSWD_PATH
fi

if [[ $VNC_VIEW_ONLY == "true" ]]; then
    echo "start VNC server in VIEW ONLY mode!"
    #create random pw to prevent access
    echo $(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20) | vncpasswd -f > $PASSWD_PATH
fi
echo "$VNC_PW" | vncpasswd -f >> $PASSWD_PATH
chmod 600 $PASSWD_PATH

#end password shenanifans

#BEGIN PASTE OF MOVING G1
echo -e "\n------------------ start VNC server ------------------------"
echo "remove old vnc locks to be a reattachable container"
#this doesn't seem to get executed or anything.
vncserver -kill $DISPLAY &> $STARTUPDIR/vnc_startup.log \
    || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $STARTUPDIR/vnc_startup.log \
    || echo "no locks present"

echo -e "start vncserver with param: VNC_COL_DEPTH=$VNC_COL_DEPTH, VNC_RESOLUTION=$VNC_RESOLUTION\n..."
#useless debug for me
#if [[ $DEBUG == true ]]; then echo "vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION"; fi
#starts the tigervnc server. 
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION &> $STARTUPDIR/no_vnc_startup.log
echo -e "start window manager\n..."
#yea a simple startup
$HOME/wm_startup.sh &> $STARTUPDIR/wm_startup.log

#END PASTE OF MOVING


## start vncserver and noVNC webclient
#why does noVNC start before the vnc server? is this necessary?
echo -e "\n------------------ start noVNC  ----------------------------"
#useless debug since i can just see the values
#if [[ $DEBUG == true ]]; then echo "$NO_VNC_HOME/utils/launch.sh --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT"; fi

#comes from novnc. --vnc is the server+port
#localhost will probably need to change to use WORKSPACE_BASE_URL_DECODED or something like that
#"Starts the WebSockets proxy and a mini-webserver and provides a cut-and-paste URL to go to."
#--listen PORT         Port for proxy/webserver to listen on Default: 6080"
#--vnc VNC_HOST:PORT   VNC server host:port proxy target Default: localhost:5900"

$NO_VNC_HOME/utils/launch.sh --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT &> $STARTUPDIR/no_vnc_startup.log &
PID_SUB=$!
#does the vnc and listen and outputs to log as well as get s the process id. 

#PASTE BELOW HERE G1


#END PASTE



## log connect options
echo -e "\n\n------------------ VNC environment started ------------------"
echo -e "\nVNCSERVER started on DISPLAY= $DISPLAY \n\t=> connect via VNC viewer with $VNC_IP:$VNC_PORT"
echo -e "\nnoVNC HTML client started:\n\t=> connect via http://$VNC_IP:$NO_VNC_PORT/?password=...\n"

#Everything past this point is useless I think 

#guess we can keep this... 
if [[ $DEBUG == true ]] || [[ $1 =~ -t|--tail-log ]]; then
    echo -e "\n------------------ $HOME/.vnc/*$DISPLAY.log ------------------"
    # if option `-t` or `--tail-log` block the execution and tail the VNC log
    tail -f $STARTUPDIR/*.log $HOME/.vnc/*$DISPLAY.log
fi

#dont need this, can probably remove?  
if [ -z "$1" ] || [[ $1 =~ -w|--wait ]]; then
    wait $PID_SUB
else
    # unknown option ==> call command
    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
    echo "Executing command: '$@'"
    exec "$@"
fi
