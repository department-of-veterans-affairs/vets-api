class IndexAwardInVerifications < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_verifications, :award_id, algorithm: :concurrently, if_not_exists: true
  end
end
