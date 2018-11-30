class AddIndexToPreferenceCode < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index(:preferences, :code, unique: true, algorithm: :concurrently)
  end
end