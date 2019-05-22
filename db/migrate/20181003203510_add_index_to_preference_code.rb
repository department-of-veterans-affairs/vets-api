class AddIndexToPreferenceCode < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:preferences, :code, unique: true, algorithm: :concurrently)
  end
end