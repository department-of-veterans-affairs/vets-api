class AddRequestedDecisionToDisabilityClaim < ActiveRecord::Migration
  def change
    add_column :disability_claims, :requested_decision, :boolean, null: false, default: false
  end
end
