# frozen_string_literal: true

class AddIndexesToDigitalDisputeSubmissions < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :digital_dispute_submissions, :user_uuid, algorithm: :concurrently
    add_index :digital_dispute_submissions, :needs_kms_rotation, algorithm: :concurrently
    add_index :digital_dispute_submissions, :debt_identifiers, using: :gin, algorithm: :concurrently
  end
end
