# frozen_string_literal: true

class RenameSavedClaimGroup < ActiveRecord::Migration[7.2]

  def change
    rename_table :saved_claim_group, :saved_claim_groups
  end

end
