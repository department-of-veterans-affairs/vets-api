class CreateVyeBdnClones < ActiveRecord::Migration[7.1]
  def change
    create_table :vye_bdn_clones do |t|
      t.boolean :is_active
      t.boolean :export_ready
      t.date    :transact_date

      t.timestamps
    end

    add_index :vye_bdn_clones, :is_active, unique: true, where: "is_active IS NOT NULL"
    add_index :vye_bdn_clones, :export_ready, unique: true, where: "export_ready IS NOT NULL"
  end
end
