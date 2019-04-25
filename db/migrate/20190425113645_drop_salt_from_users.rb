require 'carto/db/migration_helper'

include Carto::Db::MigrationHelper

migration(
  Proc.new do
    run "UPDATE users SET crypted_password = concat('$sha$v=1$$',salt,'$',crypted_password) WHERE salt <> ''"
    drop_column :users, :salt
  end,
  Proc.new do
    add_column :users, :salt, String, null: false, default: ""
  end
)
