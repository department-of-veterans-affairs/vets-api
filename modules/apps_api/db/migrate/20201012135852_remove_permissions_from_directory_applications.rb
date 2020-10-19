class RemovePermissionsFromDirectoryApplications < ActiveRecord::Migration[6.0]
  def change
    remove_column :directory_applications, :permissions
  end
end
