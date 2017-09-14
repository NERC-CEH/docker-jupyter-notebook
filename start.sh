#!/bin/bash
# Modified from the jupyter base-notebook start.sh script
# https://github.com/jupyter/docker-stacks/blob/master/base-notebook/start.sh

set -e

# If root user
if [ $(id -u) == 0 ] ; then
  # Only the username "datalab" was created in docker build, 
  # therefore rename "datalab" to $NB_USER
  usermod -d /home/$NB_USER -l $NB_USER datalab

  # Change UID of NB_USER to NB_UID if it does not match.
  if [ "$NB_UID" != $(id -u $NB_USER) ] ; then
    echo "Set user UID to: $NB_UID"
    usermod -u $NB_UID $NB_USER

  # R_LIBS_SITE path has contains R version which need to be to be set by R.
  R_LIBS_SITE_FIXED=$(R --slave -e "write(gsub('%v', R.version\$minor,Sys.getenv('R_LIBS_SITE')), stdout())")

  # Fix permissions for home and jupyter directories
    for d in "$CONDA_DIR" "$SPARK_HOME" "$R_LIBS_SITE_FIXED" "/etc/jupyter" "/home/$NB_USER"; do
      if [[ ! -z "$d" && -d "$d" ]]; then
        echo "Set ownership to uid $NB_UID: $d"
        chown -R $NB_UID "$d"
      fi
    done
  fi

  # Change GID of NB_USER to NB_GID, if given.
  if [ "$NB_GID" ] ; then
    echo "Change GID to $NB_GID"
    groupmod -g $NB_GID -o $(id -g -n $NB_USER)
  fi

  # Grant sudo permissions
  if [[ "$GRANT_SUDO" == "1" || "$GRANT_SUDO" == 'yes' ]]; then
    echo "Granting $NB_USER sudo access"
    echo "$NB_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook
  fi

  # Exec jupyter docker-entrypoint as $NB_USER
  echo "Execute the command as $NB_USER"
  exec su $NB_USER -c "env PATH=$PATH $*"
else
  if [[ ! -z "$NB_UID" && "$NB_UID" != "$(id -u)" ]]; then
    echo 'Container must be run as root to set $NB_UID'
  fi
  if [[ ! -z "$NB_GID" && "$NB_GID" != "$(id -g)" ]]; then
    echo 'Container must be run as root to set $NB_GID'
  fi
  if [[ "$GRANT_SUDO" == "1" || "$GRANT_SUDO" == 'yes' ]]; then
    echo 'Container must be run as root to grant sudo permissions'
  fi
  echo "Execute the command"
  exec $*
fi
