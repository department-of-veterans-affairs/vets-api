class AddProcessingStatusToClaims < ActiveRecord::Migration[7.1]
  def change
    add_column :claims, :processing_status, :string
    add_column :claims, :processed_at, :datetime
    add_column :claims, :processor_id, :string

    add_index :claims, :processing_status
    add_index :claims, [:processing_status, :processed_at]
  end
end