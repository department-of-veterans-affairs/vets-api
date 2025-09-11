# frozen_string_literal: true

class AddForeignKeyToSavedClaimGroup < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_foreign_key :saved_claim_group, :saved_claims, column: :parent_claim_id, if_exists: true, validate: false
    remove_foreign_key :saved_claim_group, :saved_claims, column: :saved_claim_id, if_exists: true, validate: false
  end

  def down
    add_foreign_key :saved_claim_group, :saved_claims, column: :parent_claim_id, if_not_exists: true, validate: false
    add_foreign_key :saved_claim_group, :saved_claims, column: :saved_claim_id, if_not_exists: true, validate: false
  end
end
