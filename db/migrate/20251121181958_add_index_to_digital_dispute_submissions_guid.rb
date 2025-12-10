# frozen_string_literal: true

class AddIndexToDigitalDisputeSubmissionsGuid < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :digital_dispute_submissions, :guid, unique: true, algorithm: :concurrently
  end
end
