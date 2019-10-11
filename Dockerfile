#If changing the tag for this image you must check compatibility with 
# Spark submission to Kubernetes API as it was broken in all versions between
# 29a003bb3030 and 1386e2046833 (latest at time of writing)
FROM jupyter/pyspark-notebook:29a003bb3030

ENV NB_USER datalab
ENV NB_UID 1000
ENV NB_GID 100
ENV HOME /home/datalab
ENV CONDA_DIR /opt/conda
WORKDIR /home/$NB_USER/work

USER root
# Set up Datalab user (replacing default jovyan user)
RUN usermod -l $NB_USER -d /home/$NB_USER jovyan && \
    mkdir -p $CONDA_DIR/pkgs/cache && \
    chown -R $NB_USER:$NB_GID /home/$NB_USER $CONDA_DIR/pkgs/cache && \
    fix-permissions $CONDA_DIR

USER $NB_UID

# Add Git integration
RUN pip install --no-cache-dir jupyterlab-git && \
    jupyter labextension install @jupyterlab/git && \
    jupyter serverextension enable --py jupyterlab_git --sys-prefix

# Add support for Widgets & Plots
RUN pip install --no-cache-dir ipywidgets \
      ipyleaflet && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    jupyter labextension install jupyter-leaflet && \
    jupyter labextension install @jupyterlab/plotly-extension

# Bake Dask/Dask-Kubernetes libraries into base Conda Environment
RUN conda install -y \
      dask=2.4 \
      distributed=2.4 \
      dask-kubernetes=0.9.2 \
      dask-gateway=0.3.0 \
      bokeh=1.3 \
      jupyter-server-proxy=1.1 \
      tornado=6 \
      graphviz=2.40 \
      nbgitpuller=0.7

USER root

RUN apt-get update && apt-get install -yq --no-install-recommends \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Hotfix to remove temporary local files created during build causing problems and fix permissions on pkg cache
# Similiar to;
#  https://github.com/docker/for-linux/issues/433
#  https://stackoverflow.com/questions/52214178/file-permission-displayed-a-lot-question-marks-in-docker-container
RUN rm -rf /home/$NB_USER/.local/ /home/$NB_USER/.config/ && \
    mkdir -p $CONDA_DIR/pkgs/cache && \
    chown -R $NB_UID:$NB_GID /home/$NB_USER $CONDA_DIR/pkgs/cache

# Add env-control executable to control creation/deletion of Conda Environments
COPY env-control /usr/local/bin/env-control
# Make env-control executable
RUN chmod 755 /usr/local/bin/env-control

USER $NB_UID