class IndexGibsNotFoundUsersOnEdipi < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index :gibs_not_found_users, :edipi, algorithm: :concurrently
  end
end
