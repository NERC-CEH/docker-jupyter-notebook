FROM centos:6

LABEL maintiner "joshua.foster@stfc.ac.uk"

ENV MINICONDA_VERSION 4.3.21
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH
ENV SHELL /bin/bash
ENV NB_USER datalab
ENV NB_UID 1000
ENV HOME /home/$NB_USER

USER root

# Add EPEL and ceda repos. Remove conflicting packages and prevent specific
# packages from updating using the EPEL repo. Install JASMIN Scientific 
# Analysis Platform (JAP).
RUN yum install -y epel-release && \
    rpm -Uvh http://dist.ceda.ac.uk/yumrepo/RPMS/ceda-yumrepo-0.1-1.ceda.el6.noarch.rpm && \
    sed -i '/\[epel\]/a exclude=grib_api* geos* gdal* grass* GraphicsMagick*' /etc/yum.repos.d/epel.repo && \
    yum install -y jasmin-sci-vm

# Add wget, jq, libcurl and sudo
RUN yum install -y wget jq libcurl-devel sudo && \
    yum clean all

# Install Tini
RUN wget -O /tmp/tini https://github.com/krallin/tini/releases/download/v0.15.0/tini && \
    mv /tmp/tini /usr/bin/tini && \
    rm -rf /tmp/tini && \
    chmod +x /usr/bin/tini

# Add datalab user
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown -R $NB_USER $CONDA_DIR

USER $NB_USER

# Install conda
RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda update --all && \
    conda clean -tipsy

# Install Jupyter Notebook and Hub
RUN conda install --quiet --yes \
    'notebook=5.0.*' \
    'jupyterhub=0.7.*' \
    'jupyterlab=0.24.*' \
    && conda clean -tipsy

# Install JAP Python as a kernel in Jupyter
RUN virtualenv --system-site-packages $HOME/python &&  \
    $HOME/python/bin/pip install 'six>=1.6.0' &&  \
    $HOME/python/bin/pip install ipykernel &&  \
    $HOME/python/bin/python -m ipykernel install --user --name=python2 --display-name="Python 2.7 (JAP)" &&  \
    cat $HOME/.local/share/jupyter/kernels/python2/kernel.json |  \
      jq ". |= . + { \"env\": { \"PATH\" : \"$HOME/python/bin:$PATH\" } }" > /tmp/python2.kernel.json &&  \
    mv /tmp/python2.kernel.json $HOME/.local/share/jupyter/kernels/python2/kernel.json &&  \
    rm -f /tmp/python2.kernel.json

# Install JAP R as a kernel in Jupyter
RUN mkdir -p $HOME/R-libs &&  \
    echo -e ".libPaths('$HOME/R-libs')\n" > $HOME/.Rprofile &&  \
    R -q -e "install.packages(c('repr', 'IRdisplay', 'crayon', 'pbdZMQ', 'devtools'), repos='https://cloud.r-project.org/')" && \
    R -q -e "devtools::install_github('IRkernel/IRkernel')" &&  \
    R -q -e "IRkernel::installspec(displayname = 'R (JAP)', rprofile = '$HOME/.Rprofile')"

USER root

EXPOSE 8888

WORKDIR $HOME

# Clone jupyter base-notebook scripts
RUN wget -O /usr/local/bin/start.sh https://raw.githubusercontent.com/jupyter/docker-stacks/8f56e3c47fec4ff1a8a78b3883b1dccfe0e3f272/base-notebook/start.sh
RUN wget -O /usr/local/bin/start-notebook.sh https://raw.githubusercontent.com/jupyter/docker-stacks/8f56e3c47fec4ff1a8a78b3883b1dccfe0e3f272/base-notebook/start-notebook.sh
RUN wget -O /usr/local/bin/start-singleuser.sh https://raw.githubusercontent.com/jupyter/docker-stacks/8f56e3c47fec4ff1a8a78b3883b1dccfe0e3f272/base-notebook/start-singleuser.sh
RUN chmod +x /usr/local/bin/*.sh
RUN mkdir /etc/jupyter -p
RUN wget -O /etc/jupyter/jupyter_notebook_config.py https://raw.githubusercontent.com/jupyter/docker-stacks/8f56e3c47fec4ff1a8a78b3883b1dccfe0e3f272/base-notebook/jupyter_notebook_config.py
RUN chown -R $NB_USER:users /etc/jupyter/ 

ENTRYPOINT ["tini", "--"]
CMD ["start-notebook.sh"]

USER $NB_USER
