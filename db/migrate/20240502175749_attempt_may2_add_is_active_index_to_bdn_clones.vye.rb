# This migration comes from vye (originally 20240502000008)
class AttemptMay2AddIsActiveIndexToBdnClones < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_bdn_clones, :is_active, algorithm: :concurrently
  end
end
