ARG BASE_CONTAINER
FROM $BASE_CONTAINER
USER root

# Install Kale python SDK (from master branch) and jupyterlab extension
RUN pip install --no-cache-dir "git+http://github.com/kubeflow-kale/kale.git@b4e7a9b719b16dfc923d6fda45b8d7c696618874#egg=version_subpkg&subdirectory=backend" && \
    jupyter labextension install --no-build \
      'kubeflow-kale-labextension' \
    jupyter lab build && \
    jupyter lab clean && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Configure container startup
EXPOSE 8888
USER jovyan
ENTRYPOINT ["tini", "--"]
CMD ["start-custom.sh"]
