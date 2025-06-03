class AddUniqueIndexToGibsNotFoundUsersEdipi < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    remove_index :gibs_not_found_users, column: :edipi, algorithm: :concurrently
    add_index :gibs_not_found_users, :edipi, unique: true, algorithm: :concurrently, name: :index_gibs_not_found_users_on_edipi
  end
end
