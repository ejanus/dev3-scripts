#!/bin/bash

## Help menu
print_help() {
  cat <<-HELP
This script is used to perform all initial steps to setup a new Drupal site. 

You will need to provide the following:

--project_name=[project_name] (must not contain spaces)
--site_name="[site name]" (can include spaces with qoutes)
(optional) --version=[7/8] - defaults to 8
(optional) --site_root=[site_root] - specify the site root folder relative to the project folder. No spaces.

Example - extra modules with site root specified: 
bash ${0##*/} --project_name=mynewsite --site_name='My test site' --site_root='htdocs' --quick_install=N

Example - vanilla modules with site root specified: 
bash ${0##*/} --project_name=mynewsite --site_name='My test site' --site_root='htdocs'

Example - vanilla modules: 
bash ${0##*/} --project_name=mynewsite --site_name='My test site' 

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

#project_name=${1}
#site_name="${2}"
#quick_install=${3:-Y}

# Parse Command Line Arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --project_name=*)
      project_name="${1#*=}"
      ;;
    --site_name=*)
      site_name="${1#*=}"
      ;;
    --site_root=*)
      site_root="${1#*=}"
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
  exit 1
fi

if [ -z "${site_name}" ]; then
  printf "**************************************\n"
  printf "* Error: Please provide a site name. *\n"
  printf "**************************************\n"
  exit 1
fi

########################
### gloabl variables ###
########################

path_vhosts='/etc/apache2/sites-available'
vhost_drupal_template='drupal-default.conf'
vhost_project=${project_name}.conf
path_webroot='/var/www/html'
project_tmpdir='/var/tmp/'${project_name}

if [ -z "${site_root}" ]; then
  path_siteroot=${path_webroot}/${project_name}
else 
  path_siteroot=${path_webroot}/${project_name}/${site_root}
fi

host_name=${project_name}'.dev3.com'

db_root_user='root'

# trim db_site_user name to be within mysql user max length of 16
db_site_user=$(echo ${project_name} | cut -c 1-16)
# generate a random 16 character password with numbers, capital and, lower case letters
db_site_pass="$(apg -m 16 -n 1 -a 1 -M NCL)"


#######################################
### do files/folders already exist? ###
#######################################

# make sure the project and vhost entries are not already there
if [ -d "${path_siteroot}" ]; then
  printf "*********************************\n"
  printf "* Error: project already exists *\n"
  printf "*********************************\n"
  exit 1
fi

#################################################
### since functions use variables from above, ### 
### they are declared here                    ###
#################################################

## complete function let user know everything went well and fix permissions
finalize() {
  # update file ownership
  # chown -R ${user}:${web_user} ${path_siteroot} 

  # fix permissions
  bash /home/dev/scripts/fix-permissions.sh --drupal_path=${path_siteroot} --drupal_user=dev
  
  enable_site
  add_aliases 
 
  echo "done!"
  exit 0
}


## add aliases
add_aliases() {
  ## add some helpful aliases

  # add go-[site] to .bash_alias file
  if grep -q "go-${project_name}" /home/dev/.bash_aliases; then
    echo 'go alias already exists'
  else  
    sed -i  "/#sites/a alias go-${project_name}=\"cd ${path_siteroot}\"" /home/dev/.bash_aliases
  fi 

  # add fixp-[site] to .bash_alias file
  if grep -q "fixp-${project_name}" /home/dev/.bash_aliases; then
    echo 'fix permission alias already exists' 
  else 
    sed -i "/#fix-site-permissions/a alias fixp-${project_name}=\"sudo bash /home/dev/scripts/fix-permissions.sh --drupal_path=${path_siteroot} --drupal_user=dev\"" /home/dev/.bash_aliases
  fi

  # add dbdump-[site] to .bash_alias file
  mkdir -p /home/dev/dbdumps-loc/${project_name}
  chown -R dev:dev /home/dev/dbdumps-loc
  if grep -q "dbdump-${project_name}" /home/dev/.bash_aliases; then
    echo 'dbdump alias already exists' 
  else 
    sed -i "/#dbdump-site/a alias dbdump-${project_name}='FILE_LOC_NAME=~/dbdumps-loc/${project_name}/${project_name}_loc_\$(getDateForFile).sql &&  mysqldump -u root -p ${project_name} > \$FILE_LOC_NAME; echo \$FILE_LOC_NAME created successfully!'" /home/dev/.bash_aliases
    #sed -i "/#dbdump-site/a alias dbdump-${project_name}='mkdir -p ~/dbdumps-loc/${project_name}; mysqldump -u root -p ${project_name} > ~/dbdumps-loc/${project_name}/${project_name}_loc_\$(getDateForFile).sql; ls -ABrt1 --group-directories-first ~/dbdumps-loc/${project_name}/ | tail -n1'" /home/dev/.bash_aliases
  fi
}

## enable drupal site on apache
enable_site() {
  cd ${path_vhosts}
  
  # create vhosts file from drupal_default
  if [ -d "${vhost_project}" ]; then
    echo 'vhost file already exists'
  else 
    sed "s/PROJECT/${project_name}/g" ${vhost_drupal_template} > ${vhost_project}
    sed -i 's|SITE_ROOT|'${path_siteroot}'|g' ${vhost_project}
    # enable site
    a2ensite ${vhost_project}
    # reload apache
    service apache2 reload
  fi 

  # add hosts entry
  if grep -q ${host_name} /etc/hosts; then 
    echo 'host entry already exists'
  else 
    echo -e "127.0.0.1\t"${host_name} >> /etc/hosts
  fi

  # setup temp directory for use
  mkdir -p ${project_tmpdir}
  chown -R dev:www-data ${project_tmpdir}
  chmod -R 770 ${project_tmpdir}

  # add tmp directory to settings.php
  echo -e "\$conf['file_temporary_path'] = '"${project_tmpdir}"';" >> ${path_siteroot}/sites/default/settings.php 
}


##########################
### create drupal site ###
##########################

# sometimes, for some reason, drush permissions are screwed up
# here we make sure they are correct before moving on
# chown -R dev /usr/local/bin/drush

# download drupal
cd ${path_webroot}

# if the site root was not specified then just install into a new folder based on project name
# else, cd into the project name and install into the site root folder specified
if [ -z "${site_root}" ]; then
  drush dl drupal-8 --drupal-project-rename=${project_name}
else 
  mkdir -p ${project_name}
  chown :www-data ${project_name}
  cd ${project_name}
  drush dl drupal-8 --drupal-project-rename=${site_root}
fi

# create the database and user for the project
dbstring="CREATE DATABASE ${project_name}; GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES ON ${project_name}.* TO '${db_site_user}'@'localhost' IDENTIFIED BY '${db_site_pass}';"
mysql -u ${db_root_user} -p -e "${dbstring}"


# install drupal
cd ${path_siteroot}
drush site-install standard --db-url="mysql://${db_site_user}:${db_site_pass}@localhost/${project_name}" --site-name="${site_name}" --account-name="dev3admin"  --account-pass="dev3admin" --account-mail="admin@example.com" -y

# first, create contrib/custom folders
mkdir ${path_siteroot}/sites/all/modules/custom
mkdir ${path_siteroot}/sites/all/modules/contrib

# all set so run complete function
finalize
