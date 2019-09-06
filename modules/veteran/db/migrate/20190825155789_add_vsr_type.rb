# frozen_string_literal: true

class AddVsrType < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!
  safety_assured

  def change
    change_column :veteran_representatives, :poa_codes, array: true, :default => []
    add_column :veteran_representatives, :user_types, :string, array: true, default: []
    remove_index :veteran_representatives, :representative_id
    remove_index :veteran_representatives, :first_name
    remove_index :veteran_representatives, :last_name
    add_index :veteran_representatives, %i[representative_id first_name last_name], unique: true, name: 'index_vso_grp'
  end
end
