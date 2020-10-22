ARG BASE_CONTAINER
FROM $BASE_CONTAINER
USER root

# Install Kale python SDK and jupyterlab extension
RUN pip install --no-cache-dir kubeflow-kale && \
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
