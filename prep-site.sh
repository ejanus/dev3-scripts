#!/bin/bash

## Help menu
print_help() {
  cat <<-HELP
This script is used to provide vhost, helpful aliases and hosts entries for a site 

You will need to provide the following:

--project_name=[project_name] (must not contain spaces)
(optional) --db_name="[db_name]" (must not contain spaces)
(optional) --site_root=[site_root] - specify the site root folder relative to the project folder. No spaces.

Example - default usage: 
bash ${0##*/} --project_name=mycopiedsite

Example - default usage: 
bash ${0##*/} --project_name=mycopiedsite --db_name=my_db_name --site_root=docroot

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
    --db_name=*)
      db_name="${1#*=}"
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
  print_help
  exit 1
fi


########################
### gloabl variables ###
########################

path_vhosts='/etc/apache2/sites-available'
vhost_drupal_template='drupal-default.conf'
vhost_project=${project_name}.conf
path_webroot='/var/www/html'
host_name=${project_name}'.dev3.com'
project_tmpdir='/var/tmp/'${project_name}

if [ -z "${site_root}" ]; then
  path_siteroot=${path_webroot}/${project_name}
else 
  path_siteroot=${path_webroot}/${project_name}/${site_root}
fi

if [ -z "${db_name}" ]; then
  db_name=${project_name}
fi

#################################################
### since functions use variables from above, ### 
### they are declared here                    ###
#################################################

## complete function let user know everything went well and fix permissions
finalize() {
  # update file ownership
  chown -R ${user}:${web_user} ${path_siteroot} 
  
  enable_site
  add_aliases 
  add_tmp_dir
 
  echo "done!"
  exit 0
}

## add temp directory for site
add_tmp_dir() {
  # setup temp directory for use
  mkdir -p ${project_tmpdir}
  chown -R dev:www-data ${project_tmpdir}
  chmod -R 770 ${project_tmpdir}
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
    sed -i "/#dbdump-site/a alias dbdump-${project_name}='FILE_LOC_NAME=~/dbdumps-loc/${project_name}/${project_name}_loc_\$(getDateForFile).sql &&  mysqldump -u root -p ${db_name} > \$FILE_LOC_NAME; echo \$FILE_LOC_NAME created successfully!'" /home/dev/.bash_aliases
    #sed -i "/#dbdump-site/a alias dbdump-${project_name}='mkdir -p ~/dbdumps-loc/${project_name}; mysqldump -u root -p ${db_name} > ~/dbdumps-loc/${project_name}/${project_name}_loc_\$(getDateForFile).sql; ls -ABrt1 --group-directories-first ~/dbdumps-loc/${project_name}/ | tail -n1'" /home/dev/.bash_aliases
  fi
}

## enable drupal site on apache
enable_site() {
  cd ${path_vhosts}
  
  # create vhosts file from drupal_default
  if [ -f "${vhost_project}" ]; then
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
}

finalize
