# frozen_string_literal: true

class AddIndexesToSavedClaimGroup < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :saved_claim_group, :claim_group_guid, algorithm: :concurrently, if_not_exists: true
    add_index :saved_claim_group, :needs_kms_rotation, algorithm: :concurrently, if_not_exists: true
  end
end
