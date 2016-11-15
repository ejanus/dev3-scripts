#!/bin/bash

## Help menu
print_help() {
  cat <<-HELP
This script is used to REMOVE vhost, helpful aliases and hosts entries for a site

You will need to provide the following:

--project_name=[project_name] (must not contain spaces)

Example - default usage:
bash ${0##*/} --project_name=mysite

HELP
  exit 0
}


# must run with sudo
if [ $(id -u) != 0 ]; then
  printf "***************************************\n"
  printf "* Error: You must run this with sudo. *\n"
  printf "***************************************\n"
  print_help
  exit 1
fi

###############################
### process input variables ###
###############################

# Parse Command Line Arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --project_name=*)
      project_name="${1#*=}"
      ;;
    --help)
      print_help
      ;;
    *)
      printf "************************************************************\n"
      printf "* Error: Invalid argument, run --help for valid arguments. *\n";
      printf "************************************************************\n"
      exit 1
  esac
  shift
done

##################
### prep-input ###
##################

if [ -z "${project_name}" ]; then
  printf "*****************************************\n"
  printf "* Error: Please provide a project name. *\n"
  printf "*****************************************\n"
  print_help
  exit 1
fi

valid_regex='a-z0-9_'

if [[ $project_name =~ [^$valid_regex] ]]; then
  printf "*******************************************************************************************************************\n"
  printf "* Error: This script only works with a project_name that only contain lowercase letters, numbers, and underscores *\n"
  printf "*******************************************************************************************************************\n"
  exit 1
fi

########################
### gloabl variables ###
########################

path_vhosts='/etc/apache2/sites-available'
vhost_project=${project_name}.conf
path_webroot='/var/www/html'
host_name=${project_name}'.dev3.com'
project_tmpdir='/var/tmp/'${project_name}
dbdumps_loc='/home/dev/dbdumps-loc/'${project_name}
site_logs='/var/log/apache2'

# trim db_site_user name to be within mysql user max length of 16
db_site_user=$(echo ${project_name} | cut -c 1-16)


#################################################
### since functions use variables from above, ###
### they are declared here                    ###
#################################################

## complete function let user know everything went well
finalize() {
  echo ""

  disable_site
  remove_hosts
  remove_aliases
  remove_tmp_dir
  remove_project
  remove_db
  remove_dbdumps
  remove_logs

  echo ""
  echo "done!"
  echo ""
  echo "IMPORTANT: To clear your alias cache please run the following command:"
  echo ""
  echo "src-all"
  echo ""

  exit 0
}

## remove site logs
remove_logs() {
  # access log
  if [ -f "${site_logs}/${project_name}-access.log" ]; then
    # remove access log
    rm ${site_logs}/${project_name}-access.log
    echo " -- removed access log"
  else
    echo ' ** access log does not exist'
  fi

  # error log
  if [ -f "${site_logs}/${project_name}-error.log" ]; then
    # remove access log
    rm ${site_logs}/${project_name}-error.log
    echo " -- removed error log"
  else
    echo ' ** error log does not exist'
  fi
}

## remove database dumps folder
remove_dbdumps() {
  if [ -d "${dbdumps_loc}" ]; then
    rm -rf ${dbdumps_loc}
    echo " -- removed database dump folder"
  else
    echo ' ** database dump folder does not exist'
  fi
}

## remove database
remove_db() {
  # drop the database
  mysql -e "DROP DATABASE ${project_name};"
  mysql -e "DROP USER '"${db_site_user}"'@'localhost';"
}

## remove the drupal project folder
remove_project() {
  if [ -d "${path_webroot}/${project_name}" ]; then
    rm -rf ${path_webroot}/${project_name}
    echo " -- removed site folder"
  else
    echo ' ** site folder does not exist'
  fi
}

## remove temp directory for site
remove_tmp_dir() {
  if [ -d "${project_tmpdir}" ]; then
    rm -rf ${project_tmpdir}
    echo " -- removed temp directory"
  else
    echo ' ** project temp directory does not exist'
  fi
}

## remove aliases
remove_aliases() {
  # remove go-[site] from .bash_aliases file
  if grep -q "go-${project_name}=" /home/dev/.bash_aliases; then
    sed -i "/go-${project_name}=/d" /home/dev/.bash_aliases
    echo " -- removed go alias"
  else
    echo ' ** no go alias exists'
  fi

  # remove fixp-[site] from .bash_aliases file
  if grep -q "fixp-${project_name}=" /home/dev/.bash_aliases; then
    sed -i "/fixp-${project_name}=/d" /home/dev/.bash_aliases
    echo " -- removed fixp alias"
  else
    echo ' ** no fix permission alias exists'
  fi

  # remove dbdump-[site] from .bash_aliases file
  if grep -q "dbdump-${project_name}=" /home/dev/.bash_aliases; then
    sed -i "/dbdump-${project_name}=/d" /home/dev/.bash_aliases
    echo " -- removed dbdump alias"
  else
    echo ' ** no dbdump alias exists'
  fi
}

## remove hosts entry
remove_hosts() {
  # remove hosts entry
  if grep -q ${host_name} /etc/hosts; then
    sed -i "/${host_name}/d" /etc/hosts
    echo " -- removed hosts entry"
  else
    echo ' ** host entry does not exist'
  fi
}

## disable drupal site on apache
disable_site() {
  cd ${path_vhosts}

  # disable site if it exists
  if [ -f "${vhost_project}" ]; then
    # disable site
    a2dissite ${vhost_project}
    # reload apache
    service apache2 reload
    echo " -- disabled vhost entry"
    # remove vhost file
    rm ${vhost_project}
  else
    echo ' ** vhost does not exist'
  fi
}

finalize
