class AddVet360LinkAttemptsToMobileUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :mobile_users, :vet360_link_attempts, :integer
    add_column :mobile_users, :vet360_linked, :boolean
  end
end
