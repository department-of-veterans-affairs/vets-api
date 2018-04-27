class CreatePreneedSubmissions < ActiveRecord::Migration
  def change
    create_table :preneed_submissions do |t|
      t.string :tracking_number, null: false
      t.string :application_uuid, null: true
      t.string :return_description, null: false
      t.integer :return_code, null: true

      t.timestamps null: false

      t.index :tracking_number, unique: true
      t.index :application_uuid, unique: true
    end
  end
end
