#!/bin/bash
# ---------------------------------------------------------------------
# Copyright (C) 2021 DevPanel
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation version 3 of the
# License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# For GNU Affero General Public License see <https://www.gnu.org/licenses/>.
# ----------------------------------------------------------------------

STATIC_FILES_PATH="$WEB_ROOT/sites/default/files"
SETTINGS_FILES_PATH="$WEB_ROOT/sites/default/settings.php"

if [[ ! -n "$APACHE_RUN_USER" ]]; then
  export APACHE_RUN_USER=www-data
fi
if [[ ! -n "$APACHE_RUN_GROUP" ]]; then
  export APACHE_RUN_GROUP=www-data
fi

#== Composer install.
if [[ -f "$APP_ROOT/composer.json" ]]; then
  cd $APP_ROOT && composer install;
fi
if [[ -f "$WEB_ROOT/composer.json" ]]; then
  cd $WEB_ROOT && composer install;
fi

cd $WEB_ROOT && git submodule update --init --recursive

#== Drush Site Install
if [[ $(mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD $DB_NAME -e "show tables;") == '' ]]; then
  echo "Site installing ..."
  cd $APP_ROOT
  drush si --account-name=devpanel --account-pass=devpanel  --site-name="Drupal 10" --db-url=mysql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME -y
  drush cr
fi

#== Setup settings.php file
sudo cp $APP_ROOT/.devpanel/drupal-settings.php $SETTINGS_FILES_PATH

#== Generate hash salt
echo 'Generate hash salt ...'
DRUPAL_HASH_SALT=$(openssl rand -hex 32);
sudo sed -i -e "s/^\$settings\['hash_salt'\].*/\$settings\['hash_salt'\] = '$DRUPAL_HASH_SALT';/g" $SETTINGS_FILES_PATH

#== Update permission
echo 'Update permission ....'
drush cr
sudo chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP $STATIC_FILES_PATH
sudo chown www:www $SETTINGS_FILES_PATH
sudo chmod 644 $SETTINGS_FILES_PATH
