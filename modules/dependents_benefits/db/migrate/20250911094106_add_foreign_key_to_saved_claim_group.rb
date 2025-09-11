# frozen_string_literal: true

class AddForeignKeyToSavedClaimGroup < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_foreign_key :saved_claim_group, :saved_claim, column: :parent_claim_id, if_not_exists: true
    add_foreign_key :saved_claim_group, :saved_claim, column: :saved_claim_id, if_not_exists: true
  end
end
