class FixDirectoryApplicationColumnName < ActiveRecord::Migration[6.0]
  def change
    rename_column :directory_applications, :type, :app_type
  end
end
