
###############################
###  .tmp/CPU.Dockerfile
###############################


###############################
###  docker-bits/0_CPU.Dockerfile
###############################

ARG BASE_VERSION=r-4.0.3
FROM jupyter/datascience-notebook:$BASE_VERSION

USER root
ENV PATH="/home/jovyan/.local/bin/:${PATH}"

RUN apt-get update --yes \
    && apt-get install --yes language-pack-fr \
    && rm -rf /var/lib/apt/lists/*

###############################
###  docker-bits/∞_CMD.Dockerfile
###############################

# Configure container startup

WORKDIR /home/$NB_USER
EXPOSE 8888
COPY start-custom.sh /usr/local/bin/
COPY mc-tenant-wrapper.sh /usr/local/bin/mc 
USER $NB_USER
ENTRYPOINT ["tini", "--"]
CMD ["start-custom.sh"]
