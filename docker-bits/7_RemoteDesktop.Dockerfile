# Based heavily off of https://github.com/ConSol/docker-headless-vnc-container
#I 'know' to how i18nize but keep everything in English for now. 

#FROM ubuntu:18.04

## Connection ports for controlling the UI:
# VNC port:5901 
## I will not 'require' this VNC port as this is for the VNC server. 
## This would need to be jupyter server proxy done. 


# noVNC webport, connect via http://IP:6901/?password=vncpassword
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT

### Envrionment config
#for NOW keep as headless. 
ENV HOME=/headless \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/headless/install \
    NO_VNC_HOME=/headless/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false
WORKDIR $HOME

### Add all install scripts for further steps
#scripts/remote-desktop 
COPY remote-desktop/common/install/ $INST_SCRIPTS/
COPY remote-desktop/ubuntu/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -name '*.sh' -exec chmod a+x {} +

### Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN $INST_SCRIPTS/install_custom_fonts.sh

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc.sh

### Install firefox and chrome browser
RUN $INST_SCRIPTS/firefox.sh

### Install xfce UI
RUN $INST_SCRIPTS/xfce_ui.sh
COPY remote-desktop/common/xfce/ $HOME/

#Ubuntu 20 Patch
# https://github.com/ConSol/docker-headless-vnc-container/issues/96#issuecomment-687112199 
# because the /headless/noVNC/utils/launch.sh script is lacking a python2 interpreter. 
# sufficient to link to python interpreter in the Dockerfile:
RUN ln -s `which python2` /usr/bin/python

### configure startup
#Normally this is in the infinity_CMD Dockerfile, but remote desktop starts up differently than the others.
RUN $INST_SCRIPTS/libnss_wrapper.sh
COPY remote-desktop/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME

# Remove light locker
RUN apt-get remove -y -q light-locker

#Building w/o this pip install works
RUN python3 -m pip install \
      'git+git://github.com/Ito-Matsuda/jupyter-desktop-server#egg=jupyter-desktop-server'
#End comment context


#Commented out to check things
#USER 1000

#ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
#CMD ["--wait"]

#This is exacty whats in the infinity dockerfile
WORKDIR /home/$NB_USER
EXPOSE 8888
COPY remote-desktop/common/scripts/vnc_startup.sh /usr/local/bin/
USER $NB_USER
ENTRYPOINT ["tini", "--"]
CMD ["vnc_startup.sh"]
