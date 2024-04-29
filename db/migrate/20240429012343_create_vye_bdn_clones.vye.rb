# This migration comes from vye (originally 20240422033815)
class CreateVyeBdnClones < ActiveRecord::Migration[7.1]
  def change
    create_table :vye_bdn_clones do |t|
      t.boolean :is_active
      t.boolean :export_ready
      t.date    :transact_date

      t.timestamps
    end

    add_index :vye_bdn_clones, :is_active
    add_index :vye_bdn_clones, :export_ready
  end
end
