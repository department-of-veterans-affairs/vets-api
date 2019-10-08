class CreateDrivetimeBands < ActiveRecord::Migration[5.2]
  def change
    create_table :drivetime_bands do |t|
      # wut wut
      t.string :name
      t.integer :value
      t.string :unit
      t.st_polygon :polygon, geographic: true, null: false
      t.string :vha_facility_id, null: false

      t.timestamps null: false
    end
  end
end
