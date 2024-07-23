class AttemptMay1CreateVyeBdnClones < ActiveRecord::Migration[7.1]
  def change
    drop_table :vye_bdn_clones if table_exists?(:vye_bdn_clones)

    create_table :vye_bdn_clones do |t|
      t.boolean :is_active
      t.boolean :export_ready
      t.date    :transact_date

      t.timestamps
    end
  end
end
