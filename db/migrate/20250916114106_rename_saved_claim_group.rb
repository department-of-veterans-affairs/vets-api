# frozen_string_literal: true

# add 's' to the table name so no override in the class is needed
class RenameSavedClaimGroup < ActiveRecord::Migration[7.2]

  def change
    safety_assured { rename_table :saved_claim_group, :saved_claim_groups }
  end

end
