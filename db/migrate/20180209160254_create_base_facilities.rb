class CreateBaseFacilities < ActiveRecord::Migration
  def change
    create_table :base_facilities, id: false do |t|
      t.string :unique_id, null: false
      t.string :name, null: false
      t.string :facility_type, null: false
      t.string :classification
      t.string :website
      t.float :lat, null: false
      t.float :long, null: false
      t.jsonb :address
      t.jsonb :phone
      t.jsonb :hours
      t.jsonb :services
      t.jsonb :feedback
      t.jsonb :access
      t.string :fingerprint

      t.timestamps null: false
    end
  end
end
