ARG BASE_CONTAINER
FROM $BASE_CONTAINER
USER root

# Build Kale labextension from source (includes fix below that was added after v0.5.1)
# https://github.com/kubeflow-kale/kale/pull/249

RUN PAST_CWD=$(pwd) && \
	KALE_SHA=93e6713281705a3b2376704633709e7ebb5e9514 && \
	pip install --no-cache-dir "git+http://github.com/kubeflow-kale/kale.git@${KALE_SHA}#egg=version_subpkg&subdirectory=backend" && \
    git clone https://github.com/kubeflow-kale/kale.git && \
    cd kale && \
    git reset --hard $KALE_SHA && \
    cd labextension && \
    npm install && \
    npm run build && \
    jupyter labextension install && \
    jupyter lab clean && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd $PAST_CWD

# # Install Kale python SDK (from master branch) and jupyterlab extension
# RUN pip install --no-cache-dir "git+http://github.com/kubeflow-kale/kale.git@b4e7a9b719b16dfc923d6fda45b8d7c696618874#egg=version_subpkg&subdirectory=backend" && \
#     jupyter labextension install --no-build \
#       'kubeflow-kale-labextension' \
#     jupyter lab build && \
#     jupyter lab clean && \
#     fix-permissions $CONDA_DIR && \
#     fix-permissions /home/$NB_USER

# Configure container startup
EXPOSE 8888
USER jovyan
ENTRYPOINT ["tini", "--"]
CMD ["start-custom.sh"]
