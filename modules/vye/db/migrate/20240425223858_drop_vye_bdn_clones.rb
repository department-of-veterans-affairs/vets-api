class DropVyeBdnClones < ActiveRecord::Migration[7.1]
  def change
    remove_index "vye_bdn_clones", column: [:is_active], unique: true, where: "(is_active IS NOT NULL)", name: "index_vye_bdn_clones_on_is_active", if_exists: true
    remove_index "vye_bdn_clones", column: [:export_ready], unique: true, where: "(export_ready IS NOT NULL)", name: "index_vye_bdn_clones_on_export_ready", if_exists: true
    drop_table :vye_bdn_clones, if_exists: true # rubocop:disable Rails/ReversibleMigration
  end
end
