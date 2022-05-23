class CreateVeteranDeviceRecord < ActiveRecord::Migration[6.1]
  def change
    create_table :veteran_device_records do |t|
      t.references :device, null: false, foreign_key: true
      t.boolean :active, null: false, default: true
      t.string :icn, null: false

      t.timestamps
    end
    add_index :veteran_device_records, [:icn, :device_id], unique: true
  end
end
