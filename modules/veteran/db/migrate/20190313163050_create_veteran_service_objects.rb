# frozen_string_literal: true

class CreateVeteranServiceObjects < ActiveRecord::Migration
  def change
    create_table :veteran_organizations, id: false do |t|
      t.string :poa, limit: 3
      t.string :name
      t.string :phone
      t.string :state, limit: 2
      t.index :poa, unique: true
      t.timestamps null: false
    end

    create_table :veteran_representatives, id: false do |t|
      t.string :representative_id
      t.string :poa, limit: 3
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone
      t.index :representative_id, unique: true
      t.index :first_name
      t.index :last_name
      t.timestamps null: false
    end
  end
end
