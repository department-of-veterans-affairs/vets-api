class AddHealthAccountBeta < ActiveRecord::Migration
  def change
    create_table :health_beta_registrations do |t|
      t.uuid :user_uuid, unique: true, null: false
      t.timestamps null: false
    end

    add_index :health_beta_registrations, [:user_uuid]
  end
end
