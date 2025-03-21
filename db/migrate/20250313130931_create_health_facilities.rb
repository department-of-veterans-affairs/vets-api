class CreateHealthFacilities < ActiveRecord::Migration[7.2]
  def change
    create_table :health_facilities do |t|
      t.string :name
      t.string :station_number
      t.string :postal_name

      t.timestamps
    end
    
    add_index :health_facilities, :station_number, unique: true
  end
end
