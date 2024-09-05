# This migration comes from vye (originally 20240502000009)
class AttemptMay2AddExportReadyIndexToBdnClones < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_bdn_clones, :export_ready, algorithm: :concurrently
  end
end
