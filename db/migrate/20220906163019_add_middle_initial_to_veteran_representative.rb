class AddMiddleInitialToVeteranRepresentative < ActiveRecord::Migration[6.1]
  def change
    add_column :veteran_representatives, :middle_initial, :string
  end
end
